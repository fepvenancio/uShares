# uShares Protocol

uShares is a cross-chain ERC4626 vault share tokenization protocol that enables users to access yield opportunities across different blockchains while maintaining their position on their source chain.

## Overview

uShares allows users to:
- Deposit USDC on a source chain
- Get exposure to ERC4626 vaults on destination chains
- Receive uShares tokens on the source chain representing their vault positions

### Core Value Proposition
- Access cross-chain yield opportunities without leaving source chain
- Single token (uShares) representing vault positions across chains
- Simplified user experience for cross-chain vault interactions

## Architecture

### Core Components

1. **USharesToken**
   - ERC20 token implementing CCT (Cross-Chain Token) standard
   - Manages deposit process and vault positions
   - Handles minting/burning of uShares tokens
   - Integrates with CCTP for USDC bridging

2. **VaultRegistry**
   - Maintains list of supported vaults
   - Tracks vault states and shares
   - Validates vault operations
   - Ensures vault security and compliance

3. **PositionManager**
   - Tracks user positions across chains
   - Manages vault share balances
   - Handles cross-chain state updates
   - Provides position validation

### Token Standards
- uShares Token: ERC20 compatible with CCT standard
- Decimals: 6 (matching USDC)
- Supported Assets: USDC (initially)

## Core Flows

### Deposit Flow
1. User initiates deposit with USDC on source chain
2. USDC is bridged via CCTP to destination chain
3. USDC is deposited into selected ERC4626 vault
4. uShares are minted on source chain 1:1 with vault shares

### Withdrawal Flow
1. User burns uShares on source chain
2. Corresponding vault shares are withdrawn
3. USDC is returned to user

### Cross-Chain Flow
1. Source chain burns/locks tokens
2. CCTP bridges USDC
3. Destination chain mints/releases tokens

## Security Features

### Access Control
- Role-based permissions system
- Admin functions protection
- Token pool authorization

### Cross-Chain Security
- Message verification
- CCTP attestation validation
- Duplicate message prevention

### Emergency Controls
- Pause functionality
- Admin recovery functions
- Deadline enforcement

## Installation

### Prerequisites
- Foundry
- Node.js >= 14
- Git

### Setup
```bash
# Clone the repository
git clone https://github.com/fepvenancio/uShares
cd uShares

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test
```

## Testing
```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/USharesToken.t.sol

# Run with verbosity
forge test -vv

# Run with gas reporting
forge test --gas-report
```

## Deployment

### Deployment Order
1. Deploy VaultRegistry
2. Deploy PositionManager
3. Deploy USharesToken
4. Configure contracts

### Configuration Steps
```solidity
// 1. Configure VaultRegistry
registry.registerVault(CHAIN_ID, VAULT_ADDRESS);

// 2. Configure PositionManager
positionManager.configureHandler(TOKEN_ADDRESS, true);

// 3. Configure USharesToken
token.setVaultRegistry(REGISTRY_ADDRESS);
token.configureMinter(POSITION_MANAGER, true);
token.configureBurner(POSITION_MANAGER, true);
```

## Contract Addresses

### Mainnet
- USharesToken: `TBD`
- VaultRegistry: `TBD`
- PositionManager: `TBD`

### Testnet
- USharesToken: `TBD`
- VaultRegistry: `TBD`
- PositionManager: `TBD`

## Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Security

### Audit Status
- Initial audit completed: `TBD`
- No critical vulnerabilities found
- Full audit report: `TBD`

### Bug Bounty
- Program details: `TBD`
- Scope: All smart contracts in `src/`
- Rewards: Up to `TBD` based on severity

## License

MIT License - see LICENSE file for details

## Contact

- Website: `TBD`
- Twitter: `TBD`
- Discord: `TBD`
- Email: `TBD`
