// staged-deploy-reuse-ir.js
// Deploys a Rule506c token using a multi-stage approach with option to reuse existing identity registry
const hre = require("hardhat");
const { ethers } = require("hardhat");
const readline = require('readline');
require('dotenv').config({ path: '.env.local' });
// Also load from .env as a fallback
require('dotenv').config();

// Create readline interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function askQuestion(question) {
  return new Promise(resolve => {
    rl.question(question, answer => {
      resolve(answer);
    });
  });
}

async function main() {
  try {
    console.log("\n=== Rule506c Token Deployment with Shared Identity Registry ===\n");
    
    // Network selection
    console.log("Available networks:");
    console.log("1. Local Hardhat Network");
    console.log("2. Polygon Mainnet");
    console.log("3. Local Anvil Network (127.0.0.1:8545)");
    
    const networkChoice = await askQuestion("Select network (1-3): ");
    
    // Let user set gas price for Polygon
    let customGasPrice = 50; // Default is 50 gwei
    if (networkChoice === "2") {
      const gasInput = await askQuestion("Enter gas price in gwei (minimum 40 recommended, default 50): ");
      if (gasInput && !isNaN(parseFloat(gasInput))) {
        customGasPrice = parseFloat(gasInput);
        if (customGasPrice < 40) {
          console.warn("⚠️ WARNING: Gas price below 40 gwei may cause transactions to fail");
          const confirm = await askQuestion("Continue with low gas price? (y/n): ");
          if (confirm.toLowerCase() !== 'y') {
            customGasPrice = 50;
            console.log("Using default 50 gwei gas price");
          }
        }
      }
      console.log(`Using gas price: ${customGasPrice} gwei`);
    }
    
    let deployer;
    let providerUrl;
    
    // Configure selected network
    if (networkChoice === "2") {
      // Polygon Mainnet
      console.log("\nUsing Polygon Mainnet");
      
      // Check for PRIVATE_KEY in environment
      if (!process.env.PRIVATE_KEY) {
        console.error("Error: PRIVATE_KEY not found in environment variables");
        console.log("Please create a .env file with your PRIVATE_KEY");
        process.exit(1);
      }
      
      // Check for RPC URL
      if (!process.env.POLYGON_RPC_URL) {
        console.error("Error: POLYGON_RPC_URL not found in environment variables");
        console.log("Please add POLYGON_RPC_URL to your .env file");
        process.exit(1);
      }
      
      providerUrl = process.env.POLYGON_RPC_URL;
      
      // Connect to Polygon mainnet
      const provider = new ethers.providers.JsonRpcProvider(providerUrl);
      deployer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
      
      console.log(`Connected to Polygon Mainnet`);
      console.log(`Deployer address: ${deployer.address}`);
      console.log(`Deployer balance: ${ethers.utils.formatEther(await deployer.getBalance())} MATIC`);
      
      // Check if deployer has enough MATIC
      const balance = await deployer.getBalance();
      if (balance.lt(ethers.utils.parseEther("0.5"))) {
        console.warn("WARNING: Deployer account has less than 0.5 MATIC");
        const continueAnyway = await askQuestion("Continue anyway? (y/n): ");
        if (continueAnyway.toLowerCase() !== 'y') {
          console.log("Deployment cancelled.");
          process.exit(0);
        }
      }
      
      // Override ethers.js functions to use our custom provider and signer
      const originalGetSigners = ethers.getSigners;
      ethers.getSigners = async () => [deployer];
      
    } else if (networkChoice === "3") {
      // Local Anvil Network
      console.log("\nUsing Local Anvil Network (127.0.0.1:8545)");
      
      providerUrl = "http://127.0.0.1:8545";
      const provider = new ethers.providers.JsonRpcProvider(providerUrl);
      
      // Check if Anvil is running
      try {
        await provider.getBlockNumber();
      } catch (error) {
        console.error("Error connecting to Anvil. Make sure it's running at 127.0.0.1:8545");
        process.exit(1);
      }
      
      // Use the first account from Anvil
      const accounts = await provider.listAccounts();
      if (accounts.length === 0) {
        console.error("No accounts found on Anvil network");
        process.exit(1);
      }
      
      // Use the default first account from Anvil (known private key)
      deployer = new ethers.Wallet(
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80", 
        provider
      );
      
      console.log(`Connected to Anvil`);
      console.log(`Deployer address: ${deployer.address}`);
      console.log(`Deployer balance: ${ethers.utils.formatEther(await deployer.getBalance())} ETH`);
      
      // Override ethers.js functions to use our custom provider and signer
      const originalGetSigners = ethers.getSigners;
      ethers.getSigners = async () => [deployer];
      
    } else {
      // Default: Local Hardhat Network
      console.log("\nUsing local Hardhat Network");
      [deployer] = await ethers.getSigners();
      console.log(`Deployer address: ${deployer.address}`);
    }
    
    // 1. Get token parameters from user
    const tokenName = await askQuestion("Enter token name: ");
    const tokenSymbol = await askQuestion("Enter token symbol: ");
    const tokenDecimalsInput = await askQuestion("Enter token decimals (press Enter for default 18): ");
    const tokenDecimals = tokenDecimalsInput ? parseInt(tokenDecimalsInput) : 18;
    
    // 2. Ask about using existing Identity Registry
    const useExistingIR = await askQuestion("Do you want to use an existing Identity Registry? (y/n): ");
    let existingIdentityRegistryAddress = null;
    
    if (useExistingIR.toLowerCase() === 'y') {
      existingIdentityRegistryAddress = await askQuestion("Enter the address of the existing Identity Registry: ");
      
      // Validate address format
      if (!ethers.utils.isAddress(existingIdentityRegistryAddress)) {
        console.error("Error: Invalid Identity Registry address format");
        process.exit(1);
      }
      
      // Try to get the Identity Registry to verify it exists
      try {
        const existingIR = await ethers.getContractAt("IIdentityRegistry", existingIdentityRegistryAddress);
        const storageAddress = await existingIR.identityStorage();
        console.log(`Identity Registry verified at: ${existingIdentityRegistryAddress}`);
        console.log(`Associated Identity Registry Storage: ${storageAddress}`);
      } catch (error) {
        console.error("Error: Could not connect to Identity Registry at the provided address");
        console.error("Make sure the address is correct and the contract implements IIdentityRegistry");
        process.exit(1);
      }
    }
    
    // 3. Ask about initial token supply
    const mintInitialSupply = await askQuestion("Do you want to mint an initial token supply? (y/n): ");
    let initialSupply = "0";
    let initialSupplyRecipient = null;
    
    if (mintInitialSupply.toLowerCase() === 'y') {
      const initialSupplyInput = await askQuestion("Enter initial supply (press Enter for default 1,000,000): ");
      initialSupply = initialSupplyInput ? initialSupplyInput : "1000000";
      
      initialSupplyRecipient = await askQuestion("Enter recipient address for initial supply (press Enter to use deployer address): ");
      if (!initialSupplyRecipient || !ethers.utils.isAddress(initialSupplyRecipient)) {
        initialSupplyRecipient = deployer.address;
        console.log(`Using deployer address as recipient: ${initialSupplyRecipient}`);
      }
      
      console.log(`Will mint ${initialSupply} tokens to ${initialSupplyRecipient}`);
    }
    
    console.log("\nDeployment Parameters:");
    console.log(`Token Name: ${tokenName}`);
    console.log(`Token Symbol: ${tokenSymbol}`);
    console.log(`Decimals: ${tokenDecimals}`);
    console.log(`Network: ${networkChoice === "2" ? "Polygon Mainnet" : 
                          (networkChoice === "3" ? "Local Anvil" : "Local Hardhat")}`);
    if (existingIdentityRegistryAddress) {
      console.log(`Using existing Identity Registry: ${existingIdentityRegistryAddress}`);
    } else {
      console.log("Will deploy new Identity Registry");
    }
    if (mintInitialSupply.toLowerCase() === 'y') {
      console.log(`Initial supply: ${initialSupply} tokens to ${initialSupplyRecipient}`);
    }
    
    // Display gas price for mainnet deployments
    if (networkChoice === "2") {
      const provider = deployer.provider;
      
      try {
        // Get current gas price from the network
        const gasPrice = await provider.getGasPrice();
        console.log(`Current network gas price: ${ethers.utils.formatUnits(gasPrice, "gwei")} gwei`);
        
        // Our custom gas price for Polygon
        const fixedGasPrice = ethers.utils.parseUnits(customGasPrice.toString(), "gwei"); // Custom gwei value
        console.log(`Using fixed gas price: ${ethers.utils.formatUnits(fixedGasPrice, "gwei")} gwei`);
        
        // IMPORTANT: Using legacy transactions (not EIP-1559) for better compatibility
        console.log("Using legacy (type 0) transactions to avoid EIP-1559 issues");
        console.log("⚠️ Based on error messages, minimum required gas price is 40+ gwei");
        
        // Override ethers default gas price
        const originalGetGasPrice = provider.getGasPrice;
        provider.getGasPrice = async () => fixedGasPrice;
        
        // Ensure we use legacy transactions by modifying the populateTransaction
        const originalPopulate = ethers.Contract.prototype.populateTransaction;
        ethers.Contract.prototype.populateTransaction = async function(method, args) {
          const tx = await originalPopulate.call(this, method, args);
          // Force legacy transaction type
          tx.type = 0;
          tx.gasPrice = fixedGasPrice;
          // Remove any EIP-1559 specific fields
          delete tx.maxFeePerGas;
          delete tx.maxPriorityFeePerGas;
          return tx;
        };
        
        // Override signer's sendTransaction to use legacy transactions
        const originalSendTransaction = deployer.sendTransaction;
        deployer.sendTransaction = async function(tx) {
          // Make sure we're using legacy transactions
          tx.type = 0;
          tx.gasPrice = fixedGasPrice;
          // Remove any EIP-1559 specific fields
          delete tx.maxFeePerGas;
          delete tx.maxPriorityFeePerGas;
          
          console.log("Sending transaction with gasPrice:", ethers.utils.formatUnits(tx.gasPrice || fixedGasPrice, "gwei"), "gwei");
          return originalSendTransaction.call(this, tx);
        };
      } catch (error) {
        console.warn("Warning: Error setting up gas price overrides:", error.message);
        console.log("Using default gas price: 50 gwei");
      }
      
      // Estimate deployment cost (using high estimate to be safe)
      console.log("Estimated deployment cost: ~0.5-1 MATIC (varies based on network conditions)");
      console.log("⚠️ Make sure you have at least 1 MATIC in your wallet!");
    }
    
    const confirm = await askQuestion("\nConfirm deployment? (y/n): ");
    if (confirm.toLowerCase() !== 'y') {
      console.log("Deployment cancelled.");
      process.exit(0);
    }
    
    // 4. Deploy using the slim approach
    console.log("\nStarting staged deployment process...");
    console.log("Stage 1: Deploying implementation authority and compliance modules...");
    
    // Get the deployer account (already configured above)
    console.log(`Using deployer address: ${deployer.address}`);
    
    // Deploy implementation authority
    const deployImplementationAuthority = require("./scripts/deploy/deploy-implementation-authority");
    console.log("Deploying implementation authority...");
    
    // Add gas settings for Polygon - use legacy transactions with custom gas price
    const overrides = networkChoice === "2" ? {
      gasLimit: 5000000,
      gasPrice: ethers.utils.parseUnits(customGasPrice.toString(), "gwei"), // Use custom gas price
      type: 0 // Force legacy transaction type (pre-EIP-1559)
    } : {};
    
    const implementationAuthority = await deployImplementationAuthority(null, overrides);
    console.log(`Implementation authority deployed to: ${implementationAuthority.trexImplementationAuthority}`);
    
    // Deploy compliance modules
    const deployComplianceModules = require("./scripts/deploy/deploy-compliance-modules");
    console.log("Deploying compliance modules...");
    const complianceModules = await deployComplianceModules();
    console.log(`KYC module deployed to: ${complianceModules.kycModule}`);
    console.log(`Lockup module deployed to: ${complianceModules.lockupModule}`);
    
    // Deploy or use existing Rule506c factory
    console.log("\nStage 2: Setting up Rule506c factory...");
    
    // Ask if user wants to use an existing factory
    const useExistingFactory = await askQuestion("Do you want to use an existing Rule506c factory? (y/n): ");
    let factoryAddress;
    let factoryDeploy = {};
    
    if (useExistingFactory.toLowerCase() === 'y') {
      factoryAddress = await askQuestion("Enter the existing Rule506c factory address: ");
      if (!ethers.utils.isAddress(factoryAddress)) {
        throw new Error("Invalid factory address");
      }
      console.log(`Using existing Rule506c factory at: ${factoryAddress}`);
      factoryDeploy.rule506cFactory = factoryAddress;
    } else {
      // Deploy a new factory
      console.log("Deploying new Rule506c factory...");
      const deployRule506cFactory = require("./scripts/deploy/deploy-rule506c-factory");
      factoryDeploy = await deployRule506cFactory(
        implementationAuthority.trexImplementationAuthority
      );
      factoryAddress = factoryDeploy.rule506cFactory;
      console.log(`Rule506c factory deployed to: ${factoryAddress}`);
    }
    
    // Verify that the factory supports the deployTokenWithExistingIR function
    const factoryContract = await ethers.getContractAt("Rule506cFactory", factoryAddress);
    let supportsExistingIR = false;
    
    try {
      // Check if the function exists by looking at the ABI
      const factoryAbi = factoryContract.interface.fragments;
      for (const fragment of factoryAbi) {
        if (fragment.name === 'deployTokenWithExistingIR') {
          supportsExistingIR = true;
          break;
        }
      }
      
      console.log(`Factory ${supportsExistingIR ? 'supports' : 'does not support'} direct deployment with existing Identity Registry`);
    } catch (error) {
      console.log("Could not determine if factory supports direct deployment with existing Identity Registry");
      console.log("Will use fallback approach if needed");
    }
    
    // Deploy token using slim approach
    console.log("\nStage 3: Deploying token using Rule506c factory...");
    
    const tokenParams = {
      name: tokenName,
      symbol: tokenSymbol,
      decimals: tokenDecimals,
      owner: deployer.address
    };
    
    // Add gas settings for Polygon - use legacy transactions with custom gas price
    const tokenDeployOverrides = networkChoice === "2" ? {
      gasLimit: 9000000,
      gasPrice: ethers.utils.parseUnits(customGasPrice.toString(), "gwei"), // Use custom gas price
      type: 0 // Force legacy transaction type (pre-EIP-1559)
    } : {};
    
    // Custom implementation to support existing Identity Registry
    console.log("Customizing token deployment for existing Identity Registry...");
    
    // Get the factory contract
    const factory = await ethers.getContractAt("Rule506cFactory", factoryDeploy.rule506cFactory);
    
    // Create a salt for deterministic address
    const salt = `${tokenParams.owner.toLowerCase()}${tokenParams.name}`;
    console.log(`Using salt for deployment: ${salt}`);
    
    // Deploy the token through the factory
    console.log("Deploying token through Rule506c Factory...");
    
    let deployTx;
    let token;
    
    // MODIFICATION: Check if we're using existing Identity Registry or deploying new one
    if (existingIdentityRegistryAddress) {
      console.log(`Using existing Identity Registry at: ${existingIdentityRegistryAddress}`);
      
      // Check if the factory supports direct deployment with existing Identity Registry
      if (supportsExistingIR) {
        // Use direct method if supported
        console.log("Using direct deployment with existing Identity Registry...");
        
        console.log("Deployment parameters:");
        console.log(`Salt: ${salt}`);
        console.log(`Name: ${tokenParams.name}`);
        console.log(`Symbol: ${tokenParams.symbol}`);
        console.log(`Decimals: ${tokenParams.decimals}`);
        console.log(`Owner: ${tokenParams.owner}`);
        console.log(`Identity Registry: ${existingIdentityRegistryAddress}`);
        console.log(`Compliance modules: ${[complianceModules.kycModule, complianceModules.lockupModule]}`);
        
        try {
          // Deploy using existing Identity Registry
          deployTx = await factoryContract.deployTokenWithExistingIR(
            salt,
            tokenParams.name,
            tokenParams.symbol,
            tokenParams.decimals,
            tokenParams.owner,
            existingIdentityRegistryAddress,
            [complianceModules.kycModule, complianceModules.lockupModule],
            tokenDeployOverrides
          );
          
          console.log("Transaction sent, hash:", deployTx.hash);
        } catch (error) {
          console.error("Error deploying token with existing IR:", error);
          console.log("Falling back to standard deployment...");
          
          // Deploy standard token as fallback
          deployTx = await factoryContract.deployRule506cToken(
            salt,
            tokenParams.name,
            tokenParams.symbol,
            tokenParams.decimals,
            tokenParams.owner,
            [complianceModules.kycModule, complianceModules.lockupModule],
            tokenDeployOverrides
          );
          
          console.log("Transaction sent, hash:", deployTx.hash);
        }
      } else {
        // Factory doesn't support direct deployment, use fallback approach
        console.log("Factory does not support direct deployment with existing Identity Registry");
        console.log("Using two-step approach: deploy standard token and then update its Identity Registry");
        
        // Deploy standard token first
        deployTx = await factoryContract.deployRule506cToken(
          salt,
          tokenParams.name,
          tokenParams.symbol,
          tokenParams.decimals,
          tokenParams.owner,
          [complianceModules.kycModule, complianceModules.lockupModule],
          tokenDeployOverrides
        );
        
        console.log("Transaction sent, hash:", deployTx.hash);
      }
    } else {
      // Standard deployment with new Identity Registry
      try {
        console.log("Deployment parameters:");
        console.log(`Salt: ${salt}`);
        console.log(`Name: ${tokenParams.name}`);
        console.log(`Symbol: ${tokenParams.symbol}`);
        console.log(`Decimals: ${tokenParams.decimals}`);
        console.log(`Owner: ${tokenParams.owner}`);
        console.log(`Compliance modules: ${[complianceModules.kycModule, complianceModules.lockupModule]}`);
        
        // Regular deployment with new Identity Registry
        deployTx = await factoryContract.deployRule506cToken(
          salt,
          tokenParams.name,
          tokenParams.symbol,
          tokenParams.decimals,
          tokenParams.owner,
          [complianceModules.kycModule, complianceModules.lockupModule],
          tokenDeployOverrides
        );
        
        console.log("Transaction sent, hash:", deployTx.hash);
      } catch (error) {
        console.error("Error deploying token:", error);
        throw error;
      }
    }
    
    // Wait for the transaction to be mined
    console.log("Waiting for transaction to be mined...");
    await deployTx.wait();
    
    // Get the token address from the factory
    console.log("Retrieving token address from factory...");
    const tokenAddress = await factoryContract.getToken(salt);
    console.log(`Token deployed at: ${tokenAddress}`);
    
    // Get token information
    token = await ethers.getContractAt("Token", tokenAddress);
    
    // If we need to update the Identity Registry (fallback approach)
    let irAddress = await token.identityRegistry();
    
    if (existingIdentityRegistryAddress && irAddress.toLowerCase() !== existingIdentityRegistryAddress.toLowerCase()) {
      console.log("Updating token to use the existing Identity Registry...");
      await token.setIdentityRegistry(existingIdentityRegistryAddress, tokenDeployOverrides);
      console.log("Identity Registry updated");
      irAddress = existingIdentityRegistryAddress;
    }
    
    const complianceAddress = await token.compliance();
    const tokenOnchainId = await token.onchainID();
    
    console.log(`Token name: ${await token.name()}`);
    console.log(`Token symbol: ${await token.symbol()}`);
    console.log(`Token decimals: ${await token.decimals()}`);
    console.log(`Token owner: ${await token.owner()}`);
    console.log(`Token identity registry: ${irAddress}`);
    console.log(`Token compliance: ${complianceAddress}`);
    console.log(`Token onchain ID: ${tokenOnchainId}`);
    
    // MINT INITIAL SUPPLY IF REQUESTED
    if (mintInitialSupply.toLowerCase() === 'y' && initialSupply !== "0") {
      console.log(`\nStage 4: Minting initial supply of ${initialSupply} tokens to ${initialSupplyRecipient}...`);
      
      try {
        // Check if recipient is verified in the identity registry
        const identityRegistry = await ethers.getContractAt("IIdentityRegistry", irAddress);
        const isVerified = await identityRegistry.isVerified(initialSupplyRecipient);
        
        if (!isVerified) {
          console.log(`⚠️ WARNING: Recipient ${initialSupplyRecipient} is not verified in the Identity Registry.`);
          console.log("Tokens can only be minted to verified addresses.");
          
          const proceedAnyway = await askQuestion("Attempt to mint anyway? (y/n): ");
          if (proceedAnyway.toLowerCase() !== 'y') {
            console.log("Minting skipped. You can mint tokens later after registering the address.");
          } else {
            console.log("Attempting to mint even though address is not verified (will likely fail)...");
          }
        }
        
        if (isVerified || proceedAnyway?.toLowerCase() === 'y') {
          // Check if deployer is an agent of the token
          const isAgent = await token.isAgent(deployer.address);
          if (!isAgent) {
            console.log("Adding deployer as agent to enable minting...");
            await token.addAgent(deployer.address);
            console.log("Deployer added as agent");
          }
          
          // Mint tokens
          console.log(`Minting ${initialSupply} tokens to ${initialSupplyRecipient}...`);
          const mintTx = await token.mint(
            initialSupplyRecipient, 
            ethers.utils.parseUnits(initialSupply, tokenDecimals),
            tokenDeployOverrides
          );
          
          console.log("Minting transaction sent, hash:", mintTx.hash);
          await mintTx.wait();
          console.log("✅ Minting completed successfully");
          
          // Verify the balance
          const balance = await token.balanceOf(initialSupplyRecipient);
          console.log(`Verified balance: ${ethers.utils.formatUnits(balance, tokenDecimals)} ${tokenSymbol}`);
        }
      } catch (error) {
        console.error("Error during minting:", error.message);
        console.log("You can try minting tokens later using the token's mint function.");
      }
    }
    
    // Ask if user wants to deploy corporate actions
    const deployActions = await askQuestion("\nDo you want to deploy corporate action modules (dividend and voting)? (y/n): ");
    
    if (deployActions.toLowerCase() === 'y') {
      // Stage 5: Deploy corporate action modules (dividend and voting)
      console.log("\nStage 5: Deploying corporate action modules...");
      
      // Deploy Dividend module
      console.log("Deploying Dividend module...");
      const DividendCheckpoint = await ethers.getContractFactory("DividendCheckpoint");
      const dividend = await DividendCheckpoint.deploy(tokenAddress);
      await dividend.deployed();
      console.log(`Dividend module deployed to: ${dividend.address}`);
      
      // Configure Dividend module
      console.log("Configuring Dividend module...");
      await dividend.setWallet(deployer.address);
      await dividend.addAgent(deployer.address);
      console.log("Dividend module configured");
      
      // Deploy Voting module
      console.log("Deploying Voting module...");
      const WeightedVoteCheckpoint = await ethers.getContractFactory("WeightedVoteCheckpoint");
      const voting = await WeightedVoteCheckpoint.deploy(tokenAddress);
      await voting.deployed();
      console.log(`Voting module deployed to: ${voting.address}`);
      
      // Configure Voting module
      console.log("Configuring Voting module...");
      await voting.setDefaultExemptedVoters([deployer.address]);
      await voting.addAgent(deployer.address);
      console.log("Voting module configured");
      
      console.log("\n✅ Corporate Action Modules Deployment Complete!");
      console.log("=======================");
      console.log(`Dividend Module: ${dividend.address}`);
      console.log(`Voting Module: ${voting.address}`);
    } else {
      console.log("\nCorporate action modules deployment skipped.");
    }
    
    console.log("\n✅ Token Deployment Complete!");
    console.log("=======================");
    console.log(`Token Name: ${tokenName}`);
    console.log(`Token Symbol: ${tokenSymbol}`);
    console.log(`Token Address: ${token.address}`);
    console.log(`Token Identity: ${tokenOnchainId}`);
    console.log(`Identity Registry: ${irAddress}`);
    console.log(`Compliance Address: ${complianceAddress}`);
    
    console.log("\nNext Steps:");
    console.log("1. Register verified investors in the Identity Registry");
    console.log("2. Use the check-verification.js script to verify investor status");
    console.log("3. Use the Compliance contract to add lockup periods if needed");
    console.log("4. Only verified investors will be able to send and receive tokens");
    if (deployActions.toLowerCase() === 'y') {
      console.log("5. Use the Dividend module to distribute payments to token holders");
      console.log("6. Use the Voting module to create governance ballots for token holders");
    }
    
  } catch (error) {
    console.error("Deployment failed:", error);
    if (error.error) {
      console.error("Error details:", error.error);
    }
  } finally {
    rl.close();
  }
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });