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
import "../src/interfaces/IToken.sol";
import "../src/roles/AgentRole.sol";

/**
 * @title DeployAllFixedScript
 * @dev Improved deployment script with better error handling and verification
 */
contract DeployAllFixedScript is Script {
    // Store deployed addresses for verification
    address public registryAddress;
    address public factoryAddress;
    address public tokenAddress;
    address public insiderRegistryAddress;
    address public aiModuleAddress;
    
    function run() public {
        // Validate required environment variables
        _validateEnvironmentVariables();
        
        // Get deployer address from environment
        address deployer = _getDeployerAddress();
        
        vm.startBroadcast(deployer);
        
        // Deploy contracts in phases to avoid gas issues
        _phaseOne_DeployBaseInfrastructure(deployer);
        _phaseTwo_DeployModules(deployer);
        _phaseThree_DeployToken(deployer);
        _phaseFour_VerifyAndConfigureToken(deployer);
        
        vm.stopBroadcast();
    }
    
    function _validateEnvironmentVariables() internal {
        // Validate all required environment variables exist
        string memory errorMsg = "";
        
        try vm.envString("TOKEN_NAME") {} catch {
            errorMsg = string(abi.encodePacked(errorMsg, "TOKEN_NAME environment variable is required. "));
        }
        
        try vm.envString("TOKEN_SYMBOL") {} catch {
            errorMsg = string(abi.encodePacked(errorMsg, "TOKEN_SYMBOL environment variable is required. "));
        }
        
        try vm.envUint("TOKEN_DECIMALS") {} catch {
            errorMsg = string(abi.encodePacked(errorMsg, "TOKEN_DECIMALS environment variable is required. "));
        }
        
        try vm.envAddress("ATTRIBUTE_REGISTRY_ADDRESS") {} catch {
            errorMsg = string(abi.encodePacked(errorMsg, "ATTRIBUTE_REGISTRY_ADDRESS environment variable is required. "));
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
    
    function _phaseOne_DeployBaseInfrastructure(address deployer) internal {
        console.log("\n=== PHASE 1: Deploying Base Infrastructure ===");
        
        // Step 1: Deploy the VersionRegistry
        console.log("Step 1: Deploying VersionRegistry...");
        VersionRegistry registry = new VersionRegistry();
        registryAddress = address(registry);
        console.log("VersionRegistry deployed at:", registryAddress);
        
        // Step 2: Deploy implementations
        console.log("Step 2: Deploying implementations...");
        SecurityToken tokenImpl = new SecurityToken();
        console.log("SecurityToken implementation deployed at:", address(tokenImpl));
        
        ModularCompliance mcImpl = new ModularCompliance();
        console.log("ModularCompliance implementation deployed at:", address(mcImpl));
        
        AccreditedInvestor aiImpl = new AccreditedInvestor();
        console.log("AccreditedInvestor implementation deployed at:", address(aiImpl));
        
        InsiderRegistry insiderRegImpl = new InsiderRegistry();
        console.log("InsiderRegistry implementation deployed at:", address(insiderRegImpl));
        
        // Step 3: Register implementations in the registry
        console.log("Step 3: Registering implementations in the version registry...");
        registry.registerImplementation("security-token", "1.0.0", address(tokenImpl), "Initial security token implementation");
        registry.registerImplementation("modular-compliance", "1.0.0", address(mcImpl), "Initial modular compliance implementation");
        registry.registerImplementation("accredited-investor", "1.0.0", address(aiImpl), "Initial accredited investor module implementation");
        registry.registerImplementation("insider-registry", "1.0.0", address(insiderRegImpl), "Initial insider registry implementation");
        
        // Step 4: Deploy the security token factory
        console.log("Step 4: Deploying RefactoredSecurityTokenFactory...");
        RefactoredSecurityTokenFactory factory = new RefactoredSecurityTokenFactory(address(registry));
        factoryAddress = address(factory);
        console.log("RefactoredSecurityTokenFactory deployed at:", factoryAddress);
    }
    
    function _phaseTwo_DeployModules(address deployer) internal {
        console.log("\n=== PHASE 2: Deploying Compliance Modules ===");
        
        // Get attribute registry address
        address attributeRegistry = vm.envAddress("ATTRIBUTE_REGISTRY_ADDRESS");
        console.log("Using Attribute Registry:", attributeRegistry);
        
        // Verify the registry exists
        VersionRegistry registry = VersionRegistry(registryAddress);
        
        // 5.1: Deploy InsiderRegistry module
        console.log("5.1: Deploying InsiderRegistry module...");
        address insiderRegImplAddress = registry.getImplementation("insider-registry", "1.0.0");
        require(insiderRegImplAddress != address(0), "InsiderRegistry implementation not found in registry");
        
        bytes memory insiderInitData = abi.encodeWithSelector(bytes4(keccak256("initialize()")));
        ComplianceModuleProxy insiderRegistryProxy = new ComplianceModuleProxy(insiderRegImplAddress, insiderInitData);
        insiderRegistryAddress = address(insiderRegistryProxy);
        console.log("Deployed InsiderRegistry module at:", insiderRegistryAddress);
        
        // Verify InsiderRegistry was deployed correctly by calling a function
        bool insiderDeploySuccess = false;
        try InsiderRegistry(insiderRegistryAddress).isInsider(deployer) returns (bool isInsider) {
            console.log("Deployer insider status verification:", isInsider ? "true" : "false");
            insiderDeploySuccess = true;
        } catch Error(string memory reason) {
            console.log("ERROR: InsiderRegistry deployment failed - function call error:", reason);
            revert("InsiderRegistry deployment failed");
        } catch {
            console.log("ERROR: InsiderRegistry deployment failed with unknown error");
            revert("InsiderRegistry deployment failed with unknown error");
        }
        require(insiderDeploySuccess, "InsiderRegistry verification failed");
        
        // 5.2: Deploy AccreditedInvestor module
        console.log("5.2: Deploying AccreditedInvestor module...");
        address aiImplAddress = registry.getImplementation("accredited-investor", "1.0.0");
        require(aiImplAddress != address(0), "AccreditedInvestor implementation not found in registry");
        
        bytes memory aiInitData = abi.encodeWithSelector(bytes4(keccak256("initialize()")));
        ComplianceModuleProxy aiModuleProxy = new ComplianceModuleProxy(aiImplAddress, aiInitData);
        aiModuleAddress = address(aiModuleProxy);
        console.log("Deployed AccreditedInvestor module at:", aiModuleAddress);
        
        // Configure AccreditedInvestor module
        console.log("Configuring AccreditedInvestor module...");
        
        // Set the Attribute Registry
        console.log("- Setting Attribute Registry:", attributeRegistry);
        try AccreditedInvestor(aiModuleAddress).setAttributeRegistry(attributeRegistry) {
            console.log("  Attribute Registry set successfully");
        } catch Error(string memory reason) {
            console.log("ERROR: Failed to set Attribute Registry:", reason);
            revert("Failed to set Attribute Registry");
        } catch {
            console.log("ERROR: Failed to set Attribute Registry with unknown error");
            revert("Failed to set Attribute Registry with unknown error");
        }
        
        // Set the Insider Registry
        console.log("- Setting Insider Registry:", insiderRegistryAddress);
        try AccreditedInvestor(aiModuleAddress).setInsiderRegistry(insiderRegistryAddress) {
            console.log("  Insider Registry set successfully");
        } catch Error(string memory reason) {
            console.log("ERROR: Failed to set Insider Registry:", reason);
            revert("Failed to set Insider Registry");
        } catch {
            console.log("ERROR: Failed to set Insider Registry with unknown error");
            revert("Failed to set Insider Registry with unknown error");
        }
        
        // Enable insider exemption
        console.log("- Setting insiders exempt from accreditation");
        try AccreditedInvestor(aiModuleAddress).setInsidersExemptFromAccreditation(true) {
            console.log("  Insider exemption set successfully");
        } catch Error(string memory reason) {
            console.log("ERROR: Failed to set insider exemption:", reason);
            revert("Failed to set insider exemption");
        } catch {
            console.log("ERROR: Failed to set insider exemption with unknown error");
            revert("Failed to set insider exemption with unknown error");
        }
        
        console.log("AccreditedInvestor module fully configured");
    }
    
    function _phaseThree_DeployToken(address deployer) internal {
        console.log("\n=== PHASE 3: Deploying Security Token ===");
        
        RefactoredSecurityTokenFactory factory = RefactoredSecurityTokenFactory(factoryAddress);
        
        // Get token parameters
        string memory tokenName = vm.envString("TOKEN_NAME");
        string memory tokenSymbol = vm.envString("TOKEN_SYMBOL");
        uint8 tokenDecimals = uint8(vm.envUint("TOKEN_DECIMALS"));
        address attributeRegistry = vm.envAddress("ATTRIBUTE_REGISTRY_ADDRESS");
        
        console.log("Token parameters:");
        console.log(" - Name:", tokenName);
        console.log(" - Symbol:", tokenSymbol);
        console.log(" - Decimals:", tokenDecimals);
        
        // Generate a unique salt based on name and symbol
        string memory salt = string(abi.encodePacked(tokenName, "-", tokenSymbol, "-", block.timestamp));
        
        // Create array with the compliance module(s)
        address[] memory modules = new address[](1);
        modules[0] = aiModuleAddress;
        
        // Deploy token with configured modules
        console.log("Deploying token with the factory...");
        try factory.deployToken(
            salt,
            tokenName,
            tokenSymbol,
            tokenDecimals,
            deployer, // Setting actual deployer as owner
            attributeRegistry,
            modules,  // Using our pre-configured module
            "1.0.0",  // Token version
            "1.0.0"   // Compliance version
        ) {
            console.log("Token deployment transaction succeeded");
        } catch Error(string memory reason) {
            console.log("ERROR: Token deployment failed:", reason);
            revert(string(abi.encodePacked("Token deployment failed: ", reason)));
        } catch {
            console.log("ERROR: Token deployment failed with unknown error");
            revert("Token deployment failed with unknown error");
        }
        
        // Get the token address
        tokenAddress = factory.getToken(salt);
        console.log("Token address from factory:", tokenAddress);
        
        // Verify token address has code
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(sload(tokenAddress.slot))
        }
        
        if (codeSize == 0) {
            console.log("ERROR: No code at token address. Deployment failed.");
            revert("No code at token address. Deployment failed.");
        }
        
        console.log("Code verified at token address:", tokenAddress);
    }
    
    function _phaseFour_VerifyAndConfigureToken(address deployer) internal {
        console.log("\n=== PHASE 4: Verifying and Configuring Token ===");
        
        // Verify token was deployed correctly by reading token properties
        IToken token = IToken(tokenAddress);
        
        try token.name() returns (string memory name) {
            console.log("Token name verification:", name);
        } catch Error(string memory reason) {
            console.log("ERROR: Token name verification failed:", reason);
            revert("Token name verification failed");
        } catch {
            console.log("ERROR: Token name verification failed with unknown error");
            revert("Token name verification failed with unknown error");
        }
        
        try token.symbol() returns (string memory symbol) {
            console.log("Token symbol verification:", symbol);
        } catch {
            console.log("ERROR: Token symbol verification failed");
            revert("Token symbol verification failed");
        }
        
        try token.decimals() returns (uint8 decimals) {
            console.log("Token decimals verification:", decimals);
        } catch {
            console.log("ERROR: Token decimals verification failed");
            revert("Token decimals verification failed");
        }
        
        // Get compliance address
        address complianceAddress;
        try token.compliance() returns (IModularCompliance compliance) {
            complianceAddress = address(compliance);
            console.log("Token compliance verification:", complianceAddress);
        } catch {
            console.log("ERROR: Token compliance verification failed");
            revert("Token compliance verification failed");
        }
        
        // Check if token is paused and unpause it
        try token.paused() returns (bool isPaused) {
            console.log("Token paused status:", isPaused ? "PAUSED" : "NOT PAUSED");
            
            if (isPaused) {
                console.log("Attempting to unpause token...");
                try token.unpause() {
                    console.log("Token successfully unpaused");
                } catch Error(string memory reason) {
                    console.log("WARNING: Failed to unpause token:", reason);
                    console.log("You will need to unpause the token manually before transfers will work");
                } catch {
                    console.log("WARNING: Failed to unpause token with unknown error");
                    console.log("You will need to unpause the token manually before transfers will work");
                }
            }
        } catch {
            console.log("ERROR: Failed to check token pause status");
            console.log("Token might be paused. Check manually and unpause if needed");
        }
        
        // Verify agent role
        try AgentRole(tokenAddress).isAgent(deployer) returns (bool isAgent) {
            console.log("Deployer agent status:", isAgent ? "IS AGENT" : "NOT AGENT");
            
            if (!isAgent) {
                console.log("WARNING: Deployer is not an agent. Attempting to add as agent...");
                try AgentRole(tokenAddress).addAgent(deployer) {
                    console.log("Deployer successfully added as agent");
                } catch {
                    console.log("WARNING: Failed to add deployer as agent");
                    console.log("You will need to add the deployer as an agent manually to mint tokens");
                }
            }
        } catch {
            console.log("ERROR: Failed to check agent status");
        }
        
        // Mint initial supply if specified
        uint256 initialSupply = 0;
        try vm.envUint("INITIAL_SUPPLY") returns (uint256 supply) {
            initialSupply = supply;
        } catch {
            console.log("No INITIAL_SUPPLY specified, skipping minting");
        }
        
        if (initialSupply > 0) {
            uint8 tokenDecimals = token.decimals();
            uint256 amountToMint = initialSupply * (10 ** tokenDecimals);
            
            console.log("Attempting to mint initial supply:", initialSupply);
            try token.mint(deployer, amountToMint) {
                console.log("Initial supply minted successfully:", initialSupply);
                
                // Verify balance after minting
                try token.balanceOf(deployer) returns (uint256 balance) {
                    console.log("Deployer balance after minting:", balance / (10 ** tokenDecimals));
                } catch {
                    console.log("WARNING: Failed to verify balance after minting");
                }
            } catch Error(string memory reason) {
                console.log("WARNING: Minting failed with reason:", reason);
                console.log("You will need to mint tokens manually");
            } catch {
                console.log("WARNING: Minting failed with unknown error");
                console.log("You will need to mint tokens manually");
            }
        }
        
        // Log deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("Version Registry:", registryAddress);
        console.log("Security Token Factory:", factoryAddress);
        console.log("AccreditedInvestor Module:", aiModuleAddress);
        console.log("InsiderRegistry Module:", insiderRegistryAddress);
        console.log("Attribute Registry:", vm.envAddress("ATTRIBUTE_REGISTRY_ADDRESS"));
        console.log("Deployed Token:", tokenAddress);
        console.log("Token Compliance:", complianceAddress);
    }
}