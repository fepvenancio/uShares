// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title IRolesManager
 * @author filipeVenancio
 * @notice Defines the basic interface for the Roles Manager
 */
interface IRolesManager {
    //////////////////////////////////////////////////////////////////////
    /// ROLES MANAGER
    //////////////////////////////////////////////////////////////////////

    // ROLES
    function USHARES_ADMIN_ROLE() external view returns (uint256);

    function PROTOCOL_ADMIN_ROLE() external view returns (uint256);

    function EMERGENCY_ADMIN_ROLE() external view returns (uint256);

    function GOVERNANCE_ADMIN_ROLE() external view returns (uint256);

    function HANDLER_ROLE() external view returns (uint256);

    function REGISTRY_ROLE() external view returns (uint256);

    function BRIDGE_ROLE() external view returns (uint256);

    function MINTER_ROLE() external view returns (uint256);

    function ROLES_MANAGER_ROLE() external view returns (uint256);

    // FUNCTIONS
    function setUSharesAdminRole(address admin) external;

    function setProtocol(address protocol) external;

    function isProtocol(address protocol) external view returns (bool);

    function addProtocolAdminRole(address protocolAdmin) external;

    function removeProtocolAdminRole(address protocolAdmin) external;

    function isProtocolAdmin(address protocolAdmin) external view returns (bool);

    function addEmergencyAdminRole(address emergencyAdmin) external;

    function removeEmergencyAdminRole(address emergencyAdmin) external;

    function isEmergencyAdmin(address emergencyAdmin) external view returns (bool);

    function addGovernanceAdminRole(address governanceAdmin) external;

    function removeGovernanceAdminRole(address governanceAdmin) external;

    function isGovernanceAdmin(address governanceAdmin) external view returns (bool);

    function addHandlerRole(address handler) external;

    function removeHandlerRole(address handler) external;

    function isHandler(address handler) external view returns (bool);

    function addRegistryRole(address registry) external;

    function removeRegistryRole(address registry) external;

    function isRegistry(address registry) external view returns (bool);

    function addBridgeRole(address bridge) external;

    function removeBridgeRole(address bridge) external;

    function isBridge(address bridge) external view returns (bool);

    function addMinterRole(address minter) external;

    function removeMinterRole(address minter) external;

    function isMinter(address minter) external view returns (bool);
}
