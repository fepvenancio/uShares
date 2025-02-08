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
        uint96 totalShares;
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
} 