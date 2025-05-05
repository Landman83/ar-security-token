# Token Minting Instructions

This document explains how to use the `MintTokens.s.sol` script to mint tokens to a specified address.

## Prerequisites

- You must have the token contract address where you want to mint tokens
- You must have the private key of an account with minting permissions (typically the token owner/deployer)

## Environment Variables

Set the following environment variables before running the script:

```bash
# Required
TOKEN_ADDRESS=0x... # Address of the deployed token contract
DEPLOYER_PRIVATE_KEY=0x... # Private key of the account with minting permissions
RPC_URL=https://... # RPC URL for the network

# Optional (will use defaults if not specified)
MINT_AMOUNT=1000 # Amount of tokens to mint (whole tokens, not with decimals)
RECIPIENT_ADDRESS=0x... # Address to receive the tokens (defaults to deployer if not specified)
TOKEN_DECIMALS=18 # Number of token decimals (defaults to 18 if not specified)
```

## Running the Script

To run the script, use the following command:

```bash
forge script script/MintTokens.s.sol \
--rpc-url $RPC_URL \
--private-key $DEPLOYER_PRIVATE_KEY \
--broadcast
```

For newer versions of Foundry, you might need to add `--legacy` flag:

```bash
forge script script/MintTokens.s.sol \
--rpc-url $RPC_URL \
--private-key $DEPLOYER_PRIVATE_KEY \
--broadcast \
--legacy
```

## Troubleshooting Common Issues

1. **Permission denied when minting**: Make sure the account you're using has minting permissions on the token contract.

2. **Transaction reverted**: Check that:
   - The token contract address is correct
   - The account has sufficient gas
   - The token allows minting (not paused)

3. **Zero tokens minted**: Verify the TOKEN_DECIMALS is set correctly.

4. **Script fails to execute**: Make sure all required environment variables are set correctly.

## Example .env File

```
# Network Configuration
RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/YOUR_API_KEY
DEPLOYER_ADDRESS=0x7587088e5b143Eff54A4015c30c9d297D26Cf525
DEPLOYER_PRIVATE_KEY=0x1ba3cf3a95ce7689245a1162d663e0bcb1c3f35dd7dd96b70b8439929235f822

# Minting Configuration
TOKEN_ADDRESS=0x123... # Replace with your deployed token address
MINT_AMOUNT=1000
RECIPIENT_ADDRESS=0x456... # Optional, will default to deployer if not set
TOKEN_DECIMALS=18
```