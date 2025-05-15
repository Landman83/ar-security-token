// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestUSD
 * @dev A simple ERC20 token for testing purposes
 */
contract TestUSD is ERC20, Ownable {
    uint8 private _decimals;

    /**
     * @dev Constructor that mints an initial supply to the creator
     * @param initialSupply The initial amount of tokens to mint
     * @param decimalsValue The number of decimals for the token
     */
    constructor(
        uint256 initialSupply,
        uint8 decimalsValue
    ) ERC20("Test USD", "tUSD") Ownable(msg.sender) {
        _decimals = decimalsValue;
        _mint(msg.sender, initialSupply * (10 ** decimalsValue));
    }

    /**
     * @dev Override the decimals function to use a custom value
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Allows the owner to mint additional tokens
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

/**
 * @title DeployTUSDScript
 * @dev Script to deploy TestUSD token with initial supply minted to deployer
 */
contract DeployTUSDScript is Script {
    function run() public {
        // Get deployer address from environment or use msg.sender
        address deployer;
        try vm.envAddress("DEPLOYER_ADDRESS") returns (address deployerAddr) {
            deployer = deployerAddr;
            console.log("Using deployer address from environment:", deployer);
        } catch {
            deployer = msg.sender;
            console.log("No DEPLOYER_ADDRESS set, using msg.sender as deployer:", deployer);
        }

        // Get initial supply and decimals, or use defaults
        uint256 initialSupply = 100000000; // 100 million tokens
        uint8 tokenDecimals = 18;

        try vm.envUint("TUSD_INITIAL_SUPPLY") returns (uint256 supply) {
            if (supply > 0) {
                initialSupply = supply;
            }
        } catch {}

        try vm.envUint("TUSD_DECIMALS") returns (uint256 decimals) {
            if (decimals <= 18) {
                tokenDecimals = uint8(decimals);
            }
        } catch {}

        console.log("Deploying Test USD with:");
        console.log("Initial supply:", initialSupply);
        console.log("Decimals:", tokenDecimals);

        vm.startBroadcast(deployer);

        // Deploy TestUSD with initial supply
        TestUSD token = new TestUSD(initialSupply, tokenDecimals);
        address tokenAddress = address(token);

        vm.stopBroadcast();

        console.log("\n=== Deployment Successful ===");
        console.log("Test USD (tUSD) deployed to:", tokenAddress);
        console.log("Initial supply minted to:", deployer);
        
        // Calculate actual token amount with decimals
        uint256 actualSupply = initialSupply * (10 ** tokenDecimals);
        console.log("Total supply:", initialSupply, "tUSD");
        console.log("Total supply with decimals:", actualSupply);

        console.log("\nToken information:");
        console.log("Name:", "Test USD");
        console.log("Symbol:", "tUSD");
        console.log("Decimals:", tokenDecimals);
        console.log("Owner:", deployer);
    }
}