UShares Architecture

System Overview

The UShares protocol enables users to deposit USDC into ERC4626 vaults across multiple chains while maintaining unified position tracking and a seamless user experience. The architecture consists of four main components: smart contracts, backend services, frontend application, and data indexing.

┌──────────────────────────────────────────────────────────────────┐
│                           UShares Protocol                       │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
     ┌─────────────────┬─────────┴────────────┬──────────────────┐
     │                 │                      │                  │
┌────▼─────┐     ┌─────▼─────┐          ┌─────▼──────┐     ┌─────▼─────┐
│ Smart    │     │ Backend   │          │ Frontend   │     │ Data      │
│ Contracts│     │ Services  │          │ Application│     │ Indexing  │
└──────────┘     └───────────┘          └────────────┘     └───────────┘

Smart Contract Architecture

The smart contract layer is the foundation of UShares, designed with a modular architecture to handle cross-chain operations.
                       ┌────────────────┐
                       │     UShares    │◄─────┐
                       │  (Core Logic)  │      │
                       └────────┬───────┘      │
                                │              │
           ┌───────────┬────────┼─────────┬────┘
           │           │        │         │
 ┌─────────▼───┐ ┌─────▼────┐ ┌─▼──────┐ ┌▼──────────────┐
 │USharesToken │ │ Position │ │  Vault │ │  CCTPAdapter  │
 │  (ERC677)   │ │ Manager  │ │Registry│ │(Circle Bridge)│
 └─────────────┘ └──────────┘ └────────┘ └───────────────┘
          │          │        │                │
          └──────────┴────────┼────────────────┘
                              │
                 ┌────────────▼────────────┐
                 │  External Integrations  │
                 │  - ERC4626 Vaults       │
                 │  - CCTP/CCIP Networks   │
                 └─────────────────────────┘

Contract Components

UShares.sol (Core Contract)

Main entry point for user operations
Handles deposits, withdrawals, and cross-chain coordination
Manages fee collection and distribution
Connects all other contract modules


USharesToken.sol

ERC677-compatible token for position representation
Burn/mint capabilities for cross-chain operations
Built on Chainlink's standard for enhanced compatibility
Pausable functionality for emergency scenarios


PositionManager.sol

Tracks user positions across chains and vaults
Maintains position history and current balances
Handles cross-chain position reconciliation
Provides position validation and verification


VaultRegistry.sol

Manages approved ERC4626 vaults across chains
Verifies vault compliance and security
Stores vault metadata and performance metrics
Controls vault activation/deactivation


CCTPAdapter.sol

Handles Circle's CCTP integration
Manages USDC burning and minting between chains
Processes cross-chain messages
Handles attestation verification


Backend Architecture

The backend services handle cross-chain message monitoring, transaction verification, and API services for the frontend.
┌───────────────────────────────────────────────────────────┐
│                     Backend Services                      │
└───────────────────────────┬───────────────────────────────┘
                            │
     ┌────────────┬─────────┴──────────────┬──────────────────┐
     │            │                        │                  │
┌────▼────┐ ┌─────▼───────┐         ┌──────▼─────┐     ┌──────▼──────┐
│ Message │ │ Transaction │         │     API    │     │    Admin    │
│ Monitor │ │  Validator  │         │   Service  │     │   Services  │
└─────────┘ └─────────────┘         └────────────┘     └─────────────┘
     │            │                      │                  │
     └────────────┴──────────────────────┴──────────────────┘
                              │
                    ┌─────────▼───────────┐
                    │      Database       │
                    └─────────────────────┘

Backend Components

Message Monitor
Watches for CCTP and CCIP events across all supported chains
Detects message sending and receiving
Triggers appropriate backend responses for cross-chain events
Monitors for failed or delayed messages


Transaction Validator
Verifies cross-chain transactions are completed
Reconciles deposits and withdrawals across chains (CCIP should do this)
Handles retry logic for failed operations


API Service
Provides REST endpoints for frontend operations
Delivers vault and position data to users


Admin Services
Dashboard for protocol management
Monitoring tools for protocol health
Emergency response system
Fee and parameter management


Frontend Architecture

The frontend provides a user-friendly interface for interacting with the protocol across multiple chains.


┌─────────────────────────────────────────────────────────────┐
│                     Frontend Application                     │
└───────────────────────────┬─────────────────────────────────┘
                            │
     ┌────────────┬─────────┴────────────┬──────────────────┐
     │            │                      │                  │
┌────▼────┐ ┌─────▼─────┐         ┌──────▼─────┐     ┌──────▼─────┐
│ Wallet  │ │   Vault   │         │  Position  │     │On/Off Ramp │
│ Module  │ │  Explorer │         │ Dashboard  │     │  Module    │
└─────────┘ └───────────┘         └────────────┘     └────────────┘


Frontend Components

Wallet Module

Wallet connection integration (MetaMask, WalletConnect)
Wallet creation functionality
Multi-chain wallet management
Account management and security features


Vault Explorer

Discovery and filtering of available vaults
Detailed vault information pages
Performance metrics and comparison tools
Deposit and withdrawal interface


Position Dashboard

Portfolio overview across all chains
Yield tracking and visualization
Transaction history and pending operations
Performance analytics and reporting


On/Off Ramp Module

USDC purchase integration
Fiat withdrawal functionality
Payment method management
KYC/AML processes if required



Data Indexing Architecture

The data indexing layer provides real-time data aggregation and analysis using The Graph protocol.

┌─────────────────────────────────────────────────────────────┐
│                     Data Indexing Layer                     │
└───────────────────────────┬─────────────────────────────────┘
                            │
     ┌────────────┬─────────┴────────────┬──────────────────┐
     │            │                      │                  │
┌────▼────┐ ┌─────▼─────┐         ┌──────▼─────┐     ┌──────▼─────┐
│Chain-   │ │Position   │         │Vault       │     │Protocol    │
│Specific │ │Tracking   │         │Performance │     │Metrics     │
│Subgraphs│ │Subgraph   │         │Subgraph    │     │Subgraph    │
└─────────┘ └───────────┘         └────────────┘     └────────────┘

Data Indexing Components

Chain-Specific Subgraphs
Separate subgraphs for each supported blockchain
Indexes chain-specific contract events
Optimized for each chain's characteristics
Provides chain-specific analytics


Position Tracking Subgraph
Aggregates user positions across chains
Tracks position creation, updates, and closures
Links positions to vaults and chains
Enables cross-chain position analysis


Protocol Metrics Subgraph
Tracks protocol-wide statistics
Monitors total deposits, withdrawals, and TVL
Records fee collection and distribution
Provides growth and usage metrics


Cross-Chain Operation Flow
The most critical aspect of UShares is its cross-chain operation model, which follows these steps:
Deposit Flow

┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│         │     │         │     │         │     │         │     │         │
│  User   ├────►│ UShares ├────►│  CCTP   ├────►│ UShares ├────►│ ERC4626 │
│(Chain A)│     │(Chain A)│     │ Bridge  │     │(Chain B)│     │ Vault   │
│         │     │         │     │         │     │         │     │(Chain B)│
└─────────┘     └─────────┘     └─────────┘     └─────────┘     └─────────┘
                     │                               │
                     ▼                               ▼
               ┌─────────┐                     ┌─────────┐
               │Position │                     │Position │
               │Manager  │                     │Manager  │
               │(Chain A)│                     │(Chain B)│
               └─────────┘                     └─────────┘

User initiates deposit with USDC on Chain A
UShares contract on Chain A:

Receives USDC
Records pending deposit
Approves USDC for CCTP
Burns USDC via CCTP with message

CCTP mints USDC on Chain B with message
UShares contract on Chain B:

Verifies message
Deposits USDC into target vault
Receives vault shares
Updates position via Position Manager

Position Manager on Chain B records position 
Position Manager on Chain A is updated (via CCIP or backend)
UShares Token is minted to user on Chain A

Withdrawal Flow
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│         │     │         │     │         │     │         │     │         │
│  User   ├────►│ UShares ├────►│  CCIP   ├────►│ UShares ├────►│ERC4626  │
│(Chain A)│     │(Chain A)│     │ Bridge  │     │(Chain B)│     │ Vault   │
│         │     │         │     │         │     │         │     │(Chain B)│
└─────────┘     └─────────┘     └─────────┘     └─────────┘     └─────────┘
                     │                              │               │
                     ▼                              ▼               │
               ┌─────────┐                     ┌─────────┐          │
               │UShares  │                     │Position │          │
               │Token    │                     │Manager  │          │
               │(Burn)   │                     │(Chain B)│          │
               └─────────┘                     └─────────┘          │
                                                    │               │
                                                    ▼               ▼
                                               ┌─────────┐     ┌──────────┐
                                               │  CCTP   │     │ USDC     │
                                               │ Bridge  │     │(Withdraw)│
                                               └─────────┘     └──────────┘
                                                    │
                                                    ▼
                                               ┌─────────┐
                                               │  User   │
                                               │ Wallet  │
                                               │(Chain A)│
                                               └─────────┘

User initiates withdrawal on Chain A
UShares contract on Chain A:

Burns UShares tokens
Records pending withdrawal
Sends cross-chain message via CCIP

UShares contract on Chain B:

Receives message
Withdraws shares from vault
Receives USDC
Updates position via Position Manager

Position Manager on Chain B updates position
USDC is burned via CCTP with message
CCTP mints USDC on Chain A
UShares contract on Chain A transfers USDC to user

Security Architecture

The security architecture is layered to protect the protocol at multiple levels:

┌─────────────────────────────────────────────────────────────┐
│                     Security Architecture                   │
└───────────────────────────┬─────────────────────────────────┘
                            │
     ┌────────────┬─────────┴────────────┬──────────────────┐
     │            │                      │                  │
┌────▼────┐ ┌─────▼─────┐         ┌──────▼─────┐     ┌──────▼─────┐
│Contract │ │Operation  │         │Access      │     │Emergency   │
│Security │ │Validation │         │Control     │     │Response    │
└─────────┘ └───────────┘         └────────────┘     └────────────┘

Security Components

Contract Security

Role-based access control
pause functions
Timeout mechanisms for pending operations
Validated external calls


Operation Validation

Slippage protection
Rate limiting
Attestation verification
Cross-chain consistency checks


Access Control

Admin role management
Handler role for cross-chain operations
Backend service authentication

Emergency Response

Emergency withdrawal functionality
Alert system for suspicious activities
