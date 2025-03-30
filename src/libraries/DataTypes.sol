// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title DataTypes
 * @notice Library containing data types used in the UShares protocol
 */
library DataTypes {
    /**
     * @notice Data structure for vault information
     */
    struct VaultInfo {
        address vaultAddress;
        uint32 domain;
        uint64 lastUpdate;
        bool isActive;
    }

    /**
     * @notice Status of a cross-chain operation
     */
    enum CrossChainStatus {
        None,
        Pending,
        Completed,
        Failed
    }

    /**
     * @notice Data structure for cross-chain deposits
     */
    struct CrossChainDeposit {
        address user;
        uint256 usdcAmount;
        uint32 destinationDomain;
        address targetVault;
        uint256 deadline;
        CrossChainStatus status;
        bool cctpCompleted;
    }

    /**
     * @notice Data structure for cross-chain withdrawals
     */
    struct CrossChainWithdrawal {
        address user;
        uint256 usdcAmount;
        uint32 destinationDomain;
        address targetVault;
        uint256 deadline;
        CrossChainStatus status;
        bool cctpCompleted;
    }

    /**
     * @notice Struct containing position information
     * @param owner The owner of the position
     * @param sourceChain The chain ID where the position was created
     * @param destinationChain The chain ID where the vault exists
     * @param destinationVault The vault address on the destination chain
     * @param shares The number of shares in the position
     * @param active Whether the position is active
     * @param timestamp Last update timestamp
     */
    struct Position {
        address owner;
        uint32 sourceChain;
        uint32 destinationChain;
        address destinationVault;
        uint256 shares;
        bool active;
        uint64 timestamp;
    }

    struct PendingDeposit {
        address user;
        uint32 sourceChain;
        address vault;
        uint256 amount;
        uint256 minSharesExpected;
        uint64 timestamp;
    }

    struct PendingWithdrawal {
        address user;
        uint32 sourceChain;
        uint32 destinationChain;
        address vault;
        uint256 shares;
        uint256 minUsdcExpected;
        uint64 timestamp;
    }
} 