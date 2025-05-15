// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestUSD (tUSD)
 * @dev ERC20 token with EIP-2612 permit functionality for meta-transactions
 * This is a test stablecoin implementation that allows gasless approvals
 */
contract TestUSD is ERC20, ERC20Permit, Ownable {
    uint8 private _decimals;

    /**
     * @dev Constructor that sets up the token with name, symbol, and decimals
     * @param initialSupply The initial supply to mint to the deployer
     * @param decimalsValue The number of decimals for the token (typically 18 for USD stablecoins)
     */
    constructor(
        uint256 initialSupply,
        uint8 decimalsValue
    ) ERC20("Test USD", "tUSD") ERC20Permit("Test USD") Ownable(msg.sender) {
        _decimals = decimalsValue;
        // Mint initial supply to the deployer
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply * (10 ** decimalsValue));
        }
    }

    /**
     * @dev Override decimals to use custom value
     * @return The number of decimals for the token
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Allows the owner to mint new tokens
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint (without decimals)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Allows the owner to burn tokens from any address
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    /**
     * @dev Burns tokens from the caller's balance
     * @param amount The amount of tokens to burn
     */
    function burnSelf(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}