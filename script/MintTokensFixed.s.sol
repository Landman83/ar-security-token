// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/interfaces/IToken.sol";
import "../src/interfaces/IModularCompliance.sol";
import "../src/roles/AgentRole.sol";

/**
 * @title MintTokensFixedScript
 * @dev Script to mint tokens to a specified address with proper error handling
 */
contract MintTokensFixedScript is Script {
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
        
        // Start broadcast with deployer's private key
        vm.startBroadcast(deployer);
        
        // Get token instance
        IToken token = IToken(tokenAddress);
        
        // Check token details first (less likely to fail than balance checks)
        console.log("Checking token details...");
        try token.name() returns (string memory name) {
            console.log("Token name:", name);
        } catch {
            console.log("Failed to get token name, interface may not match or contract not deployed correctly");
        }
        
        try token.symbol() returns (string memory symbol) {
            console.log("Token symbol:", symbol);
        } catch {
            console.log("Failed to get token symbol");
        }
        
        try token.decimals() returns (uint8 decimals) {
            console.log("Token decimals:", decimals);
            
            // Calculate actual mint amount with decimals
            uint256 actualMintAmount = mintAmount * (10 ** decimals);
            console.log("Actual mint amount with decimals:", actualMintAmount);
            
            // Check token pause status
            try token.paused() returns (bool isPaused) {
                if (isPaused) {
                    console.log("WARNING: Token is paused. Need to unpause before transfers will work.");
                    
                    // Try to unpause the token
                    try token.unpause() {
                        console.log("Token has been unpaused successfully.");
                    } catch Error(string memory reason) {
                        console.log("Failed to unpause token with reason:", reason);
                        console.log("You may not have agent role required to unpause.");
                    } catch {
                        console.log("Failed to unpause token with unknown error");
                    }
                } else {
                    console.log("Token is not paused. Transfers should work normally.");
                }
            } catch {
                console.log("Failed to check token pause status");
            }
            
            // Mint tokens (this requires agent role)
            console.log("Attempting to mint", mintAmount, "tokens to", recipient);
            try token.mint(recipient, actualMintAmount) {
                console.log("Minting successful!");
                
                // Try to verify the new balance
                try token.balanceOf(recipient) returns (uint256 newBalance) {
                    console.log("New balance of recipient:", newBalance / (10 ** decimals));
                } catch {
                    console.log("Failed to verify balance after minting, but mint transaction succeeded");
                }
            } catch Error(string memory reason) {
                console.log("Minting failed with reason:", reason);
                
                // Check if user has agent role
                console.log("Checking if deployer has agent role...");
                AgentRole agentRole = AgentRole(tokenAddress);
                try agentRole.isAgent(deployer) returns (bool isAgent) {
                    if (!isAgent) {
                        console.log("Deployer does NOT have agent role. This is needed for minting!");
                        
                        console.log("Attempting to add deployer as agent...");
                        try agentRole.addAgent(deployer) {
                            console.log("Successfully added deployer as agent.");
                            
                            // Try minting again
                            try token.mint(recipient, actualMintAmount) {
                                console.log("Second minting attempt successful!");
                            } catch Error(string memory reason2) {
                                console.log("Second minting attempt failed with reason:", reason2);
                            } catch {
                                console.log("Second minting attempt failed with unknown error");
                            }
                        } catch {
                            console.log("Failed to add deployer as agent. Only token owner can do this.");
                        }
                    } else {
                        console.log("Deployer has agent role, but minting still failed.");
                    }
                } catch {
                    console.log("Failed to check agent role status");
                }
            } catch {
                console.log("Minting failed with unknown error");
            }
        } catch {
            console.log("Failed to get token decimals");
        }
        
        vm.stopBroadcast();
    }
}