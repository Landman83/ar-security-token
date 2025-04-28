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
import "../src/compliance/modules/AccreditedInvestor.sol";
import "../src/interfaces/IInsiderRegistry.sol";

/**
 * @title DeployAllScript
 * @dev Main deployment script that orchestrates the deployment of all components
 */
contract DeployAllScript is Script {
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
        (address aiModule, address lockupModule, address insiderRegistry) = modulesScript.run(attributeRegistry);
        
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
            deployer, // Setting actual deployer as owner
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
        
        // Initialize the AccreditedInvestor module for this compliance by calling initializeModule
        // through callModuleFunction (only the compliance itself can call initializeModule directly)
        console.log("Initializing AccreditedInvestor module...");
        bytes memory aiInitData = abi.encodeWithSelector(
            AccreditedInvestor(aiModule).initializeModule.selector,
            complianceAddress
        );
        compliance.callModuleFunction(aiInitData, aiModule);
        console.log("AccreditedInvestor module initialized");
        
        compliance.addModule(lockupModule);
        console.log("Added Lockup module");
        
        // Initialize the Lockup module for this compliance
        console.log("Initializing Lockup module...");
        bytes memory lockupInitData = abi.encodeWithSelector(
            bytes4(keccak256("initializeModule(address)")),
            complianceAddress
        );
        compliance.callModuleFunction(lockupInitData, lockupModule);
        console.log("Lockup module initialized");
        
        // Mint initial supply if specified
        uint256 initialSupply = vm.envUint("INITIAL_SUPPLY");
        if (initialSupply > 0) {
            // Debug insider status before minting
            console.log("\n=== Debug Minting ===");
            console.log("Script address (msg.sender):", msg.sender);
            console.log("Original caller (tx.origin):", tx.origin);
            console.log("Actual deployer address:", deployer);
            console.log("InsiderRegistry address:", insiderRegistry);
            
            // Check if actual deployer is an insider
            bool isDeployerInsider = IInsiderRegistry(insiderRegistry).isInsider(deployer);
            console.log("Is actual deployer an insider in registry?", isDeployerInsider);
            
            if (isDeployerInsider) {
                uint8 insiderType = IInsiderRegistry(insiderRegistry).getInsiderType(deployer);
                console.log("Actual deployer insider type:", insiderType);
                
                // Check if actual deployer is an AGENT type insider
                bool isDeployerAgent = (insiderType == uint8(IInsiderRegistry.InsiderType.AGENT));
                console.log("Is actual deployer an AGENT type insider?", isDeployerAgent);
            } else {
                console.log("Actual deployer is not an insider, so not an AGENT");
            }
            
            // Also check other addresses for comparison
            bool isMsgSenderInsider = IInsiderRegistry(insiderRegistry).isInsider(msg.sender);
            console.log("Is msg.sender an insider in registry?", isMsgSenderInsider);
            
            bool isTxOriginInsider = IInsiderRegistry(insiderRegistry).isInsider(tx.origin);
            console.log("Is tx.origin an insider in registry?", isTxOriginInsider);
            
            // Check if InsiderRegistry is properly set in AccreditedInvestor
            address registeredInsiderRegistry = address(AccreditedInvestor(aiModule).insiderRegistry());
            console.log("Insider registry in AccreditedInvestor:", registeredInsiderRegistry);
            
            // Check the exemption flag
            bool exemptionEnabled = AccreditedInvestor(aiModule).insidersExemptFromAccreditation();
            console.log("Are insiders exempt from accreditation?", exemptionEnabled);
            
            // Check if module is initialized for compliance
            console.log("Compliance address:", complianceAddress);
            
            // Check if moduleCheck passes directly in AccreditedInvestor for actual deployer
            try AccreditedInvestor(aiModule).moduleCheck(address(0), deployer, 1, complianceAddress) returns (bool result) {
                console.log("AccreditedInvestor.moduleCheck for actual deployer result:", result);
            } catch Error(string memory reason) {
                console.log("AccreditedInvestor.moduleCheck for actual deployer failed with reason:", reason);
            } catch {
                console.log("AccreditedInvestor.moduleCheck for actual deployer failed with unknown error");
            }
            
            // Check if deployer is considered accredited by the module
            try AccreditedInvestor(aiModule).isAccreditedInvestor(deployer) returns (bool result) {
                console.log("Is actual deployer considered accredited?", result);
            } catch Error(string memory reason) {
                console.log("isAccreditedInvestor check for actual deployer failed with reason:", reason);
            } catch {
                console.log("isAccreditedInvestor check for actual deployer failed with unknown error");
            }
            
            // Check compliance's canTransfer function for actual deployer
            try ModularCompliance(complianceAddress).canTransfer(address(0), deployer, 1) returns (bool result) {
                console.log("Can transfer to actual deployer according to compliance?", result);
            } catch Error(string memory reason) {
                console.log("canTransfer check for actual deployer failed with reason:", reason);
            } catch {
                console.log("canTransfer check for actual deployer failed with unknown error");
            }
            
            // Get the target address to mint tokens to directly from environment
            address mintToAddress = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Default to this address
            console.log("Minting to hardcoded address:", mintToAddress);
            
            // Try minting to specific address
            try SecurityToken(token).mint(mintToAddress, initialSupply * (10 ** tokenDecimals)) {
                console.log("Initial supply minted successfully:", initialSupply);
                console.log("Minted to:", mintToAddress);
            } catch Error(string memory reason) {
                console.log("Minting to address failed with reason:", reason);
                console.log("To mint tokens later, ensure the receiver has the required attributes");
                console.log("Then use token.mint(address, amount) as token owner or agent");
                
                // Add additional debugging info for the mint target address
                console.log("\nExtra debugging:");
                bool isInsider = IInsiderRegistry(insiderRegistry).isInsider(mintToAddress);
                console.log("Is mint address an insider?", isInsider);
                try AccreditedInvestor(aiModule).isAccreditedInvestor(mintToAddress) returns (bool result) {
                    console.log("Is mint address considered accredited?", result);
                } catch {
                    console.log("Failed to check if mint address is accredited");
                }
                
                // Check if we can register the mint address as an insider
                try InsiderRegistry(insiderRegistry).addInsider(mintToAddress, uint8(IInsiderRegistry.InsiderType.AGENT)) {
                    console.log("Added mint address as insider");
                    try SecurityToken(token).mint(mintToAddress, initialSupply * (10 ** tokenDecimals)) {
                        console.log("Second mint attempt successful!");
                    } catch {
                        console.log("Second mint attempt failed even after adding as insider");
                    }
                } catch {
                    console.log("Failed to add mint address as insider");
                }
            } catch {
                console.log("Minting to address failed with unknown error");
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
        console.log("Insider Registry:", insiderRegistry);
        console.log("Security Token Factory:", factory);
        console.log("Attribute Registry:", attributeRegistry);
        console.log("Deployed Token:", token);
        
        vm.stopBroadcast();
    }
}