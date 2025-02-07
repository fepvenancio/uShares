// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ICCTP {
    // Events
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

    // Core functions
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (uint64 nonce);

    function depositForBurnWithCaller(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller
    ) external returns (uint64 nonce);

    // Message handling
    function receiveMessage(
        uint32 remoteDomain,
        bytes32 sender,
        bytes calldata messageBody
    ) external returns (bool);

    // Remote TokenMessenger management
    function addRemoteTokenMessenger(uint32 domain, bytes32 tokenMessenger) external;
    function removeRemoteTokenMessenger(uint32 domain) external;

    // Local minter management
    function setLocalMinter(address minter) external;
    function removeLocalMinter() external;

    // View functions
    function messageTransmitter() external view returns (address);
    function messageBodyVersion() external view returns (uint32);
    function localMinter() external view returns (address);
    function remoteTokenMessengers(uint32 domain) external view returns (bytes32);
}
