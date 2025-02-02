// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ICCTP} from "../../src/interfaces/ICCTP.sol";

contract MockCCTP is ICCTP {
    // Events to match TokenMessenger events
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

    // State variables
    mapping(bytes32 => bool) public messages;
    mapping(bytes32 => bool) public verifiedMessages;
    uint64 private nonce;

    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external {
        require(amount > 0, "Amount must be nonzero");
        require(mintRecipient != bytes32(0), "Mint recipient must be nonzero");
        require(burnToken != address(0), "Invalid token");

        // Increment nonce for unique message ID
        nonce++;

        bytes32 messageHash = keccak256(
            abi.encode(amount, destinationDomain, mintRecipient, nonce)
        );
        messages[messageHash] = true;

        // Emit event matching Circle's TokenMessenger
        emit DepositForBurn(
            nonce,
            burnToken,
            amount,
            msg.sender,
            mintRecipient,
            destinationDomain,
            bytes32(0), // Mock destination messenger
            bytes32(0) // No specific caller required
        );
    }

    function receiveMessage(
        bytes memory message,
        bytes memory attestation
    ) external override returns (bool) {
        bytes32 messageHash = keccak256(message);
        require(verifiedMessages[messageHash], "Message not verified");
        
        // Parse message to emit MintAndWithdraw event
        (address recipient, uint256 amount, address token) = abi.decode(
            message,
            (address, uint256, address)
        );
        
        emit MintAndWithdraw(recipient, amount, token);
        
        messages[messageHash] = true;
        return true;
    }

    function verifyMessageHash(
        bytes memory message,
        bytes memory attestation
    ) external view override returns (bool) {
        bytes32 messageHash = keccak256(message);
        return verifiedMessages[messageHash];
    }
} 