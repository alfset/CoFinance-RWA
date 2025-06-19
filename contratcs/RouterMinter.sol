// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IFunctionsConsumer.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./AssetToken.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract MintBurnManager is Ownable, ReentrancyGuard, CCIPReceiver {
    using SafeERC20 for IERC20;

    IFunctionsConsumer public mintConsumer;
    IFunctionsConsumer public burnConsumer;
    AssetToken public assetToken;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public tokenDecimals;
    mapping(address => address) public sourceChainTokenMapping;
    uint256 public constant REQUEST_TIMEOUT = 10 minutes;

    struct Request {
        address user;
        address paymentToken;
        uint256 amount;
        bool isMint;
        bool fulfilled;
        uint256 timestamp;
        bytes32 consumerRequestId;
        bool isCrossChain;
        uint64 sourceChainSelector;
        address sourceChainSender;
    }
    mapping(bytes32 => Request) public requests;
    mapping(bytes32 => bool) public consumerResultsReceived;
    IRouterClient public ccipRouter;
    uint64 public subscriptionId;

    event MintRequestInitiated(bytes32 indexed requestId, address indexed user, address paymentToken, uint256 amount, bool isCrossChain);
    event BurnRequestInitiated(bytes32 indexed requestId, address indexed user, uint256 amount, address paymentToken);
    event MintCompleted(bytes32 indexed requestId, address indexed user, uint256 qty);
    event BurnCompleted(bytes32 indexed requestId, address indexed user, address paymentToken, uint256 tokenAmount);
    event Refunded(bytes32 indexed requestId, address indexed user, address token, uint256 amount);
    event RequestTimedOut(bytes32 indexed requestId, address indexed user, address token, uint256 amount);
    event ConsumerResultReceived(bytes32 indexed requestId, uint256 result);
    event ProcessResultAttempted(bytes32 indexed requestId, bool isMint, bool success);
    event CrossChainMintReceived(bytes32 indexed messageId, uint64 sourceChainSelector, address sender, address user, address token, uint256 amount, string symbol);

    address public constant USDC = 0x5425890298aed601595a70AB815c96711a31Bc65;
    address public constant WETH = 0xEc3f46FBF81dBE7Bc1360b2e2eE3bBcb01d3cBB0;
    address public constant WAVAX = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c;
    address public constant LINK = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;

    constructor(
        address _mintConsumer,
        address _burnConsumer,
        uint64 _subscriptionId,
        address _assetToken,
        address _ccipRouter
    ) Ownable(msg.sender) CCIPReceiver(_ccipRouter) {
        require(_mintConsumer != address(0), "Invalid mint consumer address");
        require(_burnConsumer != address(0), "Invalid burn consumer address");
        require(_assetToken != address(0), "Invalid asset token address");
        require(_ccipRouter != address(0), "Invalid CCIP router address");
        mintConsumer = IFunctionsConsumer(_mintConsumer);
        burnConsumer = IFunctionsConsumer(_burnConsumer);
        subscriptionId = _subscriptionId;
        assetToken = AssetToken(_assetToken);
        ccipRouter = IRouterClient(_ccipRouter);

        supportedTokens[USDC] = true;
        supportedTokens[WETH] = true;
        supportedTokens[WAVAX] = true;
        supportedTokens[LINK] = true;

        tokenDecimals[USDC] = 6;
        tokenDecimals[WETH] = 18;
        tokenDecimals[WAVAX] = 18;
        tokenDecimals[LINK] = 18;
    }

    function initiateMint(
        string calldata symbol,
        address paymentToken,
        uint256 amount
    ) external nonReentrant {
        require(supportedTokens[paymentToken], "Unsupported payment token");
        require(amount > 0, "Amount must be greater than 0");

        require(IERC20(paymentToken).balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(IERC20(paymentToken).allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");

        uint256 balanceBefore = IERC20(paymentToken).balanceOf(address(this));
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);
        require(IERC20(paymentToken).balanceOf(address(this)) == balanceBefore + amount, "Token transfer failed");

        string[] memory args = new string[](3);
        args[0] = symbol;
        args[1] = _getTokenSymbol(paymentToken);
        args[2] = _toString(amount);

        bytes32 requestId = mintConsumer.sendRequest(subscriptionId, args);

        requests[requestId] = Request({
            user: msg.sender,
            paymentToken: paymentToken,
            amount: amount,
            isMint: true,
            fulfilled: false,
            timestamp: block.timestamp,
            consumerRequestId: requestId,
            isCrossChain: false,
            sourceChainSelector: 0,
            sourceChainSender: address(0)
        });

        emit MintRequestInitiated(requestId, msg.sender, paymentToken, amount, false);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        uint64 sourceChainSelector = message.sourceChainSelector;
        address sender = abi.decode(message.sender, (address));
        (address user, address sourceToken, uint256 amount, string memory symbol) = abi.decode(message.data, (address, address, uint256, string));

        address paymentToken = sourceChainTokenMapping[sourceToken];
        require(supportedTokens[paymentToken], "Unsupported payment token");

        uint256 balanceBefore = IERC20(paymentToken).balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient tokens received");

        string[] memory args = new string[](3);
        args[0] = symbol;
        args[1] = _getTokenSymbol(paymentToken);
        args[2] = _toString(amount);

        bytes32 requestId = mintConsumer.sendRequest(subscriptionId, args);

        requests[requestId] = Request({
            user: user,
            paymentToken: paymentToken,
            amount: amount,
            isMint: true,
            fulfilled: false,
            timestamp: block.timestamp,
            consumerRequestId: requestId,
            isCrossChain: true,
            sourceChainSelector: sourceChainSelector,
            sourceChainSender: sender
        });

        emit CrossChainMintReceived(message.messageId, sourceChainSelector, sender, user, paymentToken, amount, symbol);
        emit MintRequestInitiated(requestId, user, paymentToken, amount, true);
    }

    function initiateBurn(
        string calldata symbol,
        address paymentToken,
        uint256 amount
    ) external nonReentrant {
        require(supportedTokens[paymentToken], "Unsupported payment token");
        require(amount > 0, "Amount must be greater than 0");

        require(assetToken.balanceOf(msg.sender) >= amount, "Insufficient asset token balance");
        require(assetToken.allowance(msg.sender, address(this)) >= amount, "Insufficient asset token allowance");

        assetToken.burnFrom(msg.sender, amount);

        string[] memory args = new string[](3);
        args[0] = symbol;
        args[1] = _getTokenSymbol(paymentToken);
        args[2] = _toString(amount);

        bytes32 requestId = burnConsumer.sendRequest(subscriptionId, args);

        requests[requestId] = Request({
            user: msg.sender,
            paymentToken: paymentToken,
            amount: amount,
            isMint: false,
            fulfilled: false,
            timestamp: block.timestamp,
            consumerRequestId: requestId,
            isCrossChain: false,
            sourceChainSelector: 0,
            sourceChainSender: address(0)
        });

        emit BurnRequestInitiated(requestId, msg.sender, amount, paymentToken);
    }

    function processResult(bytes32 requestId, bool isMint) public nonReentrant {
        Request storage request = requests[requestId];
        require(!request.fulfilled, "Request already fulfilled");
        require(request.isMint == isMint, "Invalid request type");
        require(request.paymentToken != address(0), "Invalid payment token");
        require(request.amount > 0, "Invalid request amount");
        require(consumerResultsReceived[request.consumerRequestId], "Consumer result not received");

        IFunctionsConsumer consumer = isMint ? mintConsumer : burnConsumer;
        uint256 result = consumer.getResult();

        request.fulfilled = true;

        bool success = true;
        if (isMint) {
            if (result > 0) {
                try assetToken.mint(request.user, result) {
                    emit MintCompleted(requestId, request.user, result);
                } catch {
                    success = false;
                    revert("Failed to mint asset tokens");
                }
            } else {
                if (request.isCrossChain) {
                    _refundCrossChain(request);
                } else {
                    uint256 balanceBefore = IERC20(request.paymentToken).balanceOf(address(this));
                    if (balanceBefore >= request.amount) {
                        IERC20(request.paymentToken).safeTransfer(request.user, request.amount);
                        if (
                            IERC20(request.paymentToken).balanceOf(address(this)) == balanceBefore - request.amount
                        ) {
                            emit Refunded(requestId, request.user, request.paymentToken, request.amount);
                        } else {
                            success = false;
                            revert("Refund transfer failed");
                        }
                    } else {
                        success = false;
                        revert("Insufficient payment token balance for refund");
                    }
                }
            }
        } else {
            if (result > 0) {
                uint256 balanceBefore = IERC20(request.paymentToken).balanceOf(address(this));
                if (balanceBefore >= result) {
                    IERC20(request.paymentToken).safeTransfer(request.user, result);
                    if (
                        IERC20(request.paymentToken).balanceOf(address(this)) == balanceBefore - result
                    ) {
                        emit BurnCompleted(requestId, request.user, request.paymentToken, result);
                    } else {
                        success = false;
                        revert("Burn transfer failed");
                    }
                } else {
                    success = false;
                    revert("Insufficient payment token balance");
                }
            } else {
                try assetToken.mint(request.user, request.amount) {
                    emit Refunded(requestId, request.user, address(assetToken), request.amount);
                } catch {
                    success = false;
                    revert("Failed to refund asset tokens");
                }
            }
        }
        emit ProcessResultAttempted(requestId, isMint, success);
    }

    function _refundCrossChain(Request memory request) internal {
        require(request.isCrossChain, "Not a cross-chain request");
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: request.paymentToken,
            amount: request.amount
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(request.sourceChainSender),
            data: abi.encode(request.user, request.paymentToken, request.amount),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 200_000})),
            feeToken: LINK
        });

        uint256 fees = ccipRouter.getFee(request.sourceChainSelector, message);
        require(IERC20(LINK).balanceOf(address(this)) >= fees, "Insufficient LINK for CCIP fees");

        IERC20(LINK).safeTransferFrom(msg.sender, address(ccipRouter), fees);

        bytes32 messageId = ccipRouter.ccipSend(request.sourceChainSelector, message);
        emit Refunded(request.consumerRequestId, request.user, request.paymentToken, request.amount);
    }

    function receiveConsumerResult(bytes32 requestId, uint256 result) external nonReentrant {
        require(msg.sender == address(mintConsumer) || msg.sender == address(burnConsumer), "Unauthorized caller");
        require(!consumerResultsReceived[requestId], "Result already received");
        consumerResultsReceived[requestId] = true;
        emit ConsumerResultReceived(requestId, result);

        Request memory request = requests[requestId];
        if (request.user != address(0) && !request.fulfilled) {
            try this.processResult(requestId, request.isMint) {} catch {
                consumerResultsReceived[requestId] = false;
                emit ProcessResultAttempted(requestId, request.isMint, false);
            }
        }
    }

    function reclaimTimedOutRequest(bytes32 requestId) external nonReentrant {
        Request storage request = requests[requestId];
        require(!request.fulfilled, "Request already fulfilled");
        require(block.timestamp >= request.timestamp + REQUEST_TIMEOUT, "Request not timed out");
        require(msg.sender == request.user, "Not request owner");

        request.fulfilled = true;

        if (request.isMint) {
            if (request.isCrossChain) {
                _refundCrossChain(request);
            } else {
                uint256 balanceBefore = IERC20(request.paymentToken).balanceOf(address(this));
                require(balanceBefore >= request.amount, "Insufficient payment token balance for refund");
                IERC20(request.paymentToken).safeTransfer(request.user, request.amount);
                require(
                    IERC20(request.paymentToken).balanceOf(address(this)) == balanceBefore - request.amount,
                    "Contract balance not updated correctly"
                );
                emit Refunded(requestId, request.user, request.paymentToken, request.amount);
                emit RequestTimedOut(requestId, request.user, request.paymentToken, request.amount);
            }
        } else {
            try assetToken.mint(request.user, request.amount) {
                emit Refunded(requestId, request.user, address(assetToken), request.amount);
                emit RequestTimedOut(requestId, request.user, address(assetToken), request.amount);
            } catch {
                revert("Failed to refund asset tokens");
            }
        }
    }

    function getMintConsumerResult(bytes32 requestId) external view returns (uint256 result, bool isReceived) {
        Request memory request = requests[requestId];
        require(request.isMint, "Not a mint request");
        isReceived = consumerResultsReceived[request.consumerRequestId];
        if (isReceived) {
            result = mintConsumer.getResult();
        }
        return (result, isReceived);
    }

    function getBurnConsumerResult(bytes32 requestId) external view returns (uint256 result, bool isReceived) {
        Request memory request = requests[requestId];
        require(!request.isMint, "Not a burn request");
        isReceived = consumerResultsReceived[request.consumerRequestId];
        if (isReceived) {
            result = burnConsumer.getResult();
        }
        return (result, isReceived);
    }

    function getContractTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function isRequestTimedOut(bytes32 requestId) external view returns (bool) {
        Request storage request = requests[requestId];
        return !request.fulfilled && block.timestamp >= request.timestamp + REQUEST_TIMEOUT;
    }

    function isConsumerResultReceived(bytes32 requestId) external view returns (bool) {
        return consumerResultsReceived[requestId];
    }

    function _getTokenSymbol(address token) internal pure returns (string memory) {
        if (token == USDC) return "USDC";
        if (token == WETH) return "WETH";
        if (token == WAVAX) return "WAVAX";
        if (token == LINK) return "LINK";
        revert("Unknown token");
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function updateMintConsumer(address newMintConsumer) external onlyOwner {
        require(newMintConsumer != address(0), "Invalid mint consumer address");
        mintConsumer = IFunctionsConsumer(newMintConsumer);
    }

    function updateBurnConsumer(address newBurnConsumer) external onlyOwner {
        require(newBurnConsumer != address(0), "Invalid burn consumer address");
        burnConsumer = IFunctionsConsumer(newBurnConsumer);
    }

    function updateSubscriptionId(uint64 newSubscriptionId) external onlyOwner {
        subscriptionId = newSubscriptionId;
    }

    function setSourceChainTokenMapping(address sourceToken, address fujiToken) external onlyOwner {
        require(supportedTokens[fujiToken], "Unsupported Fuji token");
        sourceChainTokenMapping[sourceToken] = fujiToken;
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token balance");
        IERC20(token).safeTransfer(owner(), amount);
    }
}
