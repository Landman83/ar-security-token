// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../../src/SecurityTokenFactory.sol";

/**
 * @title DeployFactoryScript
 * @dev Deploys the SecurityTokenFactory
 */
contract DeployFactoryScript is Script {
    function run(address implementationAuthority) public returns (address) {
        // Deploy SecurityTokenFactory
        console.log("Deploying SecurityTokenFactory...");
        SecurityTokenFactory factory = new SecurityTokenFactory(implementationAuthority);
        console.log("SecurityTokenFactory deployed at:", address(factory));

        // Transfer ownership to the caller
        factory.transferOwnership(msg.sender);
        console.log("Factory ownership transferred to:", msg.sender);
        
        return address(factory);
    }
}