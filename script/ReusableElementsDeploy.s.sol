// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/SecurityTokenFactory.sol";
import "../src/SecurityToken.sol";
import "../src/compliance/ModularCompliance.sol";
import "../src/compliance/modules/AccreditedInvestor.sol";
import "../src/compliance/modules/Lockup.sol";
import "../src/proxy/authority/TREXImplementationAuthority.sol";
import "st-identity-registry/src/interfaces/IAttributeRegistry.sol";

/**
 * @title ReusableElementsDeployScript
 * @dev Deploys reusable elements for security token infrastructure
 * Stages 1 & 2: Implementation Authority, Compliance Modules, and Factory
 */
contract ReusableElementsDeployScript is Script {
    // Struct to store deployed addresses
    struct DeployedContracts {
        address implementationAuthority;
        address accreditedInvestorModule;
        address lockupModule;
        address securityTokenFactory;
        address attributeRegistry;
    }

    // Config variables
    address public deployer;
    address public attributeRegistryAddress;
    uint256 public chainId;

    /**
     * @dev Load configuration from environment variables
     */
    function loadConfig() internal {
        // Read from environment variables
        deployer = vm.envOr("DEPLOYER_ADDRESS", address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        attributeRegistryAddress = vm.envOr("ATTRIBUTE_REGISTRY_ADDRESS", address(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512));
        chainId = vm.envOr("CHAIN_ID", uint256(31337));
        
        // Log the configuration
        console.log("Deployer address:", deployer);
        console.log("Attribute Registry:", attributeRegistryAddress);
        console.log("Chain ID:", chainId);
        
        // Validate configuration
        require(deployer != address(0), "Invalid deployer address in config");
        require(attributeRegistryAddress != address(0), "Invalid attribute registry address in config");
    }

    /**
     * @dev Main deployment function
     */
    function run() public returns (DeployedContracts memory) {
        // Load configuration
        loadConfig();
        
        // Verify current chain
        require(block.chainid == chainId, string(abi.encodePacked(
            "Chain ID mismatch. Expected: ", vm.toString(chainId), 
            ", Actual: ", vm.toString(block.chainid)
        )));
        
        // Store deployed contract addresses
        DeployedContracts memory deployed;
        
        // Step 1: Deploy the token implementation
        console.log("Deploying SecurityToken implementation...");
        SecurityToken tokenImplementation = new SecurityToken();
        address tokenImpl = address(tokenImplementation);
        console.log("Token implementation deployed at:", tokenImpl);
        
        // Step 2: Deploy the compliance implementation
        console.log("Deploying ModularCompliance implementation...");
        ModularCompliance complianceImplementation = new ModularCompliance();
        address mcImpl = address(complianceImplementation);
        console.log("ModularCompliance implementation deployed at:", mcImpl);
        
        // Step 3: Deploy Implementation Authority
        console.log("Deploying TREX implementation authority...");
        // Parameters: 
        // - true = reference contract
        // - address(0) = trexFactory, will be set later
        // - address(0) = iaFactory, no factory for implementation authorities in this case
        TREXImplementationAuthority implementationAuthority = new TREXImplementationAuthority(
            true,   // reference status
            address(0),  // trexFactory - will be set after factory deployment
            address(0)   // iaFactory - not used in this deployment
        );
        deployed.implementationAuthority = address(implementationAuthority);
        console.log("Implementation authority deployed at:", deployed.implementationAuthority);
        
        // Step 4: Add a version with the implementations
        console.log("Adding implementations to the authority...");
        ITREXImplementationAuthority.Version memory version = ITREXImplementationAuthority.Version(1, 0, 0);
        ITREXImplementationAuthority.TREXContracts memory contracts = ITREXImplementationAuthority.TREXContracts(
            tokenImpl,             // Token implementation
            address(1),            // CTR implementation (placeholder)
            address(1),            // IR implementation (placeholder)
            address(1),            // IRS implementation (placeholder)
            address(1),            // TIR implementation (placeholder)
            mcImpl,                // MC implementation
            address(1)             // MA implementation (placeholder)
        );
        
        implementationAuthority.addTREXVersion(version, contracts);
        implementationAuthority.useTREXVersion(version);
        console.log("Implementations registered in the authority");
        
        // Step 5: Deploy compliance modules
        console.log("Deploying AccreditedInvestor module...");
        AccreditedInvestor accreditedInvestorImpl = new AccreditedInvestor();
        deployed.accreditedInvestorModule = address(accreditedInvestorImpl);
        console.log("AccreditedInvestor module deployed at:", deployed.accreditedInvestorModule);
        
        console.log("Deploying Lockup module...");
        Lockup lockupImpl = new Lockup();
        deployed.lockupModule = address(lockupImpl);
        console.log("Lockup module deployed at:", deployed.lockupModule);
        
        // Step 6: Initialize modules if needed
        console.log("Initializing compliance modules...");
        
        // Initialize AccreditedInvestor module
        AccreditedInvestor accreditedInvestor = AccreditedInvestor(deployed.accreditedInvestorModule);
        accreditedInvestor.initialize();
        accreditedInvestor.setAttributeRegistry(attributeRegistryAddress);
        console.log("AccreditedInvestor module initialized with attribute registry:", attributeRegistryAddress);
        
        // Initialize Lockup module
        Lockup lockup = Lockup(deployed.lockupModule);
        lockup.initialize();
        console.log("Lockup module initialized");
        
        // Step 7: Deploy factory
        console.log("Deploying SecurityTokenFactory...");
        SecurityTokenFactory factory = new SecurityTokenFactory(
            deployed.implementationAuthority
        );
        deployed.securityTokenFactory = address(factory);
        console.log("SecurityTokenFactory deployed at:", deployed.securityTokenFactory);
        
        // Link the implementation authority to the factory (circular reference)
        console.log("Setting TREXFactory in the implementation authority...");
        implementationAuthority.setTREXFactory(deployed.securityTokenFactory);
        console.log("TREXFactory set in implementation authority");
        
        // Add the attribute registry to the deployed struct
        deployed.attributeRegistry = attributeRegistryAddress;
        
        // Output deployment summary
        console.log("\n===== Deployment Summary =====");
        console.log("Implementation Authority:", deployed.implementationAuthority);
        console.log("AccreditedInvestor Module:", deployed.accreditedInvestorModule);
        console.log("Lockup Module:", deployed.lockupModule);
        console.log("SecurityTokenFactory:", deployed.securityTokenFactory);
        console.log("Attribute Registry (existing):", deployed.attributeRegistry);
        
        // Return deployed contract addresses
        return deployed;
    }
}