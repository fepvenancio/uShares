// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ITokenMinter} from "./ITokenMinter.sol";

interface ITokenMessenger {
    /**
     * @notice Deposits tokens for burning and cross-chain transfer
     * @param amount The amount of tokens to burn
     * @param destinationDomain The destination domain ID
     * @param mintRecipient The recipient address on the destination chain
     * @param burnToken The token to burn
     * @return The message bytes
     */
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (bytes32);

    /**
     * @notice Gets the local minter contract
     * @return The local minter contract
     */
    function localMinter() external view returns (ITokenMinter);
} 