// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../../src/compliance/modules/AccreditedInvestor.sol";
import "../../src/compliance/modules/Lockup.sol";
import "../../src/compliance/modules/InsiderRegistry.sol";
import "../../src/interfaces/IInsiderRegistry.sol";
import "../../src/proxy/ComplianceModuleProxy.sol";

/**
 * @title DeployModulesScript
 * @dev Deploys compliance modules
 */
contract DeployModulesScript is Script {
    function run(address attributeRegistry) public returns (address aicm, address lockupCM, address insiderRegistry) {
        // Get deployer address from environment
        address deployer;
        try vm.envAddress("DEPLOYER_ADDRESS") returns (address deployerAddr) {
            deployer = deployerAddr;
            console.log("Using deployer address from environment in module deployment:", deployer);
        } catch {
            deployer = msg.sender; // Fallback to msg.sender if no environment variable
            console.log("No DEPLOYER_ADDRESS set, using msg.sender as deployer in module deployment:", deployer);
        }
        // Deploy AccreditedInvestor Module
        console.log("Deploying AccreditedInvestor implementation...");
        AccreditedInvestor aiImplementation = new AccreditedInvestor();
        console.log("AccreditedInvestor implementation deployed at:", address(aiImplementation));

        // Deploy Lockup Module Implementation
        console.log("Deploying Lockup implementation...");
        Lockup lockupImplementation = new Lockup();
        console.log("Lockup implementation deployed at:", address(lockupImplementation));

        // Deploy InsiderRegistry
        console.log("Deploying InsiderRegistry implementation...");
        InsiderRegistry irImplementation = new InsiderRegistry();
        console.log("InsiderRegistry implementation deployed at:", address(irImplementation));

        // Prepare initialization data
        bytes memory aiInitData = abi.encodeWithSelector(AccreditedInvestor.initialize.selector);
        bytes memory lockupInitData = abi.encodeWithSelector(Lockup.initialize.selector);
        bytes memory irInitData = abi.encodeWithSelector(InsiderRegistry.initialize.selector);

        // Deploy AccreditedInvestor Module Proxy
        console.log("Deploying AccreditedInvestor module proxy...");
        ComplianceModuleProxy aiProxy = new ComplianceModuleProxy(address(aiImplementation), aiInitData);
        aicm = address(aiProxy);
        console.log("AccreditedInvestor module proxy deployed at:", aicm);

        // Deploy Lockup Module Proxy
        console.log("Deploying Lockup module proxy...");
        ComplianceModuleProxy lockupProxy = new ComplianceModuleProxy(address(lockupImplementation), lockupInitData);
        lockupCM = address(lockupProxy);
        console.log("Lockup module proxy deployed at:", lockupCM);

        // Deploy InsiderRegistry Proxy
        console.log("Deploying InsiderRegistry proxy...");
        ComplianceModuleProxy irProxy = new ComplianceModuleProxy(address(irImplementation), irInitData);
        insiderRegistry = address(irProxy);
        console.log("InsiderRegistry proxy deployed at:", insiderRegistry);

        // Configure AccreditedInvestor Module
        console.log("Setting attribute registry in AccreditedInvestor module...");
        AccreditedInvestor(aicm).setAttributeRegistry(attributeRegistry);
        console.log("Setting insider registry in AccreditedInvestor module...");
        AccreditedInvestor(aicm).setInsiderRegistry(insiderRegistry);
        AccreditedInvestor(aicm).setInsidersExemptFromAccreditation(true);
        console.log("AccreditedInvestor module configured");
        
        // Add the actual deployer address as an insider
        console.log("Adding deployer as AGENT insider:", deployer);
        InsiderRegistry(insiderRegistry).addInsider(deployer, uint8(IInsiderRegistry.InsiderType.AGENT));
        
        // Also add them as agent in the registry
        console.log("Adding deployer as agent:", deployer);
        InsiderRegistry(insiderRegistry).addAgent(deployer);
        
        // Transfer ownership to the actual deployer
        AccreditedInvestor(aicm).transferOwnership(deployer);
        Lockup(lockupCM).transferOwnership(deployer);
        InsiderRegistry(insiderRegistry).transferOwnership(deployer);
        console.log("Module ownership transferred to deployer:", deployer);

        return (aicm, lockupCM, insiderRegistry);
    }
}