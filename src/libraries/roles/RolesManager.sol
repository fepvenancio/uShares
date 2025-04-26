// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IRolesManager } from "../../interfaces/IRolesManager.sol";
import { Errors } from "../core/Errors.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

/**
 * @title RolesManager
 * @notice Roles Manager. Main contract for the roles management.
 * @author filipeVenancio
 */
contract RolesManager is OwnableRoles, IRolesManager {
    // @dev address of the USHARES PROTOCOL
    address public USHARES_PROTOCOL;

    uint256 public constant override USHARES_ADMIN_ROLE = _ROLE_0;
    uint256 public constant override PROTOCOL_ADMIN_ROLE = _ROLE_1;
    uint256 public constant override EMERGENCY_ADMIN_ROLE = _ROLE_2;
    uint256 public constant override GOVERNANCE_ADMIN_ROLE = _ROLE_3;
    uint256 public constant override HANDLER_ROLE = _ROLE_4;
    uint256 public constant override REGISTRY_ROLE = _ROLE_5;
    uint256 public constant override BRIDGE_ROLE = _ROLE_6;
    uint256 public constant override MINTER_ROLE = _ROLE_7;
    uint256 public constant override ROLES_MANAGER_ROLE = _ROLE_8;

    /**
     * @dev Constructor
     * @dev The RolesManager (rm) should be initialized at the addressesProvider beforehand
     * @param rmOwner address of the owner
     */
    constructor(address rmOwner) {
        Errors.verifyAddress(rmOwner);

        _initializeOwner(rmOwner);
        _grantRoles(rmOwner, ROLES_MANAGER_ROLE);
    }

    function setUSharesAdminRole(address admin) external onlyRoles(ROLES_MANAGER_ROLE) {
        _grantRoles(admin, USHARES_ADMIN_ROLE);
    }

    function setProtocol(address protocol) external onlyRoles(ROLES_MANAGER_ROLE) {
        Errors.verifyAddress(protocol);
        USHARES_PROTOCOL = protocol;
    }

    function isProtocol(address protocol) external view returns (bool) {
        return USHARES_PROTOCOL == protocol;
    }

    function addProtocolAdminRole(address protocolAdmin) external onlyRoles(ROLES_MANAGER_ROLE) {
        _grantRoles(protocolAdmin, PROTOCOL_ADMIN_ROLE);
    }

    function removeProtocolAdminRole(address protocolAdmin) external onlyRoles(ROLES_MANAGER_ROLE) {
        _removeRoles(protocolAdmin, PROTOCOL_ADMIN_ROLE);
    }

    function isProtocolAdmin(address protocolAdmin) external view returns (bool) {
        return hasAnyRole(protocolAdmin, PROTOCOL_ADMIN_ROLE);
    }

    function addEmergencyAdminRole(address emergencyAdmin) external onlyRoles(ROLES_MANAGER_ROLE) {
        _grantRoles(emergencyAdmin, EMERGENCY_ADMIN_ROLE);
    }

    function removeEmergencyAdminRole(address emergencyAdmin) external onlyRoles(ROLES_MANAGER_ROLE) {
        _removeRoles(emergencyAdmin, EMERGENCY_ADMIN_ROLE);
    }

    function isEmergencyAdmin(address emergencyAdmin) external view returns (bool) {
        return hasAnyRole(emergencyAdmin, EMERGENCY_ADMIN_ROLE);
    }

    function addGovernanceAdminRole(address governanceAdmin) external onlyRoles(ROLES_MANAGER_ROLE) {
        _grantRoles(governanceAdmin, GOVERNANCE_ADMIN_ROLE);
    }

    function removeGovernanceAdminRole(address governanceAdmin) external onlyRoles(ROLES_MANAGER_ROLE) {
        _removeRoles(governanceAdmin, GOVERNANCE_ADMIN_ROLE);
    }

    function isGovernanceAdmin(address governanceAdmin) external view returns (bool) {
        return hasAnyRole(governanceAdmin, GOVERNANCE_ADMIN_ROLE);
    }

    // handler role
    function addHandlerRole(address handler) external onlyRoles(ROLES_MANAGER_ROLE) {
        _grantRoles(handler, HANDLER_ROLE);
    }

    function removeHandlerRole(address handler) external onlyRoles(ROLES_MANAGER_ROLE) {
        _removeRoles(handler, HANDLER_ROLE);
    }

    function isHandler(address handler) external view returns (bool) {
        return hasAnyRole(handler, HANDLER_ROLE);
    }

    // registry role
    function addRegistryRole(address registry) external onlyRoles(ROLES_MANAGER_ROLE) {
        _grantRoles(registry, REGISTRY_ROLE);
    }

    function removeRegistryRole(address registry) external onlyRoles(ROLES_MANAGER_ROLE) {
        _removeRoles(registry, REGISTRY_ROLE);
    }

    function isRegistry(address registry) external view returns (bool) {
        return hasAnyRole(registry, REGISTRY_ROLE);
    }

    // bridge role
    function addBridgeRole(address bridge) external onlyRoles(ROLES_MANAGER_ROLE) {
        _grantRoles(bridge, BRIDGE_ROLE);
    }

    function removeBridgeRole(address bridge) external onlyRoles(ROLES_MANAGER_ROLE) {
        _removeRoles(bridge, BRIDGE_ROLE);
    }

    function isBridge(address bridge) external view returns (bool) {
        return hasAnyRole(bridge, BRIDGE_ROLE);
    }

    // minter role
    function addMinterRole(address minter) external onlyRoles(ROLES_MANAGER_ROLE) {
        _grantRoles(minter, MINTER_ROLE);
    }

    function removeMinterRole(address minter) external onlyRoles(ROLES_MANAGER_ROLE) {
        _removeRoles(minter, MINTER_ROLE);
    }

    function isMinter(address minter) external view returns (bool) {
        return hasAnyRole(minter, MINTER_ROLE);
    }
}
