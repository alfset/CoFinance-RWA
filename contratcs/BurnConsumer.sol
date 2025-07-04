// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts@1.4.0/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts@1.4.0/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts@1.4.0/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

/**
 * Request testnet LINK and AVAX here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest AVAX and LINK faucets here: https://docs.chain.link/resources/link-token-contracts/
 */

/**
 * @title BurnFunctionsConsumer
 * @notice This contract uses Chainlink Functions to place market sell orders on Alpaca and return payment tokens
 * @dev This contract uses hardcoded values and should not be used in production.
 */
contract BurnFunctionsConsumer is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;
    uint256 public tokenAmount;
    mapping(address => bool) public CoFIRouter;
    error UnexpectedRequestID(bytes32 requestId);
    event Response(
        bytes32 indexed requestId,
        uint256 tokenAmount,
        bytes response,
        bytes err
    );

    // Router address - Hardcoded for Avalanche Fuji
    // Check to get the router address for your supported network: https://docs.chain.link/chainlink-functions/supported-networks
    address router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;

    // source code chainlink Functions
    // Places a market sell order on Alpaca and returns the amount of payment token to send
   string source = 
        "const alpacaKey = secret.AlpacaKey;"
        "const alpacaSecret = secret.AlpacaSecret;"
        "const symbolToBurn = args[0];"
        "const paymentTokenSymbol = args[1];"
        "const qtyToSellRaw = args[2];"
        "const marketStatusRes = await Functions.makeHttpRequest({"
        "  url: `https://paper-api.alpaca.markets/v2/clock`,"
        "  headers: {"
        "    'APCA-API-KEY-ID': alpacaKey,"
        "    'APCA-API-SECRET-KEY': alpacaSecret"
        "  }"
        "});"
        "if (marketStatusRes.error || !marketStatusRes.data?.is_open) return Functions.encodeUint256(0);"
        "const totalQty = parseFloat(qtyToSellRaw) / 1e18;"
        "const splitQty = totalQty / 4;"
        "const orderIds = [];"
        "for (let i = 0; i < 4; i++) {"
        "  const order = await Functions.makeHttpRequest({"
        "    url: 'https://paper-api.alpaca.markets/v2/orders',"
        "    method: 'POST',"
        "    headers: {"
        "      'APCA-API-KEY-ID': alpacaKey,"
        "      'APCA-API-SECRET-KEY': alpacaSecret,"
        "      'Content-Type': 'application/json'"
        "    },"
        "    data: {"
        "      symbol: symbolToBurn,"
        "      qty: splitQty.toString(),"
        "      side: 'sell',"
        "      type: 'market',"
        "      time_in_force: 'day'"
        "    }"
        "  });"
        "  if (order.error || !order.data?.id) throw Error('Order failed');"
        "  orderIds.push(order.data.id);"
        "}"
        "let totalUsd = 0;"
        "for (let i = 0; i < orderIds.length; i++) {"
        "  let filled = false;"
        "  let attempts = 0;"
        "  let statusRes;"
        "  while (attempts < 10 && !filled) {"
        "    statusRes = await Functions.makeHttpRequest({"
        "      url: `https://paper-api.alpaca.markets/v2/orders/${orderIds[i]}`,"
        "      headers: {"
        "        'APCA-API-KEY-ID': alpacaKey,"
        "        'APCA-API-SECRET-KEY': alpacaSecret"
        "      }"
        "    });"
        "    if (statusRes.error) throw Error('Status check failed');"
        "    const status = statusRes.data?.status;"
        "    if (status === 'filled') {"
        "      filled = true;"
        "      const avgPrice = parseFloat(statusRes.data?.filled_avg_price) || 0;"
        "      const filledQty = parseFloat(statusRes.data?.filled_qty) || 0;"
        "      totalUsd += avgPrice * filledQty;"
        "    } else if (['canceled', 'expired', 'rejected'].includes(status)) {"
        "      break;"
        "    } else {"
        "      await new Promise(r => setTimeout(r, 3000));"
        "    }"
        "    attempts++;"
        "  }"
        "}"
        "if (totalUsd === 0) return Functions.encodeUint256(0);"
        "const coinGeckoIdMap = { 'USDC': 'usd-coin', 'WETH': 'ethereum', 'WAVAX': 'avalanche-2', 'LINK': 'chainlink' };"
        "const coinGeckoId = coinGeckoIdMap[paymentTokenSymbol.toUpperCase()] || paymentTokenSymbol.toLowerCase();"
        "const priceRes = await Functions.makeHttpRequest({"
        "  url: `https://api.coingecko.com/api/v3/simple/price?ids=${coinGeckoId}&vs_currencies=usd`"
        "});"
        "if (priceRes.error) throw Error('Price fetch failed');"
        "const priceUsd = parseFloat(priceRes.data[coinGeckoId].usd);"
        "const tokenAmount = totalUsd / priceUsd;"
        "const multiplier = paymentTokenSymbol.toUpperCase() === 'USDC' ? 1e6 : 1e18;"
        "const tokenAmountInt = Math.round(tokenAmount * multiplier * 0.9);"
        "return Functions.encodeUint256(tokenAmountInt);";

    uint32 gasLimit = 300000;

    // donID - Hardcoded for Avalanche Fuji
    // Check to get the donID for your supported network: https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 donID = 0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;

    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor() FunctionsClient(router) ConfirmedOwner(msg.sender) {}

    /**
     * @notice Sends a Chainlink Functions request to place a market sell order on Alpaca
     * @param subscriptionId The ID for the Chainlink subscription
     * @param args The arguments to pass to the HTTP request: [symbolToBurn, paymentTokenSymbol, qtyToSell]
     * @return requestId The ID of the request
     */
    function sendRequest(
        uint64 subscriptionId,
        string[] calldata args
    ) external returns (bytes32 requestId) {
        require(CoFIRouter[msg.sender], "Caller not authorized");
        if (args.length != 3) revert("Invalid arguments length");

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);
        req.setArgs(args);

        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        return s_lastRequestId;
    }

     function addRouter(address caller) external onlyOwner {
    CoFIRouter[caller] = true;
    }

    function revokeRouter(address caller) external onlyOwner {
    CoFIRouter[caller] = false;
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data (token amount to send in token-specific decimals)
     * @param err Any errors from the Functions request
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId);
        }

        uint256 _tokenAmount = 0;
        if (response.length == 32 && err.length == 0) {
            _tokenAmount = abi.decode(response, (uint256));
        }

        s_lastResponse = response;
        tokenAmount = _tokenAmount;
        s_lastError = err;

        emit Response(requestId, _tokenAmount, response, err);
    }
}
