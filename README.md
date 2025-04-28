# Security Token (AR-ST)

This repository contains a Solidity implementation of a security token system using attribute registry-based compliance.

## Architecture

- **SecurityToken**: The main token contract implementing ERC-20 compatible security token
- **ModularCompliance**: System to enforce transfer restrictions through compliance modules
- **VersionRegistry**: Central registry that manages contract implementations
- **SecurityTokenFactory**: Factory to deploy new token instances via proxies

### Key Components

- **Proxy Pattern**: System uses proxy contracts for upgradeability
- **Compliance Modules**: Pluggable modules like AccreditedInvestor and Lockup
- **Attribute Registry**: External registry for storing investor attributes

## Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js and npm (for JS scripts)

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd ar-st

# Install dependencies
forge install
```

### Configuration

Create a `.env` file based on `.env.example`:

```
# Deployment Configuration
DEPLOYER_ADDRESS=0x...
DEPLOYER_PRIVATE_KEY=0x...
CHAIN_ID=1
ATTRIBUTE_REGISTRY_ADDRESS=0x...

# Token Configuration
TOKEN_NAME="Security Token"
TOKEN_SYMBOL="STKN"
TOKEN_DECIMALS=18
```

## Development

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

## Deployment

The deployment scripts are organized into modular components to avoid contract size limitations:

1. `Deploy_Implementations.s.sol`: Deploys token and compliance implementations
2. `Deploy_Modules.s.sol`: Deploys compliance modules
3. `Deploy_Factory.s.sol`: Deploys security token factory using VersionRegistry
4. `DeployToken.s.sol`: Deploys an individual token
5. `DeployAll.s.sol`: Main script that orchestrates all deployments

### Deploy All Components

```bash
forge script script/DeployAll.s.sol --rpc-url $RPC_URL --broadcast
```

Or using the local node:

```bash
forge script script/DeployAll.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

### Deploy Individual Token

```bash
forge script script/DeployToken.s.sol --rpc-url $RPC_URL --broadcast
```

## Foundry Documentation

https://book.getfoundry.sh/

## License

This project is licensed under GPL-3.0.
