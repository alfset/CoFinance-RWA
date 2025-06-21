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
 * @title ProofOfReserveManager
 * @notice This contract uses Chainlink Functions to fetch position data for a symbol from Alpaca to prove reserves
 * @dev This contract uses hardcoded values and should not be used in production.
 */
contract ProofOfReserveManager is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;
    uint256 public positionQty; 
    error UnexpectedRequestID(bytes32 requestId);
    event Response(
        bytes32 indexed requestId,
        uint256 positionQty,
        bytes response,
        bytes err
    );

    // Router address - Hardcoded for Avalanche Fuji
    // Check to get the router address for your supported network: https://docs.chain.link/chainlink-functions/supported-networks
    address router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;

    // JavaScript source code
    // Fetches position data for a symbol from Alpaca and returns quantity in 1e18
    string source =
        "const alpacaKey = secret.AlpacaKey;"
        "const alpacaSecret = secret.AlpacaSecret;"
        "const symbol = args[0];"
        "const marketStatusRes = await Functions.makeHttpRequest({"
        " url: `https://paper-api.alpaca.markets/v2/clock`,"
        " headers: { 'APCA-API-KEY-ID': alpacaKey, 'APCA-API-SECRET-KEY': alpacaSecret }"
        "});"
        "if (marketStatusRes.error) throw Error('Market status check failed');"
        "const positionRes = await Functions.makeHttpRequest({"
        " url: `https://paper-api.alpaca.markets/v2/positions/${symbol}`,"
        " headers: { 'APCA-API-KEY-ID': alpacaKey, 'APCA-API-SECRET-KEY': alpacaSecret }"
        "});"
        "if (positionRes.error || !positionRes.data?.qty) return Functions.encodeUint256(0);"
        "const qty = parseFloat(positionRes.data.qty) || 0;"
        "const qtyInt = Math.round(qty * 1e18);"
        "return Functions.encodeUint256(qtyInt);";
    uint32 gasLimit = 300000;

    // donID - Hardcoded for Avalanche Fuji
    // Check to get the donID for your supported network: https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 donID = 0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;

    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor() FunctionsClient(router) ConfirmedOwner(msg.sender) {}

    /**
     * @notice Sends a Chainlink Functions request to fetch position data for a symbol from Alpaca
     * @param subscriptionId The ID for the Chainlink subscription
     * @param args The arguments to pass to the HTTP request: [symbol]
     * @return requestId The ID of the request
     */
    function sendRequest(
        uint64 subscriptionId,
        string[] calldata args
    ) external onlyOwner returns (bytes32 requestId) {
        if (args.length != 1) revert("Invalid arguments length");

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

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data (position quantity in 1e18)
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

        uint256 _positionQty = 0;
        if (response.length == 32 && err.length == 0) {
            _positionQty = abi.decode(response, (uint256));
        }

        s_lastResponse = response;
        positionQty = _positionQty;
        s_lastError = err;

        emit Response(requestId, _positionQty, response, err);
    }
}
