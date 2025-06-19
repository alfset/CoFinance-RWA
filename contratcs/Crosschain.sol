// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract CrossChainSender is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IRouterClient public ccipRouter;
    mapping(address => bool) public supportedTokens;
    uint64 public destinationChainSelector;
    address public destinationContract;
    address public constant LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address public constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;

    event CrossChainMintInitiated(bytes32 indexed messageId, address indexed user, address token, uint256 amount, string symbol);
    event CrossChainRefundReceived(bytes32 indexed messageId, address indexed user, address token, uint256 amount);

    constructor(
        address _ccipRouter,
        uint64 _destinationChainSelector,
        address _destinationContract
    ) Ownable(msg.sender) {
        require(_ccipRouter != address(0), "Invalid CCIP router address");
        require(_destinationContract != address(0), "Invalid destination contract");
        ccipRouter = IRouterClient(_ccipRouter);
        destinationChainSelector = _destinationChainSelector;
        destinationContract = _destinationContract;

        supportedTokens[USDC] = true;
        supportedTokens[WETH] = true;
        supportedTokens[LINK] = true;
    }

    function initiateCrossChainMint(
        string calldata symbol,
        address paymentToken,
        uint256 amount
    ) external nonReentrant {
        require(supportedTokens[paymentToken], "Unsupported payment token");
        require(amount > 0, "Amount must be greater than 0");

        require(IERC20(paymentToken).balanceOf(msg.sender) >= amount, "Insufficient token balance");
        require(IERC20(paymentToken).allowance(msg.sender, address(this)) >= amount, "Insufficient token allowance");

        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: paymentToken,
            amount: amount
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(destinationContract),
            data: abi.encode(msg.sender, paymentToken, amount, symbol),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 200_000})),
            feeToken: LINK
        });

        uint256 fees = ccipRouter.getFee(destinationChainSelector, message);
        require(IERC20(LINK).balanceOf(msg.sender) >= fees, "Insufficient LINK for CCIP fees");
        IERC20(LINK).safeTransferFrom(msg.sender, address(this), fees);
        IERC20(address(this)).approve(address(ccipRouter), fees);



        bytes32 messageId = ccipRouter.ccipSend(destinationChainSelector, message);

        emit CrossChainMintInitiated(messageId, msg.sender, paymentToken, amount, symbol);
    }

    function receiveCrossChainRefund(
        address user,
        address token,
        uint256 amount
    ) external nonReentrant {
        require(supportedTokens[token], "Unsupported token");
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
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token balance");
        IERC20(token).safeTransfer(owner(), amount);
    }
}
