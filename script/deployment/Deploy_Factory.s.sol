// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../../src/RefactoredSecurityTokenFactory.sol";

/**
 * @title DeployFactoryScript
 * @dev Deploys the RefactoredSecurityTokenFactory
 */
contract DeployFactoryScript is Script {
    function run(address versionRegistry) public returns (address) {
        // Deploy RefactoredSecurityTokenFactory
        console.log("Deploying RefactoredSecurityTokenFactory...");
        RefactoredSecurityTokenFactory factory = new RefactoredSecurityTokenFactory(versionRegistry);
        console.log("RefactoredSecurityTokenFactory deployed at:", address(factory));

        // Transfer ownership to the caller
        factory.transferOwnership(msg.sender);
        console.log("Factory ownership transferred to:", msg.sender);
        
        return address(factory);
    }
}