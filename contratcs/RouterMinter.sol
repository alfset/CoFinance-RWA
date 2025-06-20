// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IFunctionsConsumer.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./AssetToken.sol";

contract MintBurnManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IFunctionsConsumer public mintConsumer;
    IFunctionsConsumer public burnConsumer;
    AssetToken public assetToken;

    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public tokenDecimals;
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
    uint64 public subscriptionId;

    address public constant USDC = 0xAEFC91bc9426203374d25A535Cf09618e250D14e;
    address public constant WETH = 0xEc3f46FBF81dBE7Bc1360b2e2eE3bBcb01d3cBB0;
    address public constant WAVAX = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c;
    address public constant LINK = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;

    constructor(
        address _mintConsumer,
        address _burnConsumer,
        uint64 _subscriptionId,
        address _assetToken
    ) Ownable(msg.sender) {
        require(_mintConsumer != address(0), "Invalid mint consumer address");
        require(_burnConsumer != address(0), "Invalid burn consumer address");
        require(_assetToken != address(0), "Invalid asset token address");
        mintConsumer = IFunctionsConsumer(_mintConsumer);
        burnConsumer = IFunctionsConsumer(_burnConsumer);
        subscriptionId = _subscriptionId;
        assetToken = AssetToken(_assetToken);

        supportedTokens[USDC] = true;
        supportedTokens[WETH] = true;
        supportedTokens[WAVAX] = true;
        supportedTokens[LINK] = true;

        tokenDecimals[USDC] = 6;
        tokenDecimals[WETH] = 18;
        tokenDecimals[WAVAX] = 18;
        tokenDecimals[LINK] = 18;
    }

    /**
     * @notice Initiates a mint request by transferring payment tokens and calling the mint consumer
     * @param symbol The asset symbol to mint (e.g., AAPL)
     * @param paymentToken The payment token (USDC, WETH, WAVAX, LINK)
     * @param amount The amount of payment tokens to send
     * @dev Refunds use the same token (e.g., WETH for WETH, USDC for USDC) if mint fails
     */
    function initiateMint(
        string calldata symbol,
        address paymentToken,
        uint256 amount
    ) external nonReentrant {
        require(supportedTokens[paymentToken], "Unsupported payment token");
        require(amount > 0, "Amount must be greater than 0");
        require(
            IERC20(paymentToken).balanceOf(msg.sender) >= amount,
            "Insufficient token balance"
        );
        require(
            IERC20(paymentToken).allowance(msg.sender, address(this)) >= amount,
            "Insufficient token allowance"
        );
        uint256 balanceBefore = IERC20(paymentToken).balanceOf(address(this));
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);
        require(
            IERC20(paymentToken).balanceOf(address(this)) == balanceBefore + amount,
            "Token transfer failed"
        );
        string[] memory args = new string[](3);
        args[0] = symbol;
        args[1] = _getTokenSymbol(paymentToken);
        args[2] = _toString(amount);

        // Send request via mint consumer
        bytes32 requestId = mintConsumer.sendRequest(subscriptionId, args);

        // Store request details
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

    /**
     * @notice Initiates a burn request by burning asset tokens and calling the burn consumer
     * @param symbol The asset symbol to burn (e.g., AAPL)
     * @param paymentToken The payment token to receive (USDC, WETH, WAVAX, LINK)
     * @param amount The amount of asset tokens to burn
     */
    function initiateBurn(
        string calldata symbol,
        address paymentToken,
        uint256 amount
    ) external nonReentrant {
        require(supportedTokens[paymentToken], "Unsupported payment token");
        require(amount > 0, "Amount must be greater than 0");
        require(
            assetToken.balanceOf(msg.sender) >= amount,
            "Insufficient asset token balance"
        );
        require(
            assetToken.allowance(msg.sender, address(this)) >= amount,
            "Insufficient asset token allowance"
        );

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

    /**
     * @notice Processes the result of a mint or burn request
     * @param requestId The ID of the fulfilled request
     * @param isMint True for mint, false for burn
     * @dev For mint failures (result == 0), refunds the exact token deposited or reverts
     * @dev For burn failures (result == 0), mints back tAAPL tokens or reverts
     */
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
                uint256 balanceBefore = IERC20(request.paymentToken).balanceOf(address(this));
                if (balanceBefore >= request.amount) {
                    uint256 userBalanceBefore = IERC20(request.paymentToken).balanceOf(request.user);
                    IERC20(request.paymentToken).safeTransfer(request.user, request.amount);
                    if (
                        IERC20(request.paymentToken).balanceOf(request.user) == userBalanceBefore + request.amount &&
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
        } else {
            if (result > 0) {
                uint256 balanceBefore = IERC20(request.paymentToken).balanceOf(address(this));
                if (balanceBefore >= result) {
                    uint256 userBalanceBefore = IERC20(request.paymentToken).balanceOf(request.user);
                    IERC20(request.paymentToken).safeTransfer(request.user, result);
                    if (
                        IERC20(request.paymentToken).balanceOf(request.user) == userBalanceBefore + result &&
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
                // Refund asset tokens by minting back
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

    /**
     * @notice Callback function for consumer contracts to report results
     * @param requestId The ID of the consumer request
     * @param result The result from the consumer
     */
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

    /**
     * @notice Allows users to reclaim tokens for timed-out requests
     * @param requestId The ID of the timed-out request
     * @dev Refunds payment tokens for mint or mints back tAAPL for burn
     */
    function reclaimTimedOutRequest(bytes32 requestId) external nonReentrant {
        Request storage request = requests[requestId];
        require(!request.fulfilled, "Request already fulfilled");
        require(block.timestamp >= request.timestamp + REQUEST_TIMEOUT, "Request not timed out");
        require(msg.sender == request.user, "Not request owner");

        request.fulfilled = true;

        if (request.isMint) {
            // Refund payment tokens for mint
            uint256 balanceBefore = IERC20(request.paymentToken).balanceOf(address(this));
            require(
                balanceBefore >= request.amount,
                "Insufficient payment token balance for refund"
            );
            uint256 userBalanceBefore = IERC20(request.paymentToken).balanceOf(request.user);
            IERC20(request.paymentToken).safeTransfer(request.user, request.amount);
            require(
                IERC20(request.paymentToken).balanceOf(request.user) == userBalanceBefore + request.amount,
                "Refund transfer failed"
            );
            require(
                IERC20(request.paymentToken).balanceOf(address(this)) == balanceBefore - request.amount,
                "Contract balance not updated correctly"
            );
            emit Refunded(requestId, request.user, request.paymentToken, request.amount);
            emit RequestTimedOut(requestId, request.user, request.paymentToken, request.amount);
        } else {
            // Refund asset tokens for burn
            try assetToken.mint(request.user, request.amount) {
                emit Refunded(requestId, request.user, address(assetToken), request.amount);
                emit RequestTimedOut(requestId, request.user, address(assetToken), request.amount);
            } catch {
                revert("Failed to refund asset tokens");
            }
        }
    }

    /**
     * @notice Debug function to get the result from MintingFunctionsConsumer
     * @param requestId The ID of the mint request
     * @return result The result from the consumer (uint256)
     * @return isReceived True if the result has been received, false otherwise
     */
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

    /**
     * @notice Debug function to get the result from BurnFunctionsConsumer
     * @param requestId The ID of the burn request
     * @return result The result from the consumer (uint256)
     * @return isReceived True if the result has been received, false otherwise
     */
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

    /**
     * @notice Gets the contract's balance of a token
     * @param token The token address
     * @return The contract's balance
     */
    function getContractTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Checks if a request is timed out
     * @param requestId The ID of the request
     * @return True if timed out, false otherwise
     */
    function isRequestTimedOut(bytes32 requestId) external view returns (bool) {
        Request storage request = requests[requestId];
        return !request.fulfilled && block.timestamp >= request.timestamp + REQUEST_TIMEOUT;
    }

    /**
     * @notice Gets the consumer result status for a request
     * @param requestId The ID of the request
     * @return True if result received, false otherwise
     */
    function isConsumerResultReceived(bytes32 requestId) external view returns (bool) {
        return consumerResultsReceived[requestId];
    }

    /**
     * @notice Converts a token address to its symbol
     * @param token The token address
     * @return The token symbol
     */
    function _getTokenSymbol(address token) internal pure returns (string memory) {
        if (token == USDC) return "USDC";
        if (token == WETH) return "WETH";
        if (token == WAVAX) return "WAVAX";
        if (token == LINK) return "LINK";
        revert("Unknown token");
    }

    /**
     * @notice Converts a uint256 to a string
     * @param value The value to convert
     * @return The string representation
     */
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

    /**
     * @notice Updates the mint consumer address
     * @param newMintConsumer The new mint consumer address
     */
    function updateMintConsumer(address newMintConsumer) external onlyOwner {
        require(newMintConsumer != address(0), "Invalid mint consumer address");
        mintConsumer = IFunctionsConsumer(newMintConsumer);
    }

    /**
     * @notice Updates the burn consumer address
     * @param newBurnConsumer The new burn consumer address
     */
    function updateBurnConsumer(address newBurnConsumer) external onlyOwner {
        require(newBurnConsumer != address(0), "Invalid burn consumer address");
        burnConsumer = IFunctionsConsumer(newBurnConsumer);
    }

    /**
     * @notice Updates the subscription ID
     * @param newSubscriptionId The new subscription ID
     */
    function updateSubscriptionId(uint64 newSubscriptionId) external onlyOwner {
        subscriptionId = newSubscriptionId;
    }

    /**
     * @notice Withdraws stuck tokens (emergency use)
     * @param token The token address
     * @param amount The amount to withdraw
     */
    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "Insufficient token balance"
        );
        IERC20(token).safeTransfer(owner(), amount);
    }
}
