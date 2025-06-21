// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IFunctionsConsumer.sol";
import "./IAssetToken.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/access/Ownable.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
contract MintBurnManager is Ownable, ReentrancyGuard, CCIPReceiver {
    using SafeERC20 for IERC20;

    IFunctionsConsumer public mintConsumer;
    IFunctionsConsumer public burnConsumer;
    IAssetToken public assetToken;
    IRouterClient public ccipRouter;
    LinkTokenInterface public linkToken;

    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public tokenDecimals;
    mapping(uint64 => bool) public supportedDestinationChains;
    mapping(uint64 => bool) public supportedSourceChains;
    uint256 public constant REQUEST_TIMEOUT = 5 minutes;

    struct Request {
        address user;
        address paymentToken;
        uint256 amount;
        bool isMint;
        bool fulfilled;
        uint256 timestamp;
        bytes32 consumerRequestId;
    }
    mapping(bytes32 => Request) public requests;
    mapping(bytes32 => bool) public consumerResultsReceived;

    event MintRequestInitiated(bytes32 indexed requestId, address indexed user, address paymentToken, uint256 amount);
    event BurnRequestInitiated(bytes32 indexed requestId, address indexed user, uint256 amount, address paymentToken);
    event MintCompleted(bytes32 indexed requestId, address indexed user, uint256 qty);
    event BurnCompleted(bytes32 indexed requestId, address indexed user, address paymentToken, uint256 tokenAmount);
    event Refunded(bytes32 indexed requestId, address indexed user, address token, uint256 amount);
    event RequestTimedOut(bytes32 indexed requestId, address indexed user, address token, uint256 amount);
    event ConsumerResultReceived(bytes32 indexed requestId, uint256 result);
    event ProcessResultAttempted(bytes32 indexed requestId, bool isMint, bool success);
    event TokensBridged(bytes32 indexed messageId, uint64 indexed destinationChainSelector, address receiver, uint256 amount);
    event CrossChainMintTriggered(bytes32 indexed messageId, uint64 indexed sourceChainSelector, address receiver, uint256 amount, address paymentToken);

    uint64 public subscriptionId;

    address public constant USDC = 0xc4BEc34199421c26AeB08e15Ca29E97b65dFC757;
    address public constant WETH = 0x11452c1b9fF5AA9169CEd6511cd7683c2cdCeC85;
    address public constant WAVAX = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c;
    address public constant LINK = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;

    constructor(
    address _mintConsumer,
    address _burnConsumer,
    uint64 _subscriptionId,
    address _assetToken,
    address _ccipRouter,
    address _linkToken
    ) Ownable() CCIPReceiver(_ccipRouter) {
        require(_mintConsumer != address(0), "Invalid mint consumer address");
        require(_burnConsumer != address(0), "Invalid burn consumer address");
        require(_assetToken != address(0), "Invalid asset token address");
        require(_ccipRouter != address(0), "Invalid CCIP router address");
        require(_linkToken != address(0), "Invalid LINK token address");

        mintConsumer = IFunctionsConsumer(_mintConsumer);
        burnConsumer = IFunctionsConsumer(_burnConsumer);
        subscriptionId = _subscriptionId;
        assetToken = IAssetToken(_assetToken);
        ccipRouter = IRouterClient(_ccipRouter);
        linkToken = LinkTokenInterface(_linkToken);

        supportedTokens[USDC] = true;
        supportedTokens[WETH] = true;
        supportedTokens[WAVAX] = true;
        supportedTokens[LINK] = true;

        tokenDecimals[USDC] = 6;
        tokenDecimals[WETH] = 18;
        tokenDecimals[WAVAX] = 18;
        tokenDecimals[LINK] = 18;
    }


    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        require(supportedSourceChains[message.sourceChainSelector], "Unsupported source chain");
        require(message.destTokenAmounts[0].token == WETH, "Expected WETH token");

        (address receiver, address paymentToken, uint256 amount, string memory symbol) = abi.decode(message.data, (address, address, uint256, string));

        require(supportedTokens[paymentToken], "Unsupported payment token");
        require(receiver != address(0), "Invalid receiver address");
        require(amount > 0, "Invalid amount");
        require(message.destTokenAmounts[0].token == paymentToken, "Token mismatch");
        require(message.destTokenAmounts[0].amount == amount, "Amount mismatch");
        string[] memory args = new string[](3);
        args[0] = symbol;
        args[1] = _getTokenSymbol(WETH);
        args[2] = _toString(amount);

        bytes32 requestId = mintConsumer.sendRequest(subscriptionId, args);

        requests[requestId] = Request({
            user: receiver,
            paymentToken: WETH,
            amount: amount,
            isMint: true,
            fulfilled: false,
            timestamp: block.timestamp,
            consumerRequestId: requestId
        });

        emit CrossChainMintTriggered(message.messageId, message.sourceChainSelector, receiver, amount, WETH);
    }

    function initiateMint(
        string calldata symbol,
        address paymentToken,
        uint256 amount
    ) external nonReentrant {
        require(supportedTokens[paymentToken], "Unsupported payment token");
        require(amount > 0, "Amount must be greater than 0");
        require(IERC20(paymentToken).balanceOf(msg.sender) >= amount, "Insufficient token balance");
        require(IERC20(paymentToken).allowance(msg.sender, address(this)) >= amount, "Insufficient token allowance");

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
            consumerRequestId: requestId
        });

        emit MintRequestInitiated(requestId, msg.sender, paymentToken, amount);
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
            consumerRequestId: requestId
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
                require(assetToken.hasRole(assetToken.MINTER_ROLE(), address(this)), "Contract not minter");
                try assetToken.mint(request.user, result) {
                    emit MintCompleted(requestId, request.user, result);
                } catch {
                    success = false;
                    uint256 balanceBefore = IERC20(request.paymentToken).balanceOf(address(this));
                    if (balanceBefore >= request.amount) {
                        IERC20(request.paymentToken).safeTransfer(request.user, request.amount);
                        emit Refunded(requestId, request.user, request.paymentToken, request.amount);
                    } else {
                        revert("Insufficient payment token balance for refund");
                    }
                }
            } else {
                uint256 balanceBefore = IERC20(request.paymentToken).balanceOf(address(this));
                if (balanceBefore >= request.amount) {
                    IERC20(request.paymentToken).safeTransfer(request.user, request.amount);
                    emit Refunded(requestId, request.user, request.paymentToken, request.amount);
                } else {
                    success = false;
                    revert("Insufficient payment token balance for refund");
                }
            }
        } else {
            if (result > 0) {
                uint256 balanceBefore = IERC20(request.paymentToken).balanceOf(address(this));
                if (balanceBefore >= result) {
                    IERC20(request.paymentToken).safeTransfer(request.user, result);
                    emit BurnCompleted(requestId, request.user, request.paymentToken, result);
                } else {
                    success = false;
                    try assetToken.mint(request.user, request.amount) {
                        emit Refunded(requestId, request.user, address(assetToken), request.amount);
                    } catch {
                        revert("Failed to refund asset tokens");
                    }
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

    function bridgeTokens(
        uint64 destinationChainSelector,s
        address receiver,
        uint256 amount
    ) external nonReentrant returns (bytes32 messageId) {
        require(supportedDestinationChains[destinationChainSelector], "Unsupported destination chain");
        require(receiver != address(0), "Invalid receiver address");
        require(amount > 0, "Amount must be greater than 0");
        require(assetToken.balanceOf(msg.sender) >= amount, "Insufficient tAAPL balance");
        require(assetToken.allowance(msg.sender, address(this)) >= amount, "Insufficient tAAPL allowance");

        assetToken.burnFrom(msg.sender, amount);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(""),
            tokenAmounts: new Client.EVMTokenAmount[](1),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 200_000})),
            feeToken: address(linkToken)
        });

        message.tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(assetToken),
            amount: amount
        });

        uint256 fees = ccipRouter.getFee(destinationChainSelector, message);
        require(linkToken.balanceOf(msg.sender) >= fees, "Insufficient LINK for fees");
        require(linkToken.allowance(msg.sender, address(this)) >= fees, "Insufficient LINK allowance");

        linkToken.transferFrom(msg.sender, address(this), fees);
        linkToken.approve(address(ccipRouter), fees);

        messageId = ccipRouter.ccipSend(destinationChainSelector, message);

        emit TokensBridged(messageId, destinationChainSelector, receiver, amount);
        return messageId;
    }

    function receiveConsumerResult(bytes32 requestId, uint256 result) external nonReentrant {
        require(msg.sender == address(mintConsumer) || msg.sender == address(burnConsumer), "Unauthorized caller");
        require(!consumerResultsReceived[requestId], "Result already received");
        consumerResultsReceived[requestId] = true;
        emit ConsumerResultReceived(requestId, result);

        Request memory request = requests[requestId];
        if (request.user != address(0) && !request.fulfilled) {
            try this.processResult(requestId, request.isMint) {
            } catch {
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
            uint256 balanceBefore = IERC20(request.paymentToken).balanceOf(address(this));
            require(balanceBefore >= request.amount, "Insufficient payment token balance for refund");
            IERC20(request.paymentToken).safeTransfer(request.user, request.amount);
            emit Refunded(requestId, request.user, request.paymentToken, request.amount);
            emit RequestTimedOut(requestId, request.user, request.paymentToken, request.amount);
        } else {
            try assetToken.mint(request.user, request.amount) {
                emit Refunded(requestId, request.user, address(assetToken), request.amount);
                emit RequestTimedOut(requestId, request.user, address(assetToken), request.amount);
            } catch {
                revert("Failed to refund asset tokens");
            }
        }
    }

    function addSupportedSourceChain(uint64 chainSelector) external onlyOwner {
        supportedSourceChains[chainSelector] = true;
    }

    function removeSupportedSourceChain(uint64 chainSelector) external onlyOwner {
        supportedSourceChains[chainSelector] = false;
    }

    function addSupportedDestinationChain(uint64 chainSelector) external onlyOwner {
        supportedDestinationChains[chainSelector] = true;
    }

    function removeSupportedDestinationChain(uint64 chainSelector) external onlyOwner {
        supportedDestinationChains[chainSelector] = false;
    }

    function updateCCIPRouter(address newRouter) external onlyOwner {
        require(newRouter != address(0), "Invalid router address");
        ccipRouter = IRouterClient(newRouter);
    }

    function getMintConsumerResult(bytes32 requestId) external view returns (uint256 result, bool isReceived) {
        Request memory request = requests[requestId];
        require(request.isMint, "Not a mint request");
        isReceived = consumerResultsReceived[request.consumerRequestId];
        if (isReceived) {
            result = mintConsumer.getResult();
        } else {
            result = 0;
        }
        return (result, isReceived);
    }

    function getBurnConsumerResult(bytes32 requestId) external view returns (uint256 result, bool isReceived) {
        Request memory request = requests[requestId];
        require(!request.isMint, "Not a burn request");
        isReceived = consumerResultsReceived[request.consumerRequestId];
        if (isReceived) {
            result = burnConsumer.getResult();
        } else {
            result = 0;
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

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token balance");
        IERC20(token).safeTransfer(owner(), amount);
    }
}
