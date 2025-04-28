// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/proxy/VersionRegistry.sol";
import "../src/RefactoredSecurityTokenFactory.sol";
import "../src/SecurityToken.sol";
import "../src/compliance/ModularCompliance.sol";
import "../src/compliance/modules/AccreditedInvestor.sol";
import "../src/interfaces/IInsiderRegistry.sol";
import "../src/proxy/ComplianceModuleProxy.sol";
import "../src/compliance/modules/InsiderRegistry.sol";

/**
 * @title DeployAllScript
 * @dev Main deployment script that orchestrates the deployment of all components with the new proxy architecture
 */
contract DeployAllScript is Script {
    // Note: Deploy_Authority.s.sol was removed as we no longer have an authority to deploy
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
        
        vm.startBroadcast(deployer);

        // Get deployment parameters from environment
        address attributeRegistry;
        try vm.envAddress("ATTRIBUTE_REGISTRY_ADDRESS") returns (address registryAddr) {
            attributeRegistry = registryAddr;
        } catch {
            // Use a fixed valid address as fallback if the env variable is not a proper address
            attributeRegistry = 0x0000000000000000000000000000000000000001;
            console.log("Warning: ATTRIBUTE_REGISTRY_ADDRESS is not a valid address, using fallback:", attributeRegistry);
        }
        
        // Step 1: Deploy the VersionRegistry
        console.log("Step 1: Deploying VersionRegistry...");
        VersionRegistry registry = new VersionRegistry();
        
        // Step 2: Deploy implementations
        console.log("Step 2: Deploying implementations...");
        SecurityToken tokenImpl = new SecurityToken();
        ModularCompliance mcImpl = new ModularCompliance();
        AccreditedInvestor aiImpl = new AccreditedInvestor();
        
        // Deploy InsiderRegistry implementation separately
        console.log("Deploying InsiderRegistry implementation...");
        InsiderRegistry insiderRegImpl = new InsiderRegistry();
        
        // Step 3: Register implementations in the registry
        console.log("Step 3: Registering implementations in the version registry...");
        registry.registerImplementation("security-token", "1.0.0", address(tokenImpl), "Initial security token implementation");
        registry.registerImplementation("modular-compliance", "1.0.0", address(mcImpl), "Initial modular compliance implementation");
        registry.registerImplementation("accredited-investor", "1.0.0", address(aiImpl), "Initial accredited investor module implementation");
        registry.registerImplementation("insider-registry", "1.0.0", address(insiderRegImpl), "Initial insider registry implementation");
        
        // Step 4: Deploy the security token factory
        console.log("Step 4: Deploying RefactoredSecurityTokenFactory...");
        RefactoredSecurityTokenFactory factory = new RefactoredSecurityTokenFactory(address(registry));
        
        // Step 5: Deploy and configure all compliance modules before token
        console.log("Step 5: Deploying and configuring compliance modules...");
        
        // 5.1: Deploy InsiderRegistry module FIRST (since AccreditedInvestor depends on it)
        console.log("Deploying InsiderRegistry module...");
        address insiderRegImplAddress = registry.getImplementation("insider-registry", "1.0.0");
        bytes memory insiderInitData = abi.encodeWithSelector(bytes4(keccak256("initialize()")));
        ComplianceModuleProxy insiderRegistryProxy = new ComplianceModuleProxy(insiderRegImplAddress, insiderInitData);
        address insiderRegistry = address(insiderRegistryProxy);
        console.log("Deployed InsiderRegistry module at:", insiderRegistry);
        
        // The deployer is already an insider due to the initialize() function of InsiderRegistry
        // which automatically adds the msg.sender (deployer) as an AGENT insider
        console.log("Deployer added as insider during InsiderRegistry initialization");
        
        // 5.2: Deploy AccreditedInvestor module AFTER InsiderRegistry
        console.log("Deploying AccreditedInvestor module...");
        address aiImplAddress = registry.getImplementation("accredited-investor", "1.0.0");
        bytes memory aiInitData = abi.encodeWithSelector(bytes4(keccak256("initialize()")));
        ComplianceModuleProxy aiModuleProxy = new ComplianceModuleProxy(aiImplAddress, aiInitData);
        address aiModule = address(aiModuleProxy);
        console.log("Deployed AccreditedInvestor module at:", aiModule);
        
        // Configure AccreditedInvestor module with BOTH registries
        console.log("Configuring AccreditedInvestor module...");
        
        // Set the Attribute Registry
        console.log("- Setting Attribute Registry:", attributeRegistry);
        AccreditedInvestor(aiModule).setAttributeRegistry(attributeRegistry);
        
        // Set the Insider Registry - THIS IS THE CRITICAL CONNECTION
        console.log("- Setting Insider Registry:", insiderRegistry);
        AccreditedInvestor(aiModule).setInsiderRegistry(insiderRegistry);
        
        // Enable insider exemption
        console.log("- Setting insiders exempt from accreditation");
        AccreditedInvestor(aiModule).setInsidersExemptFromAccreditation(true);
        
        console.log("AccreditedInvestor module fully configured with InsiderRegistry connection");
        
        // Step 6: Deploy a security token (FINAL STEP - after all modules are ready)
        console.log("Step 6: Deploying security token...");
        string memory tokenName = vm.envString("TOKEN_NAME");
        string memory tokenSymbol = vm.envString("TOKEN_SYMBOL");
        uint8 tokenDecimals = uint8(vm.envUint("TOKEN_DECIMALS"));
        
        console.log(" - Name:", tokenName);
        console.log(" - Symbol:", tokenSymbol);
        console.log(" - Decimals:", tokenDecimals);
        console.log(" - Factory:", address(factory));
        console.log(" - Attribute Registry:", attributeRegistry);
        
        // Generate a unique salt based on name and symbol
        string memory salt = string(abi.encodePacked(tokenName, "-", tokenSymbol, "-", block.timestamp));
        
        // Create array with the compliance module(s)
        address[] memory modules = new address[](1);
        modules[0] = aiModule;
        
        // Deploy token with configured modules
        factory.deployToken(
            salt,
            tokenName,
            tokenSymbol,
            tokenDecimals,
            deployer, // Setting actual deployer as owner
            attributeRegistry,
            modules,  // Using our pre-configured module
            "1.0.0",  // Token version
            "1.0.0"   // Compliance version
        );
        
        // Get the token address
        address token = factory.getToken(salt);
        console.log("Token deployed at:", token);
        
        // Get Compliance address
        address complianceAddress = address(IToken(token).compliance());
        console.log("Token compliance is at:", complianceAddress);
        
        // Mint initial supply if specified
        uint256 initialSupply = vm.envUint("INITIAL_SUPPLY");
        if (initialSupply > 0) {
            try IToken(token).mint(deployer, initialSupply * (10 ** tokenDecimals)) {
                console.log("Initial supply minted successfully:", initialSupply);
            } catch Error(string memory reason) {
                console.log("Minting failed with reason:", reason);
            } catch {
                console.log("Minting failed with unknown error");
            }
        }
        
        // Log deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("Version Registry:", address(registry));
        console.log("Token Implementation:", address(tokenImpl));
        console.log("Modular Compliance Implementation:", address(mcImpl));
        console.log("AccreditedInvestor Implementation:", address(aiImpl));
        console.log("InsiderRegistry Implementation:", address(insiderRegImpl));
        console.log("Security Token Factory:", address(factory));
        console.log("AccreditedInvestor Module:", aiModule);
        console.log("InsiderRegistry Module:", insiderRegistry);
        console.log("Attribute Registry:", attributeRegistry);
        console.log("Deployed Token:", token);
        console.log("Token Compliance:", complianceAddress);
        
        vm.stopBroadcast();
    }
}