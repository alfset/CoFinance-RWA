// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts@4.9.0/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@4.9.0/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts@4.9.0/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@4.9.0/access/Ownable.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract CrossChainSender is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IRouterClient public immutable ccipRouter;
    uint64 public destinationChainSelector;
    address public destinationContract;

    address public constant LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789; 
    address public constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; 
    address public constant WETH = 0xD96b1bf0432A11f57fc0A1FcE5ae3e74A8C5829a; 

    mapping(string => address) public symbolToToken;

    event CrossChainMintInitiated(bytes32 indexed messageId, address indexed user, address token, uint256 amount, string symbolToMint);
    event CrossChainRefundReceived(bytes32 indexed messageId, address indexed user, address token, uint256 amount);
    event DestinationChainUpdated(uint64 newChainSelector, address newDestinationContract);

    constructor(
        address _ccipRouter,
        uint64 _destinationChainSelector,
        address _destinationContract
    ) Ownable() {
        require(_ccipRouter != address(0), "Invalid CCIP router address");
        require(_destinationContract != address(0), "Invalid destination contract");
        ccipRouter = IRouterClient(_ccipRouter);
        destinationChainSelector = _destinationChainSelector;
        destinationContract = _destinationContract;

        symbolToToken["USDC"] = USDC;
        symbolToToken["WETH"] = WETH;
        symbolToToken["LINK"] = LINK;
    }

    function initiateCrossChainMint(
        string calldata symbolToMint,
        string calldata symbolForPayment,
        uint256 amount
    ) external nonReentrant returns (bytes32) {
        address paymentToken = symbolToToken[symbolForPayment];
        require(paymentToken != address(0), "Unsupported payment token");
        require(amount > 0, "Amount must be greater than 0");
        require(IERC20(paymentToken).balanceOf(msg.sender) >= amount, "Insufficient token balance");
        require(IERC20(paymentToken).allowance(msg.sender, address(this)) >= amount, "Insufficient token allowance");

        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(paymentToken).approve(address(ccipRouter), amount);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: paymentToken,
            amount: amount
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(destinationContract),
            data: abi.encode(msg.sender, symbolForPayment, amount, symbolToMint),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 1_000_000})),
            feeToken: LINK
        });

        uint256 fees = ccipRouter.getFee(destinationChainSelector, message);
        require(IERC20(LINK).balanceOf(msg.sender) >= fees, "Insufficient LINK for CCIP fees");
        require(IERC20(LINK).allowance(msg.sender, address(this)) >= fees, "Insufficient LINK allowance");

        IERC20(LINK).safeTransferFrom(msg.sender, address(this), fees);
        IERC20(LINK).approve(address(ccipRouter), fees);

        bytes32 messageId = ccipRouter.ccipSend(destinationChainSelector, message);
        emit CrossChainMintInitiated(messageId, msg.sender, paymentToken, amount, symbolToMint);
        return messageId;
    }

    function receiveCrossChainRefund(
        address user,
        address token,
        uint256 amount
    ) external nonReentrant {
        require(msg.sender == destinationContract, "Only destination contract can call");
        require(symbolToToken[_getTokenSymbol(token)] != address(0), "Unsupported token");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token balance");

        IERC20(token).safeTransfer(user, amount);
        emit CrossChainRefundReceived(keccak256(abi.encodePacked(user, token, amount)), user, token, amount);
    }

    function updateDestinationChain(
        uint64 _destinationChainSelector,
        address _destinationContract
    ) external onlyOwner {
        require(_destinationContract != address(0), "Invalid destination contract");
        destinationChainSelector = _destinationChainSelector;
        destinationContract = _destinationContract;
        emit DestinationChainUpdated(_destinationChainSelector, _destinationContract);
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token balance");
        IERC20(token).safeTransfer(owner(), amount);
    }

    function _getTokenSymbol(address token) internal pure returns (string memory) {
        if (token == 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238) return "USDC";
        if (token == 0xD96b1bf0432A11f57fc0A1FcE5ae3e74A8C5829a) return "WETH";
        if (token == 0x779877A7B0D9E8603169DdbD7836e478b4624789) return "LINK";
        revert("Unknown token");
    }
}
