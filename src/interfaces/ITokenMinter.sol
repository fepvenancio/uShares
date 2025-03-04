// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ITokenMinter {
    /**
     * @notice Gets the burn limit per message for a token
     * @param token The token address
     * @return The burn limit
     */
    function burnLimitsPerMessage(address token) external view returns (uint256);
} 