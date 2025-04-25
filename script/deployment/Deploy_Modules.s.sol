// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../../src/compliance/modules/AccreditedInvestor.sol";
import "../../src/compliance/modules/Lockup.sol";
import "../../src/proxy/ComplianceModuleProxy.sol";

/**
 * @title DeployModulesScript
 * @dev Deploys compliance modules
 */
contract DeployModulesScript is Script {
    function run(address attributeRegistry) public returns (address aicm, address lockupCM) {
        // Deploy AccreditedInvestor Module
        console.log("Deploying AccreditedInvestor implementation...");
        AccreditedInvestor aiImplementation = new AccreditedInvestor();
        console.log("AccreditedInvestor implementation deployed at:", address(aiImplementation));

        // Deploy Lockup Module Implementation
        console.log("Deploying Lockup implementation...");
        Lockup lockupImplementation = new Lockup();
        console.log("Lockup implementation deployed at:", address(lockupImplementation));

        // Prepare initialization data
        bytes memory aiInitData = abi.encodeWithSelector(AccreditedInvestor.initialize.selector);
        bytes memory lockupInitData = abi.encodeWithSelector(Lockup.initialize.selector);

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

        // Configure AccreditedInvestor Module
        console.log("Setting attribute registry in AccreditedInvestor module...");
        AccreditedInvestor(aicm).setAttributeRegistry(attributeRegistry);
        console.log("AccreditedInvestor module configured");
        
        // Transfer ownership to the caller
        AccreditedInvestor(aicm).transferOwnership(msg.sender);
        Lockup(lockupCM).transferOwnership(msg.sender);
        console.log("Module ownership transferred to caller:", msg.sender);

        return (aicm, lockupCM);
    }
}