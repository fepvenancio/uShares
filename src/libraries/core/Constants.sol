// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

library Constants {
    ////////////////////////////////////////////
    // Reentrancy Guard for modules
    ////////////////////////////////////////////
    uint256 internal constant REENTRANCYLOCK__UNLOCKED = 0; // prettier-ignore
    uint256 internal constant REENTRANCYLOCK__LOCKED = 1; // prettier-ignore

    ////////////////////////////////////////////
    // Modules Configuration
    ////////////////////////////////////////////

    uint256 internal constant MAX_EXTERNAL_SINGLE_PROXY_MODULEID = 499_999; // prettier-ignore
    uint256 internal constant MAX_EXTERNAL_MODULEID = 999_999; // prettier-ignore

    ////////////////////////////////////////////
    // List Modules
    ////////////////////////////////////////////

    // Public single-proxy modules
    uint256 internal constant MODULEID__INSTALLER = 1; // prettier-ignore
    uint256 internal constant MODULEID__VAULT_REGISTRY = 2; // prettier-ignore
    uint256 internal constant MODULEID__POSITION_MANAGER = 3; // prettier-ignore
    uint256 internal constant MODULEID__MINTER = 4; // prettier-ignore

    ////////////////////////////////////////////
    // CIRCLE DOMAIN IDS
    ////////////////////////////////////////////

    uint32 public constant Ethereum = 0; // prettier-ignore
    uint32 public constant Avalanche = 1; // prettier-ignore
    uint32 public constant Optimism = 2; // prettier-ignore
    uint32 public constant Arbitrum = 3; // prettier-ignore
    uint32 public constant Noble = 4; // prettier-ignore
    uint32 public constant Solana = 5; // prettier-ignore
    uint32 public constant Base = 6; // prettier-ignore
    uint32 public constant Polygon = 7; // prettier-ignore
    uint32 public constant Sui = 8; // prettier-ignore
    uint32 public constant Aptos = 9; // prettier-ignore
    uint32 public constant Unichain = 10; // prettier-ignore

    ////////////////////////////////////////////
    // VAULT STATE
    ////////////////////////////////////////////

    /**
     * @notice Status of a vault
     */
    enum VaultState {
        STOPPED, // No supply
        FREEZED, // No supply, No withdraw
        ACTIVE // working as intended

    }

    ////////////////////////////////////////////
    // CROSS CHAIN OPERATION STATUS
    ////////////////////////////////////////////

    /**
     * @notice Status of a cross-chain operation
     */
    enum CrossChainStatus {
        None,
        Pending,
        Completed,
        Failed
    }
}
