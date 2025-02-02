// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ICCTP {
    function depositForBurn(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient, address burnToken)
        external;

    function receiveMessage(bytes memory message, bytes memory attestation) external returns (bool success);

    function verifyMessageHash(bytes memory message, bytes memory attestation) external view returns (bool);
}
