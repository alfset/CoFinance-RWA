// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts@1.4.0/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts@1.4.0/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts@1.4.0/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MintingFunctionsConsumer is FunctionsClient, ConfirmedOwner, ReentrancyGuard {
    using FunctionsRequest for FunctionsRequest.Request;

    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;
    uint256 public s_lastResult;
    mapping(address => bool) public CoFIRouter;
    mapping(bytes32 => bool) public requestProcessed;
    mapping(address => RequestInfo) public requestsInfo;
    mapping(bytes32 => address) public requestIdToUser;
    uint256 public nonce;
    bool public isProcessingRequest;
    uint256 public constant REQUEST_TIMEOUT = 60;

    struct RequestInfo {
        bytes32 requestId;
        bytes32 requestKey;
        uint256 amount;
        bool isPending;
        uint256 timestamp;
        string symbol;
        string token;
    }

    error UnexpectedRequestID(bytes32 requestId);
    error DuplicateRequest(bytes32 requestKey);
    error InvalidArguments();
    error UnauthorizedCaller();
    error InvalidAmountString(string amount);
    error UserHasPendingRequest(address user);
    error RequestTimedOut(address user);
    error ContractLocked();

    event Response(bytes32 indexed requestId, uint256 qty, bytes response, bytes err);
    event RequestSent(bytes32 indexed requestId, address indexed user, string symbol, string token, uint256 amount);
    event RequestCleared(address indexed user, bytes32 requestId);

    address router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;
    bytes32 donID = 0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;

    string source =
        "const alpacaKey = 'Secret';"
        "const alpacaSecret = 'Secret';"
        "const symbolToMint = args[0];"
        "const paymentTokenSymbol = args[1];"
        "const amountPaidRaw = args[2];"
        "if (!symbolToMint || !paymentTokenSymbol || !amountPaidRaw) throw Error('Missing arguments');"
        "const marketStatusRes = await Functions.makeHttpRequest({"
        "  url: `https://paper-api.alpaca.markets/v2/clock`,"
        "  headers: { 'APCA-API-KEY-ID': alpacaKey, 'APCA-API-SECRET-KEY': alpacaSecret },"
        "  timeout: 5000"
        "});"
        "if (marketStatusRes.error || !marketStatusRes.data) throw Error(`Market status check failed: ${marketStatusRes.error?.message || 'No data'}`);"
        "if (!marketStatusRes.data.is_open) return Functions.encodeUint256(0);"
        "const divisor = paymentTokenSymbol.toUpperCase() === 'USDC' ? 1e6 : 1e18;"
        "const amountPaid = Number(amountPaidRaw) / divisor;"
        "if (isNaN(amountPaid) || amountPaid <= 0) throw Error(`Invalid amount: ${amountPaidRaw}`);"
        "const coinGeckoIdMap = { 'USDC': 'usd-coin', 'WETH': 'ethereum', 'WAVAX': 'avalanche', 'LINK': 'chainlink' };"
        "const coinGeckoId = coinGeckoIdMap[paymentTokenSymbol.toUpperCase()] || paymentTokenSymbol.toLowerCase();"
        "const priceRes = await Functions.makeHttpRequest({"
        "  url: `https://api.coingecko.com/api/v3/simple/price?ids=${coinGeckoId}&vs_currencies=usd`,"
        "  timeout: 5000"
        "});"
        "if (priceRes.error || !priceRes.data?.[coinGeckoId]?.usd) throw Error(`Price fetch failed: ${priceRes.error?.message || 'No price data'}`);"
        "const priceUsd = Number(priceRes.data[coinGeckoId].usd);"
        "if (isNaN(priceUsd) || priceUsd <= 0) throw Error(`Invalid price: ${priceUsd}`);"
        "const notionalUsd = Math.max((amountPaid * priceUsd * 0.9).toFixed(2), 1);"
        "const orderNotional = Math.max((notionalUsd / 4).toFixed(2), 1);"
        "const orderIds = [];"
        "console.log(`Splitting ${notionalUsd} USD into 4 orders of ${orderNotional} USD each`);"
        "const maxRetries = 3;"
        "const retryDelay = 2000;"
        "for (let i = 0; i < 4; i++) {"
        "  let order;"
        "  for (let attempt = 1; attempt <= maxRetries; attempt++) {"
        "    try {"
        "      order = await Functions.makeHttpRequest({"
        "        url: 'https://paper-api.alpaca.markets/v2/orders',"
        "        method: 'POST',"
        "        headers: { 'APCA-API-KEY-ID': alpacaKey, 'APCA-API-SECRET-KEY': alpacaSecret, 'Content-Type': 'application/json' },"
        "        data: { symbol: symbolToMint.toUpperCase(), notional: orderNotional, side: 'buy', type: 'market', time_in_force: 'day' },"
        "        timeout: 5000"
        "      });"
        "      if (order.error || !order.data?.id) throw Error(`Order ${i + 1} failed: ${order.error?.message || JSON.stringify(order)}`);"
        "      console.log(`Order ${i + 1} placed (attempt ${attempt}): ID ${order.data.id}, Symbol ${symbolToMint}, Notional ${orderNotional}`);"
        "      orderIds.push(order.data.id);"
        "      break;"
        "    } catch (e) {"
        "      console.log(`Order ${i + 1} attempt ${attempt} failed: ${e.message}`);"
        "      if (attempt === maxRetries) throw Error(`Order ${i + 1} failed after ${maxRetries} attempts: ${e.message}`);"
        "      await new Promise(resolve => setTimeout(resolve, retryDelay));"
        "    }"
        "  }"
        "}"
        "let totalFilledQty = 0;"
        "for (let i = 0; i < orderIds.length; i++) {"
        "  let filled = false;"
        "  for (let j = 0; j < 10 && !filled; j++) {"
        "    const statusRes = await Functions.makeHttpRequest({"
        "      url: `https://paper-api.alpaca.markets/v2/orders/${orderIds[i]}`,"
        "      headers: { 'APCA-API-KEY-ID': alpacaKey, 'APCA-API-SECRET-KEY': alpacaSecret },"
        "      timeout: 5000"
        "    });"
        "    if (statusRes.error || !statusRes.data) throw Error(`Status check for order ${orderIds[i]} failed: ${statusRes.error?.message || 'No data'}`);"
        "    const status = statusRes.data.status;"
        "    console.log(`Order ${i + 1} status check ${j + 1}: ${status}`);"
        "    if (status === 'filled') {"
        "      filled = true;"
        "      const filledQty = Number(statusRes.data?.filled_qty) || 0;"
        "      if (isNaN(filledQty) || filledQty <= 0) throw Error(`Invalid quantity for order ${orderIds[i]}: ${filledQty}`);"
        "      totalFilledQty += filledQty;"
        "    } else if (['canceled', 'expired', 'rejected'].includes(status)) {"
        "      console.log(`Order ${orderIds[i]} not filled: ${status}`);"
        "      filled = true;"
        "    } else {"
        "      await new Promise(r => setTimeout(r, 3000));"
        "    }"
        "  }"
        "}"
        "if (totalFilledQty == 0) return Functions.encodeUint256(0);"
        "const qtyInt = Math.round(totalFilledQty * 1e18);"
        "console.log(`Total filled quantity: ${totalFilledQty}, Encoded: ${qtyInt}`);"
        "return Functions.encodeUint256(qtyInt);";

    uint32 gasLimit = 500000;

    constructor() FunctionsClient(router) ConfirmedOwner(msg.sender) {}

    function stringToUint(string memory str) internal pure returns (uint256) {
        bytes memory b = bytes(str);
        if (b.length == 0) revert InvalidAmountString(str);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] < 0x30 || b[i] > 0x39) revert InvalidAmountString(str);
            result = result * 10 + (uint8(b[i]) - 0x30);
        }
        return result;
    }

    function sendRequest(
        uint64 subscriptionId,
        string[] calldata args,
        address user
    ) external nonReentrant returns (bytes32 requestId) {
        if (!CoFIRouter[msg.sender]) revert UnauthorizedCaller();
        if (args.length != 3) revert InvalidArguments();
        if (user == address(0)) revert InvalidArguments();
        if (isProcessingRequest) revert ContractLocked();

        isProcessingRequest = true;

        RequestInfo storage info = requestsInfo[user];
        if (info.isPending) {
            if (block.timestamp > info.timestamp + REQUEST_TIMEOUT) {
                emit RequestCleared(user, info.requestId);
                delete requestsInfo[user];
                delete requestIdToUser[info.requestId];
            } else {
                isProcessingRequest = false;
                revert UserHasPendingRequest(user);
            }
        }

        bytes32 requestKey = keccak256(abi.encode(user, args[0], args[1], args[2], nonce));
        if (requestProcessed[requestKey]) {
            isProcessingRequest = false;
            revert DuplicateRequest(requestKey);
        }

        uint256 amount = stringToUint(args[2]);
        nonce++;
        requestProcessed[requestKey] = true;
        info.requestKey = requestKey;
        info.amount = amount;
        info.isPending = true;
        info.timestamp = block.timestamp;
        info.symbol = args[0];
        info.token = args[1];

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);
        req.setArgs(args);

        bytes32 newRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        s_lastRequestId = newRequestId;
        info.requestId = newRequestId;
        requestIdToUser[newRequestId] = user;

        isProcessingRequest = false;
        emit RequestSent(newRequestId, user, args[0], args[1], amount);
        return newRequestId;
    }

    function addRouter(address caller) external onlyOwner {
        CoFIRouter[caller] = true;
    }

    function revokeRouter(address caller) external onlyOwner {
        CoFIRouter[caller] = false;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) revert UnexpectedRequestID(requestId);

        uint256 _qty = 0;
        if (response.length == 32 && err.length == 0) {
            _qty = abi.decode(response, (uint256));
        }

        address user = requestIdToUser[requestId];
        if (user != address(0)) {
            RequestInfo storage info = requestsInfo[user];
            if (info.isPending && info.requestId == requestId) {
                info.isPending = false;
                emit RequestCleared(user, requestId);
            }
            delete requestIdToUser[requestId];
        }

        s_lastResponse = response;
        s_lastResult = _qty;
        s_lastError = err;

        emit Response(requestId, _qty, response, err);
    }

    function getResult() external view returns (uint256) {
        return s_lastResult;
    }

    function clearTimedOutRequest(address user) external {
        RequestInfo storage info = requestsInfo[user];
        if (!info.isPending) revert InvalidArguments();
        if (block.timestamp <= info.timestamp + REQUEST_TIMEOUT) revert InvalidArguments();

        info.isPending = false;
        delete requestIdToUser[info.requestId];
        emit RequestCleared(user, info.requestId);
    }
}
