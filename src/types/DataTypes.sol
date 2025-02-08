// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title DataTypes
/// @notice Core data structures for the cross-chain vault protocol
library DataTypes {
    // Enums
    enum CrossChainStatus {
        Pending,
        CCTPCompleted,
        SharesIssued,
        Completed,
        Failed
    }

    // Cross-chain structures
    struct CrossChainDeposit {
        address user;
        uint256 usdcAmount;
        address sourceVault;
        address targetVault;
        uint32 destinationChain;
        uint256 vaultShares;
        uint256 uSharesMinted;
        bool cctpCompleted;
        bool sharesIssued;
        uint256 timestamp;
        uint256 minShares;
        uint256 deadline;
        CrossChainStatus status;
    }

    struct CrossChainWithdrawal {
        address user;
        uint256 uSharesAmount;
        address sourceVault;
        address targetVault;
        uint32 destinationChain;
        uint256 usdcAmount;
        bool cctpCompleted;
        bool sharesWithdrawn;
        uint256 timestamp;
        uint256 minUSDC;
        uint256 deadline;
        CrossChainStatus status;
    }

    // Vault structures
    struct VaultInfo {
        address vaultAddress;
        uint32 chainId;
        uint96 totalShares;
        uint64 lastUpdate;
        bool active;
    }

    // Position structures
    struct Position {
        address owner;
        uint32 sourceChain;
        uint32 destinationChain;
        address destinationVault;
        uint256 shares;
        bool active;
        uint256 timestamp;
    }

    // Message structures
    struct DepositParams {
        address user;
        uint32 sourceChain;
        uint32 destChain;
        uint256 vaultId;
        uint256 amount;
    }

    // CCT Standard structs
    struct LockOrBurnParams {
        address sender;
        uint256 amount;
        uint64 destinationChainSelector;
        address receiver;
        bytes32 depositId;
    }

    struct ReleaseOrMintParams {
        bytes32 depositId;
        address receiver;
        uint256 amount;
        uint64 sourceChainSelector;
    }
}
