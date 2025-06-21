// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IAssetToken {
    function mint(address to, uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function MINTER_ROLE() external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
}
