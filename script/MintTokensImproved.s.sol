// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/interfaces/IToken.sol";
import "../src/interfaces/IModularCompliance.sol";
import "../src/roles/AgentRole.sol";
import "../src/interfaces/IInsiderRegistry.sol";
import "st-identity-registry/src/interfaces/IAttributeRegistry.sol";
import "st-identity-registry/src/libraries/Attributes.sol";

/**
 * @title MintTokensImproved
 * @dev Script to mint tokens to an address specified in MINT_ADDRESS with comprehensive error handling
 */
contract MintTokensImproved is Script {
    function run() public {
        console.log("\n=== Token Minting Script ===");
        
        // Validate required environment variables
        _validateEnvironmentVariables();
        
        // Get addresses from environment
        address deployer = _getDeployerAddress();
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        console.log("Token address:", tokenAddress);
        
        // Get mint destination address
        address mintAddress = vm.envAddress("MINT_ADDRESS");
        console.log("Mint destination address:", mintAddress);
        
        // Get amount to mint (in whole tokens)
        uint256 mintAmount = vm.envUint("MINT_AMOUNT");
        if (mintAmount == 0) {
            mintAmount = 1000; // Default to 1000 tokens if not specified
            console.log("No MINT_AMOUNT set, using default amount:", mintAmount);
        } else {
            console.log("Mint amount from environment:", mintAmount);
        }
        
        vm.startBroadcast(deployer);
        
        // Execute the minting process with detailed error handling
        _executeMinting(deployer, tokenAddress, mintAddress, mintAmount);
        
        vm.stopBroadcast();
    }
    
    function _validateEnvironmentVariables() internal {
        // Validate all required environment variables exist
        string memory errorMsg = "";
        
        try vm.envAddress("TOKEN_ADDRESS") {} catch {
            errorMsg = string(abi.encodePacked(errorMsg, "TOKEN_ADDRESS environment variable is required. "));
        }
        
        try vm.envAddress("MINT_ADDRESS") {} catch {
            errorMsg = string(abi.encodePacked(errorMsg, "MINT_ADDRESS environment variable is required. "));
        }
        
        if (bytes(errorMsg).length > 0) {
            revert(errorMsg);
        }
    }
    
    function _getDeployerAddress() internal returns (address) {
        address deployer;
        try vm.envAddress("DEPLOYER_ADDRESS") returns (address deployerAddr) {
            deployer = deployerAddr;
            console.log("Using deployer address from environment:", deployer);
        } catch {
            deployer = msg.sender; // Fallback to msg.sender if no environment variable
            console.log("No DEPLOYER_ADDRESS set, using msg.sender as deployer:", deployer);
        }
        return deployer;
    }
    
    function _executeMinting(address deployer, address tokenAddress, address mintAddress, uint256 mintAmount) internal {
        // Verify code exists at token address
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(tokenAddress)
        }
        
        if (codeSize == 0) {
            console.log("ERROR: No code at token address. Token not deployed at", tokenAddress);
            return;
        }
        
        console.log("Code verified at token address");
        
        // Get token instance
        IToken token = IToken(tokenAddress);
        
        // Basic token details check
        bool tokenDetailsSuccess = true;
        string memory tokenName;
        string memory tokenSymbol;
        uint8 tokenDecimals;
        
        try token.name() returns (string memory name) {
            tokenName = name;
            console.log("Token name:", tokenName);
        } catch {
            console.log("ERROR: Failed to get token name");
            tokenDetailsSuccess = false;
        }
        
        try token.symbol() returns (string memory symbol) {
            tokenSymbol = symbol;
            console.log("Token symbol:", symbol);
        } catch {
            console.log("ERROR: Failed to get token symbol");
            tokenDetailsSuccess = false;
        }
        
        try token.decimals() returns (uint8 decimals) {
            tokenDecimals = decimals;
            console.log("Token decimals:", decimals);
        } catch {
            console.log("ERROR: Failed to get token decimals");
            tokenDetailsSuccess = false;
        }
        
        if (!tokenDetailsSuccess) {
            console.log("ERROR: Failed to read basic token details. Check if the token contract is correct.");
            return;
        }
        
        // Calculate actual mint amount with decimals
        uint256 actualMintAmount = mintAmount * (10 ** tokenDecimals);
        console.log("Actual mint amount with decimals:", actualMintAmount);
        
        // Check if token is paused
        bool isPaused = false;
        try token.paused() returns (bool paused) {
            isPaused = paused;
            console.log("Token paused status:", isPaused ? "PAUSED" : "NOT PAUSED");
        } catch {
            console.log("ERROR: Failed to check token pause status");
            return;
        }
        
        // Try to unpause the token if it's paused
        if (isPaused) {
            console.log("Token is paused. Attempting to unpause...");
            try token.unpause() {
                console.log("Token successfully unpaused");
                isPaused = false;
            } catch Error(string memory reason) {
                console.log("Failed to unpause token with reason:", reason);
                console.log("You may not have agent role required to unpause");
            } catch {
                console.log("Failed to unpause token with unknown error");
            }
            
            if (isPaused) {
                console.log("WARNING: Token is still paused. Minting may fail.");
            }
        }
        
        // Check if destination address is a valid receiver
        console.log("\n=== Performing Compliance Checks for Mint Address ===");
        
        // Check compliance system
        address complianceAddress;
        try token.compliance() returns (IModularCompliance compliance) {
            complianceAddress = address(compliance);
            console.log("Token compliance contract:", complianceAddress);
        } catch {
            console.log("ERROR: Failed to get compliance contract");
            return;
        }
        
        // Check attribute registry
        address attributeRegistryAddress;
        try token.attributeRegistry() returns (IAttributeRegistry registry) {
            attributeRegistryAddress = address(registry);
            console.log("Token attribute registry:", attributeRegistryAddress);
        } catch {
            console.log("ERROR: Failed to get attribute registry");
            return;
        }
        
        // Verify if destination has ACCREDITED_INVESTOR attribute
        bool isAccredited = false;
        try IAttributeRegistry(attributeRegistryAddress).hasAttribute(mintAddress, Attributes.ACCREDITED_INVESTOR) returns (bool hasAttribute) {
            isAccredited = hasAttribute;
            console.log("Mint address accredited investor status:", isAccredited ? "ACCREDITED" : "NOT ACCREDITED");
        } catch {
            console.log("ERROR: Failed to check accredited investor status");
            // Continue anyway as the address might be exempt via other mechanisms
        }
        
        // Check if address is an insider (might be exempt from accreditation)
        try IModularCompliance(complianceAddress).getModules() returns (address[] memory modules) {
            console.log("Found", modules.length, "compliance modules");
            
            // Try to find an InsiderRegistry module
            for (uint i = 0; i < modules.length; i++) {
                console.log("Checking module:", modules[i]);
                try IInsiderRegistry(modules[i]).isInsider(mintAddress) returns (bool isInsider) {
                    if (isInsider) {
                        console.log("Mint address is registered as an insider in module", i);
                        console.log("This may exempt it from accreditation requirements");
                    } else {
                        console.log("Mint address is NOT an insider in module", i);
                    }
                } catch {
                    // Not an insider registry module, continue to next one
                }
            }
        } catch {
            console.log("ERROR: Failed to check compliance modules");
        }
        
        // Check if minter has agent role
        bool hasAgentRole = false;
        try AgentRole(tokenAddress).isAgent(deployer) returns (bool isAgent) {
            hasAgentRole = isAgent;
            console.log("Deployer agent status:", hasAgentRole ? "IS AGENT" : "NOT AGENT");
            
            if (!hasAgentRole) {
                console.log("Attempting to add deployer as agent...");
                try AgentRole(tokenAddress).addAgent(deployer) {
                    console.log("Successfully added deployer as agent");
                    hasAgentRole = true;
                } catch Error(string memory reason) {
                    console.log("Failed to add deployer as agent:", reason);
                } catch {
                    console.log("Failed to add deployer as agent with unknown error");
                }
            }
        } catch {
            console.log("ERROR: Failed to check agent role");
        }
        
        if (!hasAgentRole) {
            console.log("ERROR: Deployer is not an agent and cannot mint tokens");
            return;
        }
        
        // Check if a direct transfer would be allowed by compliance
        bool transferAllowed = false;
        try IModularCompliance(complianceAddress).canTransfer(address(0), mintAddress, actualMintAmount) returns (bool allowed) {
            transferAllowed = allowed;
            console.log("Compliance check result:", transferAllowed ? "ALLOWED" : "NOT ALLOWED");
        } catch Error(string memory reason) {
            console.log("Compliance check failed with reason:", reason);
        } catch {
            console.log("Compliance check failed with unknown error");
        }
        
        if (!transferAllowed) {
            console.log("WARNING: Compliance check failed. Mint address is likely not authorized to receive tokens");
            console.log("This could be because:");
            console.log("1. The address is not an accredited investor");
            console.log("2. The address is not registered as an insider");
            console.log("3. There are other compliance rules preventing the transfer");
            console.log("Continuing with minting attempt, but it will likely fail...");
        }
        
        // Attempt to mint tokens
        console.log("\n=== Attempting to Mint Tokens ===");
        console.log("Minting tokens to destination address");
        console.log("Amount:", mintAmount);
        console.log("Token:", tokenName);
        console.log("Destination:", mintAddress);
        
        try token.mint(mintAddress, actualMintAmount) {
            console.log("Minting transaction successful!");
            
            // Verify balance after minting
            try token.balanceOf(mintAddress) returns (uint256 newBalance) {
                console.log("New balance of mint address:", newBalance / (10 ** tokenDecimals));
                console.log("Token:", tokenName);
                
                if (newBalance >= actualMintAmount) {
                    console.log("Minting was successful!");
                } else {
                    console.log("Minting transaction succeeded but balance is incorrect");
                }
            } catch {
                console.log("Failed to verify balance after minting");
            }
        } catch Error(string memory reason) {
            console.log("Minting failed with reason:");
            console.log(reason);
            
            // Provide more user-friendly error explanation
            if (bytes(reason).length > 0) {
                if (_contains(reason, "Compliance check failed")) {
                    console.log("EXPLANATION: The mint address failed compliance checks. It needs to be:");
                    console.log("1. Registered as an accredited investor in the attribute registry, OR");
                    console.log("2. Registered as an insider and exempt from accreditation");
                } else if (_contains(reason, "not agent")) {
                    console.log("EXPLANATION: The deployer does not have the agent role required to mint tokens");
                } else if (_contains(reason, "paused")) {
                    console.log("EXPLANATION: The token is paused and needs to be unpaused before minting");
                }
            }
            
            console.log("\nTo fix this issue, you will need to:");
            console.log("1. Ensure the mint address is properly registered in the attribute registry, OR");
            console.log("2. Register the mint address as an insider if appropriate");
            console.log("3. Ensure the minting account has the agent role");
            console.log("4. Ensure the token is not paused");
        } catch {
            console.log("Minting failed with unknown error");
        }
    }
    
    // Helper function to check if a string contains a substring
    function _contains(string memory source, string memory search) internal pure returns (bool) {
        bytes memory sourceBytes = bytes(source);
        bytes memory searchBytes = bytes(search);
        
        if (searchBytes.length > sourceBytes.length) {
            return false;
        }
        
        for (uint i = 0; i <= sourceBytes.length - searchBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < searchBytes.length; j++) {
                if (sourceBytes[i + j] != searchBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        
        return false;
    }
}