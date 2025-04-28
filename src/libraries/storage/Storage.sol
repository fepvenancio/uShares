// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import { Constants } from "../core/Constants.sol";
import { RolesManager } from "../core/RolesManager.sol";
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
    // ORACLE ADDRESS
    address internal _usdcOracle;
    // USDC Address
    address internal _usdc;
    // SIGNED ADDRESS
    address internal _signer;
    // ERC1155 to mint to users
    address internal _safeERC1155;

    /////////////////////////////////////////
    //  Signature Logic
    /////////////////////////////////////////
    mapping(address => uint256) internal _signNonce;

    /////////////////////////////////////////
    //  Allowed Vaults
    /////////////////////////////////////////

    /// @notice Mapping of vault key to vault info
    mapping(bytes32 => DataTypes.VaultInfo) public vaults;

    /// @notice Mapping of position keys to Position structs
    /// @dev Key format: keccak256(abi.encode(owner, sourceChain, destinationChain, destinationVault))
    mapping(bytes32 => DataTypes.Position) public positions;
}
