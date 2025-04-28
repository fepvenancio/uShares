// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Errors } from "../core/Errors.sol";

/**
 * @title KeyLogic
 * @notice Library for handling position and vault keys
 */
library KeyLogic {
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
    function getPositionKey(
        address owner,
        uint32 sourceChain,
        uint32 destinationChain,
        address destinationVault
    )
        internal
        pure
        returns (bytes32)
    {
        Errors.verifyAddress(owner);
        Errors.verifyNumber(sourceChain);
        Errors.verifyNumber(destinationChain);
        Errors.verifyAddress(destinationVault);

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
        Errors.verifyNumber(chainId);
        Errors.verifyAddress(vault);

        return keccak256(abi.encode(chainId, vault));
    }

    /*//////////////////////////////////////////////////////////////
                            KEY VALIDATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates if a position key matches the data provided
     * @dev Compares the provided key with the generated key
     * @param keyToValidate Key to validate
     * @param owner Position owner address
     * @param sourceChain Source chain ID
     * @param destinationChain Destination chain ID
     * @param destinationVault Destination vault address
     * @return bool True if key is valid
     */
    function isValidPositionKey(
        bytes32 keyToValidate,
        address owner,
        uint32 sourceChain,
        uint32 destinationChain,
        address destinationVault
    )
        internal
        pure
        returns (bool)
    {
        bytes32 key = getPositionKey(owner, sourceChain, destinationChain, destinationVault);
        return keyToValidate == key;
    }

    /**
     * @notice Validates if a vault key matches the data provided
     * @dev Currently only checks for non-zero value
     * @param key Key to validate
     * @param chainId Chain ID where vault exists
     * @param vault Vault address
     * @return bool True if key is valid
     */
    function isValidVaultKey(bytes32 key, uint32 chainId, address vault) internal pure returns (bool) {
        bytes32 expectedKey = getVaultKey(chainId, vault);
        return key == expectedKey;
    }
}
