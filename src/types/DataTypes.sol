// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title DataTypes
/// @notice Core data structures for the cross-chain vault protocol
library DataTypes {
    // Vault information
    struct VaultInfo {
        address vaultAddress;    // ERC4626 vault contract
        uint32 chainId;         // Chain where vault exists
        uint96 totalShares;     // Total shares issued
        uint64 lastUpdate;      // Last update timestamp
        bool active;            // Vault status
    }

    // Deposit message structure
    struct DepositParams {
        address user;           // Original user address
        uint32 sourceChain;     // Origin chain
        uint32 destChain;       // Target chain
        uint256 vaultId;        // Target vault
        uint256 amount;         // USDC amount
    }
}
