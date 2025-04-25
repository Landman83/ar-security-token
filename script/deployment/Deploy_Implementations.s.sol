// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../../src/SecurityToken.sol";
import "../../src/compliance/ModularCompliance.sol";

/**
 * @title DeployImplementationsScript
 * @dev Deploys token and compliance implementations
 */
contract DeployImplementationsScript is Script {
    function run() public returns (address tokenImpl, address mcImpl) {
        // Deploy the token implementation
        console.log("Deploying SecurityToken implementation...");
        SecurityToken tokenImplementation = new SecurityToken();
        tokenImpl = address(tokenImplementation);
        console.log("Token implementation deployed at:", tokenImpl);
        
        // Deploy the compliance implementation
        console.log("Deploying ModularCompliance implementation...");
        ModularCompliance complianceImplementation = new ModularCompliance();
        mcImpl = address(complianceImplementation);
        console.log("ModularCompliance implementation deployed at:", mcImpl);
        
        return (tokenImpl, mcImpl);
    }
}