// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { ITokenMinter } from "./ITokenMinter.sol";

interface ITokenMessenger {
    /// @notice Emitted when a DepositForBurn message is sent
    /// @param nonce Unique nonce reserved by message
    /// @param burnToken Address of token burnt on source domain
    /// @param amount Deposit amount
    /// @param depositor Address where deposit is transferred from
    /// @param mintRecipient Address receiving minted tokens on destination domain as bytes32
    /// @param destinationDomain Destination domain
    /// @param destinationTokenMessenger Address of TokenMessenger on destination domain as bytes32
    /// @param destinationCaller Authorized caller as bytes32 of receiveMessage() on destination domain,
    /// if not equal to bytes32(0). If equal to bytes32(0), any address can call receiveMessage().
    event DepositForBurn(
        uint64 indexed nonce,
        address indexed burnToken,
        uint256 amount,
        address indexed depositor,
        bytes32 mintRecipient,
        uint32 destinationDomain,
        bytes32 destinationTokenMessenger,
        bytes32 destinationCaller
    );

    /// @notice Burns the tokens on the source side to produce a nonce through
    /// Circles Cross Chain Transfer Protocol.
    /// @param amount Amount of tokens to deposit and burn.
    /// @param destinationDomain Destination domain identifier.
    /// @param mintRecipient Address of mint recipient on destination domain.
    /// @param burnToken Address of contract to burn deposited tokens, on local domain.
    /// @param destinationCaller Caller on the destination domain, as bytes32.
    /// @return nonce The unique nonce used in unlocking the funds on the destination chain.
    /// @dev emits DepositForBurn
    function depositForBurnWithCaller(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller
    )
        external
        returns (uint64 nonce);

    /// Returns the version of the message body format.
    /// @dev immutable
    function messageBodyVersion() external view returns (uint32);

    /// Returns local Message Transmitter responsible for sending and receiving messages
    /// to/from remote domainsmessage transmitter for this token messenger.
    /// @dev immutable
    function localMessageTransmitter() external view returns (address);

    /**
     * @notice Gets the local minter contract
     * @return The local minter contract
     */
    function localMinter() external view returns (ITokenMinter);
}
