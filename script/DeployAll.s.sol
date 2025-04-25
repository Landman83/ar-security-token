// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "./deployment/Deploy_Implementations.s.sol";
import "./deployment/Deploy_Authority.s.sol";
import "./deployment/Deploy_Modules.s.sol";
import "./deployment/Deploy_Factory.s.sol";
import "../src/proxy/authority/TREXImplementationAuthority.sol";
import "../src/SecurityToken.sol";
import "../src/SecurityTokenFactory.sol";
import "../src/compliance/ModularCompliance.sol";

/**
 * @title DeployAllScript
 * @dev Main deployment script that orchestrates the deployment of all components
 */
contract DeployAllScript is Script {
    function run() public {
        vm.startBroadcast();

        // Get deployment parameters from environment
        string memory attributeRegistryEnv = vm.envString("ATTRIBUTE_REGISTRY_ADDRESS");
        address attributeRegistry = address(bytes20(bytes(attributeRegistryEnv)));
        
        // Step 1: Deploy implementations
        console.log("Step 1: Deploying implementations...");
        DeployImplementationsScript implementationsScript = new DeployImplementationsScript();
        (address tokenImpl, address mcImpl) = implementationsScript.run();
        
        // Step 2: Deploy implementation authority
        console.log("Step 2: Deploying implementation authority...");
        DeployAuthorityScript authorityScript = new DeployAuthorityScript();
        address implementationAuthority = authorityScript.run(tokenImpl, mcImpl);
        
        // Step 3: Deploy compliance modules
        console.log("Step 3: Deploying compliance modules...");
        DeployModulesScript modulesScript = new DeployModulesScript();
        (address aiModule, address lockupModule) = modulesScript.run(attributeRegistry);
        
        // Step 4: Deploy security token factory
        console.log("Step 4: Deploying security token factory...");
        DeployFactoryScript factoryScript = new DeployFactoryScript();
        address factory = factoryScript.run(implementationAuthority);
        
        // Step 5: Configure implementation authority with factory
        console.log("Step 5: Setting factory in implementation authority...");
        TREXImplementationAuthority(implementationAuthority).setTREXFactory(factory);
        
        // Step 6: Deploy a security token (optional)
        string memory tokenName = vm.envString("TOKEN_NAME");
        string memory tokenSymbol = vm.envString("TOKEN_SYMBOL");
        uint8 tokenDecimals = uint8(vm.envUint("TOKEN_DECIMALS"));
        
        console.log("Step 6: Deploying security token...");
        console.log(" - Name:", tokenName);
        console.log(" - Symbol:", tokenSymbol);
        console.log(" - Decimals:", tokenDecimals);
        console.log(" - Factory:", factory);
        console.log(" - Attribute Registry:", attributeRegistry);
        
        // Generate a unique salt based on name and symbol
        string memory salt = string(abi.encodePacked(tokenName, "-", tokenSymbol, "-", block.timestamp));
        
        // Create an empty array for compliance modules
        address[] memory emptyModules = new address[](0);
        
        // Deploy token directly
        SecurityTokenFactory(factory).deployToken(
            salt,
            tokenName,
            tokenSymbol,
            tokenDecimals,
            msg.sender, // Setting sender as owner
            attributeRegistry,
            emptyModules
        );
        
        // Get the token address
        address token = SecurityTokenFactory(factory).getToken(salt);
        console.log("Token deployed at:", token);
        
        // Configure token compliance
        console.log("Configuring token compliance...");
        address complianceAddress = address(SecurityToken(token).compliance());
        console.log("Token compliance is at:", complianceAddress);
        
        // Add compliance modules to the token
        console.log("Adding compliance modules...");
        ModularCompliance compliance = ModularCompliance(complianceAddress);
        compliance.addModule(aiModule);
        console.log("Added AccreditedInvestor module");
        compliance.addModule(lockupModule);
        console.log("Added Lockup module");
        
        // Mint initial supply if specified
        uint256 initialSupply = vm.envUint("INITIAL_SUPPLY");
        if (initialSupply > 0) {
            try SecurityToken(token).mint(msg.sender, initialSupply * (10 ** tokenDecimals)) {
                console.log("Initial supply minted successfully:", initialSupply);
                console.log("Minted to:", msg.sender);
            } catch {
                console.log("Minting failed - receiver may not have the ACCREDITED_INVESTOR attribute");
                console.log("To mint tokens later, ensure the receiver has the required attributes");
                console.log("Then use token.mint(address, amount) as token owner or agent");
            }
        }
        
        // Log deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("Token Implementation:", tokenImpl);
        console.log("Modular Compliance Implementation:", mcImpl);
        console.log("Implementation Authority:", implementationAuthority);
        console.log("AccreditedInvestor Module:", aiModule);
        console.log("Lockup Module:", lockupModule);
        console.log("Security Token Factory:", factory);
        console.log("Attribute Registry:", attributeRegistry);
        console.log("Deployed Token:", token);
        
        vm.stopBroadcast();
    }
}