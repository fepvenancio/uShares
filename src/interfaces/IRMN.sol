// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IRMN
 * @notice Interface for Router Message Network proxy
 */
interface IRMN {
    /**
     * @notice Check if an address is cursed
     * @param addr The address to check
     * @return bool True if the address is cursed
     */
    function isCursed(address addr) external view returns (bool);

    /**
     * @notice Check if a message has been processed
     * @param messageId The message ID to check
     * @return bool True if the message has been processed
     */
    function isMessageProcessed(bytes32 messageId) external view returns (bool);

    /**
     * @notice Mark a message as processed
     * @param messageId The message ID to mark
     */
    function markMessageAsProcessed(bytes32 messageId) external;
} 