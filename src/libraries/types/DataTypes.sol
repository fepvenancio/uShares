// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Constants } from "../core/Constants.sol";

/**
 * @title DataTypes
 * @notice Library containing data types used in the UShares protocol
 */
library DataTypes {
    /**
     * @notice Data structure for cross-chain deposits
     */
    struct CrossChainDeposit {
        address user;
        uint256 usdcAmount;
        uint32 destinationDomain;
        address targetVault;
        uint256 deadline;
        Constants.CrossChainStatus status;
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
        Constants.CrossChainStatus status;
        bool cctpCompleted;
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
