// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title ITypeAndVersion
 * @notice Interface for contracts that want to expose their type and version
 */
interface ITypeAndVersion {
    /**
     * @notice Get the type and version of the contract
     * @return The type and version string (e.g. "TokenPool 1.0.0")
     */
    function typeAndVersion() external pure returns (string memory);
} 