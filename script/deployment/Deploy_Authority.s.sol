// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../../src/proxy/authority/TREXImplementationAuthority.sol";
import "../../src/interfaces/ITREXImplementationAuthority.sol";

/**
 * @title DeployAuthorityScript
 * @dev Deploys implementation authority and registers implementations
 */
contract DeployAuthorityScript is Script {
    function run(address tokenImpl, address mcImpl) public returns (address) {
        // Deploy Implementation Authority
        console.log("Deploying TREX implementation authority...");
        TREXImplementationAuthority implementationAuthority = new TREXImplementationAuthority(
            true,   // reference status
            address(0),  // trexFactory - will be set later
            address(0)   // iaFactory - not used in this deployment
        );
        address implAuthAddress = address(implementationAuthority);
        console.log("Implementation authority deployed at:", implAuthAddress);
        
        // Add a version with the implementations
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
        
        // Transfer ownership to the caller so the main script can call setTREXFactory
        implementationAuthority.transferOwnership(msg.sender);
        console.log("Implementation authority ownership transferred to:", msg.sender);
        
        return implAuthAddress;
    }
}