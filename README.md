# UShares Protocol

## Overview

UShares is a cross-chain yield protocol that enables users to deposit USDC into any ERC4626-compliant vault across different EVM chains using Circle's CCTP (Cross-Chain Transfer Protocol) and Chainlink's CCIP (Cross-Chain Interoperability Protocol).

For a detailed system architecture, please see the [ARCHITECTURE.md](ARCHITECTURE.md) document.

## Features

- **Cross-Chain Deposits**: Deposit USDC into any ERC4626 vault across different EVM chains
- **Seamless Bridging**: Utilizes Circle's CCTP for USDC transfers and Chainlink's CCIP for data messaging
- **Yield Generation**: Access to various yield-generating strategies through ERC4626 vaults
- **Multi-Chain Support**: Works across all CCTP and CCIP supported EVM chains
- **User-Friendly Interface**: Complete web interface for wallet management, deposits, and portfolio tracking
- **On/Off Ramp Integration**: Built-in USDC purchase and selling capabilities
- **Real-time Tracking**: Subgraph-based analytics and position tracking

## Architecture

### Smart Contracts

- **UShares**: Main protocol contract handling deposits, withdrawals, and cross-chain operations
- **USharesToken**: ERC677 token representing user's share in the protocol
- **VaultRegistry**: Manages and validates ERC4626 vaults across chains
- **PositionManager**: Tracks user positions across different chains and vaults
- **CCTPAdapter**: Handles Circle's CCTP integration for USDC transfers

### Backend

- Transaction monitoring and validation
- Cross-chain message handling
- User position management
- Vault data aggregation
- Circle CCTP API integration
- Chainlink CCIP integration

### Frontend

- Wallet integration and management
- USDC on/off ramp interface
- Vault discovery and filtering
- User dashboard with portfolio tracking
- Cross-chain position management
- Yield analytics

### Subgraph

- Real-time protocol analytics
- User position tracking
- Vault performance metrics
- Cross-chain operation monitoring
- Transaction history

## Implementation Status

### Smart Contracts (Partially Complete)

#### ✅ Done:
- Basic contract structure with CCTP integration
- UShares token implementation with burn/mint capabilities
- Vault registry system
- Position management system
- Basic cross-chain messaging structure
- Fee management system
- Basic security features (roles, pausing)

#### 🔄 In Progress/Needs Review:
- CCTP message handling and validation
- Cross-chain position tracking
- Vault integration with ERC4626
- Fee calculation and distribution

#### ❌ To Do:
- Complete CCTP message handling
- Implement proper attestation verification
- Add emergency withdrawal mechanisms
- Add more comprehensive error handling
- Implement proper token approval mechanisms
- Add more security features (rate limiting, circuit breakers)

### Backend Requirements

#### ❌ To Do:
- Create API endpoints for:
  - Transaction monitoring
  - Cross-chain message tracking
  - User position management
  - Vault data aggregation
- Implement Circle CCTP API integration
- Implement Chainlink CCIP integration
- Create transaction monitoring system
- Implement retry mechanisms for failed transactions
- Create alerting system for failed operations
- Implement proper logging and monitoring
- Create admin dashboard for protocol management

### Frontend Requirements

#### ❌ To Do:
- Wallet Integration:
  - Wallet connection
  - Wallet creation system
  - Multi-chain wallet management
- On/Off Ramp:
  - USDC purchase integration
  - USDC selling integration
  - Payment method integration
  - KYC/AML integration if needed
- Vault Interface:
  - Vault listing page with filters
  - Vault details page
  - Deposit/withdrawal interface
  - Yield tracking
  - TVL display
  - Historical performance
- User Dashboard:
  - Portfolio overview
  - Cross-chain position tracking
  - Yield earnings
  - Transaction history
  - Pending operations
  - Chain-specific views

### Subgraph Requirements

#### ❌ To Do:
- Create subgraph schema for:
  - Deposits
  - Withdrawals
  - Vaults
  - User positions
  - Cross-chain operations
  - Transaction history
- Implement subgraph handlers for:
  - Deposit events
  - Withdrawal events
  - Vault updates
  - Position changes
  - Cross-chain messages
- Create queries for:
  - User portfolio
  - Vault statistics
  - Protocol metrics
  - Cross-chain analytics

### Testing Requirements

#### ❌ To Do:
- Smart Contract Tests:
  - Unit tests
  - Integration tests
  - Cross-chain tests
  - Security tests
  - Gas optimization tests
- Frontend Tests:
  - Component tests
  - Integration tests
  - E2E tests
  - Performance tests
- Backend Tests:
  - API tests
  - Integration tests
  - Load tests
  - Security tests

### Documentation Requirements

#### ❌ To Do:
- Technical Documentation:
  - Architecture overview
  - Smart contract documentation
  - API documentation
  - Integration guides
- User Documentation:
  - User guides
  - FAQ
  - Troubleshooting guides
  - Security best practices

### Security Requirements

#### ❌ To Do:
- Smart Contract Security:
  - Audit preparation
  - Bug bounty program
  - Security monitoring
  - Emergency response plan
- Frontend Security:
  - Input validation
  - XSS prevention
  - CSRF protection
  - Rate limiting
- Backend Security:
  - API security
  - Data encryption
  - Access control
  - Monitoring and alerting

## Next Steps Priority

1. Complete the core smart contract functionality:
   - Finish CCTP message handling
   - Implement proper attestation verification
   - Complete vault integration
2. Set up basic backend infrastructure:
   - Create basic API structure
   - Implement Circle CCTP integration
   - Set up monitoring system
3. Develop initial frontend:
   - Basic wallet integration
   - Simple deposit/withdrawal interface
   - Basic vault listing
4. Create subgraph:
   - Basic schema
   - Core event handlers
   - Essential queries

## Flow

### Deposit Flow

1. User connects wallet and selects a vault on any supported chain
2. User deposits USDC into the protocol
3. Protocol burns USDC and sends cross-chain message
4. On destination chain:
   - USDC is minted
   - Funds are deposited into selected vault
   - Receipt tokens are stored
5. On source chain:
   - uShares are minted to
   - Position is recorded

### Withdrawal Flow

1. User initiates withdrawal of uShares
2. Protocol burns uShares and sends cross-chain message
3. On destination chain:
   - Receipt tokens are redeemed
   - USDC is burned
4. On source chain:
   - USDC is minted to user
   - Position is closed

## Security

- Role-based access control
- Emergency pause functionality
- Rate limiting
- Comprehensive audit coverage
- Bug bounty program

## Development

### Prerequisites

- Foundry
- Node.js v16+
- Solidity v0.8.28+
- Circle CCTP API Key
- Chainlink CCIP API Key

### Setup

1. Clone the repository:
```bash
git clone https://github.com/fepvenancio/uShares.git
cd uShares
```

2. Install dependencies:
```bash
forge install
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Compile contracts:
```bash
forge build
```

5. Run tests:
```bash
forge test
```

### Testing

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/USharesToken.t.sol

# Run with coverage
forge coverage

# Run with verbosity
forge test -vvv
```

### Deployment

```bash
# Set environment variables
cp .env.example .env
# Edit .env with your values

# Deploy contracts
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast

# Deploy to specific network
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Circle for CCTP
- Chainlink for CCIP
- OpenZeppelin for smart contract libraries
- Solady for gas-optimized contracts
