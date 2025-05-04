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
    uint256 internal constant MODULEID__USHARES_TOKEN_REGISTRY = 3; // prettier-ignore
    uint256 internal constant MODULEID__CROSS_VAULT = 4; // prettier-ignore
    uint256 internal constant MODULEID__LOCAL_VAULT = 5; // prettier-ignore

    ////////////////////////////////////////////
    // CIRCLE DOMAIN IDS
    ////////////////////////////////////////////

    uint32 public constant ETHEREUM = 0; // prettier-ignore
    uint32 public constant AVALANCHE = 1; // prettier-ignore
    uint32 public constant OPTIMISM = 2; // prettier-ignore
    uint32 public constant ARBITRUM = 3; // prettier-ignore
    uint32 public constant NOBLE = 4; // prettier-ignore
    uint32 public constant SOLANA = 5; // prettier-ignore
    uint32 public constant BASE = 6; // prettier-ignore
    uint32 public constant POLYGON = 7; // prettier-ignore
    uint32 public constant SUI = 8; // prettier-ignore
    uint32 public constant APTOS = 9; // prettier-ignore
    uint32 public constant UNICHAIN = 10; // prettier-ignore

    ////////////////////////////////////////////
    // CONSTANT VARS
    ////////////////////////////////////////////

    uint256 public constant MAX_TIMEOUT = 1 days;
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MAX_FEE = 1000;

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
        Pending,
        Completed,
        Failed
    }
}
