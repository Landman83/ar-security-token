// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/test/tUSD.sol";

/**
 * @title DeployUSDToken
 * @dev Deployment script for Test USD (tUSD) token
 * Usage: forge script script/DeployUSDToken.s.sol:DeployUSDToken --rpc-url $RPC_URL --broadcast --verify
 */
contract DeployUSDToken is Script {
    function run() public {
        // Get environment variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 chainId = vm.envUint("CHAIN_ID");
        
        // Set default values or get from environment
        uint256 initialSupply = vm.envOr("TUSD_INITIAL_SUPPLY", uint256(1_000_000)); // 1 million tokens default
        uint8 decimals = uint8(vm.envOr("TUSD_DECIMALS", uint256(18))); // 18 decimals default
        
        console.log("=== Deploying Test USD (tUSD) ===");
        console.log("Chain ID:", chainId);
        console.log("Initial Supply:", initialSupply);
        console.log("Decimals:", decimals);
        console.log("Deployer:", deployerAddress);
        
        // Start broadcast
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the token
        TestUSD token = new TestUSD(initialSupply, decimals);
        
        // Stop broadcast
        vm.stopBroadcast();
        
        // Log deployment information
        console.log("\n=== Deployment Successful ===");
        console.log("Token deployed at:", address(token));
        console.log("Name:", token.name());
        console.log("Symbol:", token.symbol());
        console.log("Decimals:", token.decimals());
        console.log("Total Supply:", token.totalSupply());
        console.log("Owner:", token.owner());
        
        // Log the actual token amount with decimals
        uint256 actualSupply = initialSupply * (10 ** decimals);
        console.log("\nActual token supply with decimals:", actualSupply);
        
        // Write deployment address to console for easy copying
        console.log("\n=== IMPORTANT: Save this address ===");
        console.log("TUSD_ADDRESS=", address(token));
    }
    
    /**
     * @dev Alternative run function that accepts parameters
     * Can be called with: forge script script/DeployUSDToken.s.sol:DeployUSDToken --sig "runWithParams(uint256,uint8)" 1000000 18 --broadcast
     */
    function runWithParams(uint256 initialSupply, uint8 decimals) public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        console.log("=== Deploying Test USD (tUSD) with Parameters ===");
        console.log("Initial Supply:", initialSupply);
        console.log("Decimals:", decimals);
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        
        vm.startBroadcast(deployerPrivateKey);
        
        TestUSD token = new TestUSD(initialSupply, decimals);
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Successful ===");
        console.log("Token deployed at:", address(token));
    }
}