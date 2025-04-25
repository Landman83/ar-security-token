// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/SecurityToken.sol";
import "../src/SecurityTokenFactory.sol";
import "../src/compliance/ModularCompliance.sol";
import "../src/proxy/authority/TREXImplementationAuthority.sol";
import "../src/interfaces/ITREXImplementationAuthority.sol";

/**
 * @title DeployTokenScript
 * @dev Deploys a new security token using the factory
 */
contract DeployTokenScript is Script {
    function run(
        address factoryAddress,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address attributeRegistry,
        address accreditedInvestorModule,
        address lockupModule
    ) public returns (address tokenAddress) {
        // Deploy a new security token
        console.log("Deploying Security Token with params:");
        console.log(" - Name:", name);
        console.log(" - Symbol:", symbol);
        console.log(" - Decimals:", decimals);
        console.log(" - Factory:", factoryAddress);
        console.log(" - Attribute Registry:", attributeRegistry);
        console.log(" - Accredited Investor Module:", accreditedInvestorModule);
        console.log(" - Lockup Module:", lockupModule);

        address deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        console.log(" - Deployer:", deployer);

        SecurityTokenFactory factory = SecurityTokenFactory(factoryAddress);

        // Generate a unique salt based on name and symbol
        string memory salt = string(abi.encodePacked(name, "-", symbol, "-", block.timestamp));
        
        // Create an empty array for compliance modules (we'll add them manually after)
        address[] memory emptyModules = new address[](0);
        
        // Deploy token via factory
        factory.deployToken(
            salt,
            name,
            symbol,
            decimals,
            deployer, // Setting deployer as initial owner
            attributeRegistry,
            emptyModules
        );
        
        // Get the token address from the factory
        tokenAddress = factory.getToken(salt);
        console.log("Token deployed at:", tokenAddress);

        // Configure token compliance
        console.log("Configuring token compliance...");
        SecurityToken token = SecurityToken(tokenAddress);
        address complianceAddress = address(token.compliance());
        console.log("Token compliance is at:", complianceAddress);

        // Add compliance modules to the token
        console.log("Adding compliance modules...");
        ModularCompliance compliance = ModularCompliance(complianceAddress);
        compliance.addModule(accreditedInvestorModule);
        console.log("Added AccreditedInvestor module");
        compliance.addModule(lockupModule);
        console.log("Added Lockup module");

        // Mint initial supply
        uint256 initialSupply = vm.envUint("INITIAL_SUPPLY");
        if (initialSupply > 0) {
            console.log("Minting initial supply:", initialSupply);
            uint256 decimalFactor = 10 ** decimals;
            uint256 initialSupplyWithDecimals = initialSupply * decimalFactor;
            token.mint(deployer, initialSupplyWithDecimals);
            console.log("Initial supply minted to:", deployer);
        }

        return tokenAddress;
    }
}