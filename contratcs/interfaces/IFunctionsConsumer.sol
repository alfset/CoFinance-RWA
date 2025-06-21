// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IFunctionsConsumer {
    /**
     * @notice Sends a Chainlink Functions request to place a market order on Alpaca
     * @param subscriptionId The ID for the Chainlink subscription
     * @param args The arguments to pass to the HTTP request: [symbol, paymentTokenSymbol, amount]
     * @return requestId The ID of the request
     */
    function sendRequest(uint64 subscriptionId, string[] calldata args) external returns (bytes32 requestId);

    /**
     * @notice Retrieves the result of the last fulfilled request
     * @return result The quantity of tAAPL to mint (for minting) or payment tokens to send (for burning)
     */
    function getResult() external view returns (uint256);

    /**
     * @notice Authorizes a caller to send requests
     * @param caller The address to authorize
     */
    function addRouter(address caller) external;

    /**
     * @notice Revokes authorization for a caller
     * @param caller The address to revoke
     */
    function revokeRouter(address caller) external;
}
