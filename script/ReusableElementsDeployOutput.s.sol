// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "./ReusableElementsDeploy.s.sol";

/**
 * @title ReusableElementsDeployOutputScript
 * @dev Wrapper script that runs the deployment and outputs the results to console
 */
contract ReusableElementsDeployOutputScript is Script {
    function run() public {
        // Read deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        require(deployerPrivateKey != 0, "Deployer private key not set in environment");
        
        // Run the deployment script with the deployer's private key
        vm.startBroadcast(deployerPrivateKey);
        
        // Run the deployment script
        ReusableElementsDeployScript deployer = new ReusableElementsDeployScript();
        ReusableElementsDeployScript.DeployedContracts memory deployed = deployer.run();
        
        vm.stopBroadcast();
        
        // Output a summary in JSON format on the console
        console.log("\n===== DEPLOYMENT DETAILS (JSON FORMAT) =====");
        console.log("{");
        console.log('  "timestamp": "%s",', block.timestamp);
        console.log('  "chainId": %s,', block.chainid);
        console.log('  "contracts": {');
        console.log('    "implementationAuthority": "%s",', deployed.implementationAuthority);
        console.log('    "accreditedInvestorModule": "%s",', deployed.accreditedInvestorModule);
        console.log('    "lockupModule": "%s",', deployed.lockupModule);
        console.log('    "securityTokenFactory": "%s"', deployed.securityTokenFactory);
        console.log('  },');
        console.log('  "attributeRegistry": "%s"', deployed.attributeRegistry);
        console.log("}");
        console.log("\nCopy these values to a safe location for future reference.");
    }
}