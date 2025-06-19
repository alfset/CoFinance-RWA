// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract AssetToken is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    /**
     * @notice Initializes the token with name "tAAPL" and symbol "tAAPL"
     * @param admin The initial admin address (e.g., deployer or MintBurnManager)
     */
    constructor(address admin) ERC20("tAAPL", "tAAPL") {
        require(admin != address(0), "Admin address cannot be zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }

    /**
     * @notice Mints new tokens to the specified address
     * @param to The recipient address
     * @param amount The amount of tokens to mint (in 1e18)
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be greater than 0");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    /**
     * @notice Burns tokens from the caller's account
     * @param amount The amount of tokens to burn (in 1e18)
     */
    function burn(uint256 amount) public override {
        require(amount > 0, "Amount must be greater than 0");
        super.burn(amount);
        emit Burned(msg.sender, amount);
    }

    /**
     * @notice Burns tokens from a specified account with allowance
     * @param account The account to burn from
     * @param amount The amount of tokens to burn (in 1e18)
     */
    function burnFrom(address account, uint256 amount) public override {
        require(amount > 0, "Amount must be greater than 0");
        super.burnFrom(account, amount);
        emit Burned(account, amount);
    }

    /**
     * @notice Grants minter role to an address
     * @param account The address to grant the minter role
     */
    function grantMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(account != address(0), "Account cannot be zero address");
        grantRole(MINTER_ROLE, account);
    }

    /**
     * @notice Revokes minter role from an address
     * @param account The address to revoke the minter role
     */
    function revokeMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(account != address(0), "Account cannot be zero address");
        revokeRole(MINTER_ROLE, account);
    }
}
