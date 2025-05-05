// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/interfaces/IToken.sol";

/**
 * @title MintTokensScript
 * @dev Script to mint tokens to a specified address
 */
contract MintTokensScript is Script {
    function run() public {
        // Get deployer address from environment
        address deployer;
        try vm.envAddress("DEPLOYER_ADDRESS") returns (address deployerAddr) {
            deployer = deployerAddr;
            console.log("Using deployer address from environment:", deployer);
        } catch {
            deployer = msg.sender; // Fallback to msg.sender if no environment variable
            console.log("No DEPLOYER_ADDRESS set, using msg.sender as deployer:", deployer);
        }
        
        // Get token address - required
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        console.log("Token address:", tokenAddress);
        
        // Get recipient address - defaults to deployer if not specified
        address recipient;
        try vm.envAddress("RECIPIENT_ADDRESS") returns (address recipientAddr) {
            recipient = recipientAddr;
            console.log("Recipient address from environment:", recipient);
        } catch {
            recipient = deployer; // Fallback to deployer if no recipient specified
            console.log("No RECIPIENT_ADDRESS set, using deployer as recipient:", recipient);
        }
        
        // Get amount to mint (in whole tokens)
        uint256 mintAmount = vm.envUint("MINT_AMOUNT");
        if (mintAmount == 0) {
            mintAmount = 1000; // Default to 1000 tokens if not specified
            console.log("No MINT_AMOUNT set, using default amount:", mintAmount);
        } else {
            console.log("Mint amount from environment:", mintAmount);
        }
        
        // Get token decimals
        uint8 decimals = 18; // Default to 18 decimals
        try vm.envUint("TOKEN_DECIMALS") returns (uint256 decVal) {
            decimals = uint8(decVal);
        } catch {}
        console.log("Using token decimals:", decimals);
        
        // Calculate actual mint amount with decimals
        uint256 actualMintAmount = mintAmount * (10 ** decimals);
        console.log("Actual mint amount with decimals:", actualMintAmount);
        
        // Start broadcast with deployer's private key
        vm.startBroadcast(deployer);
        
        // Get token instance
        IToken token = IToken(tokenAddress);
        
        // Check current balance before minting
        try token.balanceOf(recipient) returns (uint256 currentBalance) {
            console.log("Current balance of recipient:", currentBalance / (10 ** decimals));
        } catch {
            console.log("Failed to get current balance");
        }
        
        // Mint tokens
        console.log("Attempting to mint", mintAmount, "tokens to", recipient);
        try token.mint(recipient, actualMintAmount) {
            console.log("Minting successful!");
            
            // Verify the new balance
            try token.balanceOf(recipient) returns (uint256 newBalance) {
                console.log("New balance of recipient:", newBalance / (10 ** decimals));
            } catch {
                console.log("Failed to get updated balance");
            }
        } catch Error(string memory reason) {
            console.log("Minting failed with reason:", reason);
        } catch {
            console.log("Minting failed with unknown error");
        }
        
        vm.stopBroadcast();
    }
}