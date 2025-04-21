// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title CircleDomains
 * @notice Constants for Circle's CCTP domain IDs
 * @dev Reference: https://developers.circle.com/stablecoins/docs/supported-domains
 */
library CircleDomains {
    uint32 public constant ETHEREUM = 0;
    uint32 public constant OPTIMISM = 2;
    uint32 public constant ARBITRUM = 3;
    uint32 public constant SOLANA = 5;
    uint32 public constant BASE = 6;
    uint32 public constant POLYGON = 7;
    uint32 public constant AVALANCHE = 1;
}
