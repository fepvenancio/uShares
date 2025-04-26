// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IRolesManager } from "../../interfaces/IRolesManager.sol";
import { Constants } from "../core/Constants.sol";
import { Errors } from "../core/Errors.sol";
import { Base } from "./Base.sol";

/**
 * @title BaseModule
 * @notice Base logic on each module
 * @author filipeVenancio
 */
contract BaseModule is Base {
    // public accessors common to all modules
    uint256 public immutable moduleId;
    bytes32 public immutable moduleVersion;

    constructor(uint256 moduleId_, bytes32 moduleVersion_) {
        moduleId = moduleId_;
        moduleVersion = moduleVersion_;
    }

    /**
     * @dev Modifier that checks if the sender has Protocol Admin ROLE
     */
    modifier onlyAdmin() {
        if (!IRolesManager(_rolesManager).isProtocolAdmin(unpackTrailingParamMsgSender())) {
            revert Errors.ProtocolAccessDenied();
        }
        _;
    }

    /**
     * @dev Modifier that checks if the sender has Governance ROLE
     */
    modifier onlyGovernance() {
        // We can create a new role for that
        if (!IRolesManager(_rolesManager).isGovernanceAdmin(unpackTrailingParamMsgSender())) {
            revert Errors.GovernanceAccessDenied();
        }
        _;
    }

    /**
     * @dev Modifier that checks if the sender has Emergency ROLE
     */
    modifier onlyEmergency() {
        if (!IRolesManager(_rolesManager).isEmergencyAdmin(unpackTrailingParamMsgSender())) {
            revert Errors.EmergencyAccessDenied();
        }
        _;
    }

    /**
     * @dev Modifier that checks if the sender has Handler ROLE
     */
    modifier onlyHandler() {
        if (!IRolesManager(_rolesManager).isHandler(unpackTrailingParamMsgSender())) {
            revert Errors.HandlerAccessDenied();
        }
        _;
    }

    /**
     * @dev Modifier that checks if the sender has Registry ROLE
     */
    modifier onlyRegistry() {
        if (!IRolesManager(_rolesManager).isRegistry(unpackTrailingParamMsgSender())) {
            revert Errors.RegistryAccessDenied();
        }
        _;
    }

    /**
     * @dev Modifier that checks if the sender has Bridge ROLE
     */
    modifier onlyBridge() {
        if (!IRolesManager(_rolesManager).isBridge(unpackTrailingParamMsgSender())) {
            revert Errors.BridgeAccessDenied();
        }
        _;
    }

    /**
     * @dev Modifier that checks if the sender has Minter ROLE
     */
    modifier onlyMinter() {
        if (!IRolesManager(_rolesManager).isMinter(unpackTrailingParamMsgSender())) {
            revert Errors.MinterAccessDenied();
        }
        _;
    }

    /**
     * @dev Due we are using the router we need to do this thing in order to extract the real sender, by default
     * msg.sender is the router
     */
    function unpackTrailingParamMsgSender() internal pure returns (address msgSender) {
        /// @solidity memory-safe-assembly
        assembly {
            msgSender := shr(96, calldataload(sub(calldatasize(), 40)))
        }
    }

    function unpackTrailingParams() internal pure returns (address msgSender, address proxyAddr) {
        /// @solidity memory-safe-assembly
        assembly {
            msgSender := shr(96, calldataload(sub(calldatasize(), 40)))
            proxyAddr := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }

    // Emit logs via proxies
    function emitViaProxy_Transfer(address proxyAddr, address from, address to, uint256 value) internal FREEMEM {
        (bool success,) = proxyAddr.call(
            abi.encodePacked(
                uint8(3),
                keccak256(bytes("Transfer(address,address,uint256)")),
                bytes32(uint256(uint160(from))),
                bytes32(uint256(uint160(to))),
                value
            )
        );
        if (!success) revert Errors.LogProxyFail();
    }

    function emitViaProxy_Approval(address proxyAddr, address owner, address spender, uint256 value) internal FREEMEM {
        (bool success,) = proxyAddr.call(
            abi.encodePacked(
                uint8(3),
                keccak256(bytes("Approval(address,address,uint256)")),
                bytes32(uint256(uint160(owner))),
                bytes32(uint256(uint160(spender))),
                value
            )
        );
        if (!success) revert Errors.LogProxyFail();
    }
}
