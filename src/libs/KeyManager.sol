// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Errors} from "./Errors.sol";

/**
 * @title KeyManager
 * @notice Library for handling position and vault keys
 * @dev Provides utilities for generating and validating unique identifiers for positions and vaults
 * @custom:security-contact security@ushares.com
 */
library KeyManager {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a key has an invalid length
    error InvalidKeyLength();

    /// @notice Thrown when an address parameter is invalid
    error InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                            KEY GENERATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a unique key for a position
     * @dev Combines owner, chains, and vault info into a unique identifier
     * @param owner Position owner address
     * @param sourceChain Source chain ID
     * @param destinationChain Destination chain ID
     * @param destinationVault Destination vault address
     * @return bytes32 Unique position identifier
     */
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

    /**
     * @notice Creates a unique key for a vault
     * @dev Combines chain ID and vault address into a unique identifier
     * @param chainId Chain ID where vault exists
     * @param vault Vault address
     * @return bytes32 Unique vault identifier
     */
    function getVaultKey(uint32 chainId, address vault) internal pure returns (bytes32) {
        if (chainId == 0) revert Errors.ZeroChainId();
        if (vault == address(0)) revert InvalidAddress();

        return keccak256(abi.encode(chainId, vault));
    }

    /*//////////////////////////////////////////////////////////////
                            KEY VALIDATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates a position key format
     * @dev Currently only checks for non-zero value
     * @param key Key to validate
     * @return bool True if key is valid
     */
    function isValidPositionKey(bytes32 key) internal pure returns (bool) {
        // Add validation logic based on your key structure
        return key != bytes32(0);
    }

    /**
     * @notice Validates a vault key format
     * @dev Currently only checks for non-zero value
     * @param key Key to validate
     * @return bool True if key is valid
     */
    function isValidVaultKey(bytes32 key) internal pure returns (bool) {
        // Add validation logic based on your key structure
        return key != bytes32(0);
    }
}
