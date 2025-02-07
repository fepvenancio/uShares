// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ICCTP} from "../../src/interfaces/ICCTP.sol";

contract MockCCTP is ICCTP {
    address public immutable token;
    uint32 public immutable domainId;
    address private _messageTransmitter;
    address private _localMinter;
    mapping(uint32 => bytes32) private _remoteTokenMessengers;
    mapping(address => uint256) public minterAllowances;

    constructor(address _token, uint32 _domainId) {
        token = _token;
        domainId = _domainId;
        _messageTransmitter = msg.sender;
    }

    function setMinterAllowance(address minter, uint256 amount) external {
        minterAllowances[minter] = amount;
    }

    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnTokenAddr
    ) external override returns (uint64) {
        return 1;
    }

    function depositForBurnWithCaller(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnTokenAddr,
        bytes32 destinationCaller
    ) external override returns (uint64) {
        return 1;
    }

    function receiveMessage(
        uint32 sourceDomain,
        bytes32 sender,
        bytes calldata messageBody
    ) external override returns (bool) {
        return true;
    }

    function addRemoteTokenMessenger(uint32 domain, bytes32 tokenMessenger) external override {
        _remoteTokenMessengers[domain] = tokenMessenger;
    }

    function removeRemoteTokenMessenger(uint32 domain) external override {
        delete _remoteTokenMessengers[domain];
    }

    function setLocalMinter(address minter) external override {
        _localMinter = minter;
    }

    function removeLocalMinter() external override {
        _localMinter = address(0);
    }

    function messageTransmitter() external view override returns (address) {
        return _messageTransmitter;
    }

    function messageBodyVersion() external pure override returns (uint32) {
        return 1;
    }

    function localMinter() external view override returns (address) {
        return _localMinter;
    }

    function remoteTokenMessengers(uint32 domain) external view override returns (bytes32) {
        return _remoteTokenMessengers[domain];
    }

    // Additional helper functions (not part of the interface)
    function getBurnToken() external view returns (address) {
        return token;
    }

    function getLocalDomain() external view returns (uint32) {
        return domainId;
    }
}
