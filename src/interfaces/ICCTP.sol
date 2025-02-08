// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title ICCTP
 * @notice Interface for Circle's Cross-Chain Transfer Protocol (CCTP)
 * @dev Based on Circle's TokenMessenger contract
 */
interface ICCTP {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

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

    event MintAndWithdraw(
        address indexed mintRecipient,
        uint256 amount,
        address indexed mintToken
    );

    event RemoteTokenMessengerAdded(uint32 domain, bytes32 tokenMessenger);
    event RemoteTokenMessengerRemoved(uint32 domain, bytes32 tokenMessenger);
    event LocalMinterAdded(address localMinter);
    event LocalMinterRemoved(address localMinter);

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Burns tokens and initiates a CCTP transfer
     * @param amount The amount of tokens to burn
     * @param destinationDomain The destination domain (chain) ID
     * @param mintRecipient The recipient of the minted tokens on the destination chain
     * @param burnToken The token to burn
     * @return nonce The unique identifier for this transfer
     */
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (uint64 nonce);

    /**
     * @notice Burns tokens and initiates a CCTP transfer with a specified caller on the destination chain
     * @param amount The amount of tokens to burn
     * @param destinationDomain The destination domain (chain) ID
     * @param mintRecipient The recipient of the minted tokens on the destination chain
     * @param burnToken The token to burn
     * @param destinationCaller The allowed caller of receiveMessage on destination domain
     * @return nonce The unique identifier for this transfer
     */
    function depositForBurnWithCaller(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller
    ) external returns (uint64 nonce);

    /**
     * @notice Receives and processes a CCTP message
     * @param sourceDomain The domain (chain) where the message originated
     * @param sender The address that sent the message on the source chain
     * @param messageBody The encoded message data
     * @return success Whether the message was processed successfully
     */
    function receiveMessage(
        uint32 sourceDomain,
        bytes32 sender,
        bytes calldata messageBody
    ) external returns (bool success);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the message transmitter contract address
    function messageTransmitter() external view returns (address);

    /// @notice Returns the current message body version
    function messageBodyVersion() external view returns (uint32);

    /// @notice Returns the local minter contract address
    function localMinter() external view returns (address);

    /// @notice Returns the token messenger address for a given domain
    function remoteTokenMessengers(uint32 domain) external view returns (bytes32);

    // Remote TokenMessenger management
    function addRemoteTokenMessenger(uint32 domain, bytes32 tokenMessenger) external;
    function removeRemoteTokenMessenger(uint32 domain) external;

    // Local minter management
    function setLocalMinter(address minter) external;
    function removeLocalMinter() external;
}
