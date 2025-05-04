// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { DataTypes } from "../types/DataTypes.sol";

/**
 * @title Storage
 * @author UShares
 * @notice Storage of the route context for the modules
 */
abstract contract Storage {
    /////////////////////////////////////////
    //  Dispacher and Upgrades
    /////////////////////////////////////////

    mapping(uint256 => address) internal _moduleLookup; // moduleId => module implementation
    mapping(uint256 => address) internal _proxyLookup; // moduleId => proxy address (only for single-proxy modules)
    mapping(address => TrustedSenderInfo) internal _trustedSenders;

    struct TrustedSenderInfo {
        uint32 moduleId; // 0 = un-trusted
        address moduleImpl; // only non-zero for external single-proxy modules
    }

    /////////////////////////////////////////
    //  Configurations
    /////////////////////////////////////////

    // ROLES MANAGER ADDRESS
    address internal _rolesManager;
    // CHAINLINK PRICE FEED ADDRESS
    address internal _usdcChainlinkPriceFeed;
    // USDC ADDRESS
    address internal _usdc;
    // SIGNED ADDRESS
    address internal _signer;
    // PROTOCOL PAUSED
    bool internal _paused;

    // Protocol-wide fee configuration
    uint256 internal _protocolFee;
    address internal _feeCollector;
    mapping(uint32 => uint256) internal _chainFees;

    /////////////////////////////////////////
    //  Signature Logic
    /////////////////////////////////////////
    mapping(address => uint256) internal _signNonce;

    /////////////////////////////////////////
    //  ChainSelectors
    /////////////////////////////////////////

    // Chain ID => Chain Selector
    mapping(uint32 => uint64) internal _chainSelectors;

    // Chain ID => CrossVault Address
    mapping(uint32 => address) internal _crossVaultsAddresses;

    /////////////////////////////////////////
    //  Allowed Vaults
    /////////////////////////////////////////

    /// @notice Mapping of vault key to vault info
    mapping(address => bool) public vaults;

    mapping(bytes32 => DataTypes.PendingDeposit) public pendingDeposits;

    mapping(bytes32 => DataTypes.PendingWithdrawal) public pendingWithdrawals;

    /////////////////////////////////////////
    //  uShares Token Registry
    /////////////////////////////////////////

    // SAME CHAIN vault => uSharesToken
    mapping(address => address) public uSharesTokens;

    // CROSS CHAIN chainId => vault => uSharesToken
    mapping(uint32 => mapping(address => address)) public crossChainUSharesTokens;

    address[] public uSharesTokenAssetLists;
}
