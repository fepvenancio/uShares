// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {Constants} from '../helpers/Constants.sol';
import {DataTypes} from '../../types/DataTypes.sol';
import {ACLManager} from '../configuration/ACLManager.sol';

/**
 * @title Storage
 * @author filipeVenancio
 * @notice Storage of the route context for the modules
 */
contract Storage {
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

  // ACL MANAGER ADDRESS
  address internal _aclManager;
  // WALLET REGISTRY
  address internal _walletRegistry;
  // ALLOWED CONTROLLER
  address internal _allowedControllers;
  // ORACLE ADDRESS
  address internal _reserveOracle;
  // SIGNED ADDRESS
  address internal _signer;
  // UTOKEN Vault
  address internal _uShares;
  /// @dev contract that
  address internal _safeERC1155;
  /////////////////////////////////////////
  //  Signature Logic
  /////////////////////////////////////////
  mapping(address => uint256) internal _signNonce;

  /////////////////////////////////////////
  //  Allowed NFTS
  /////////////////////////////////////////

  mapping(address => Constants.ReserveType) internal _allowedVaults;

  /////////////////////////////////////////
  //  Allowed addresses
  /////////////////////////////////////////

  // Mapping of markets adapter allowed
  mapping(address => uint256) internal _allowedMarketAdapter; // address adapter true/false

  /////////////////////////////////////////
  //  Data Structs
  /////////////////////////////////////////

  mapping(bytes32 => DataTypes.Loan) internal _loans;
  mapping(bytes32 => DataTypes.Order) internal _orders;

  /////////////////////////////////////////
}