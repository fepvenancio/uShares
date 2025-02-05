// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Errors} from "./Errors.sol";

/// @title KeyManager
/// @notice Library for handling position and vault keys
library KeyManager {
    // Error definitions
    error InvalidKeyLength();
    error InvalidAddress();

    /// @notice Creates a unique key for a position
    /// @param owner Position owner
    /// @param sourceChain Source chain ID
    /// @param destinationChain Destination chain ID
    /// @param destinationVault Destination vault address
    /// @return bytes32 Unique position identifier
    function getPositionKey(address owner, uint32 sourceChain, uint32 destinationChain, address destinationVault)
        internal
        pure
        returns (bytes32)
    {
        if (owner == address(0)) revert InvalidAddress();
        if (sourceChain == 0) revert Errors.ZeroChainId();
        if (destinationChain == 0) revert Errors.ZeroChainId();
        if (destinationVault == address(0)) revert InvalidAddress();

        return keccak256(abi.encode(owner, sourceChain, destinationChain, destinationVault));
    }

    /// @notice Creates a unique key for a vault
    /// @param chainId Chain ID where vault exists
    /// @param vault Vault address
    /// @return bytes32 Unique vault identifier
    function getVaultKey(uint32 chainId, address vault) internal pure returns (bytes32) {
        if (chainId == 0) revert Errors.ZeroChainId();
        if (vault == address(0)) revert InvalidAddress();

        return keccak256(abi.encode(chainId, vault));
    }

    /// @notice Validates a position key format
    /// @param key Key to validate
    /// @return bool True if key is valid
    function isValidPositionKey(bytes32 key) internal pure returns (bool) {
        // Add validation logic based on your key structure
        return key != bytes32(0);
    }

    /// @notice Validates a vault key format
    /// @param key Key to validate
    /// @return bool True if key is valid
    function isValidVaultKey(bytes32 key) internal pure returns (bool) {
        // Add validation logic based on your key structure
        return key != bytes32(0);
    }
}
