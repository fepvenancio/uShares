// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Errors } from "../../src/libraries/Errors.sol";
import { RolesManager } from "../../src/libraries/roles/RolesManager.sol";
import { BaseTest } from "../helpers/BaseTest.sol";

contract RolesManagerTest is BaseTest {
    RolesManager public rolesManager;

    function setUp() public {
        super._setUp("BASE", 29_200_000);
        vm.startPrank(users.admin);
        rolesManager = new RolesManager(users.admin);
        vm.stopPrank();
    }

    function test_Constructor() public {
        assertEq(rolesManager.owner(), users.admin);
        assertTrue(rolesManager.hasAnyRole(users.admin, rolesManager.ROLES_MANAGER_ROLE()));
    }

    function test_RevertWhen_ConstructorWithZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        new RolesManager(address(0));
    }

    function test_SetUSharesAdminRole() public {
        vm.startPrank(users.admin);

        rolesManager.setUSharesAdminRole(users.alice);
        assertTrue(rolesManager.hasAnyRole(users.alice, rolesManager.USHARES_ADMIN_ROLE()));

        vm.stopPrank();
    }

    function test_RevertWhen_UnauthorizedSetUSharesAdmin() public {
        vm.startPrank(users.alice);

        vm.expectRevert();
        rolesManager.setUSharesAdminRole(users.bob);

        vm.stopPrank();
    }

    function test_SetAndVerifyProtocol() public {
        vm.startPrank(users.admin);

        address protocol = makeAddr("protocol");
        rolesManager.setProtocol(protocol);
        assertTrue(rolesManager.isProtocol(protocol));

        vm.stopPrank();
    }

    function test_RevertWhen_SetProtocolZeroAddress() public {
        vm.startPrank(users.admin);

        vm.expectRevert(Errors.ZeroAddress.selector);
        rolesManager.setProtocol(address(0));

        vm.stopPrank();
    }

    function test_ProtocolAdminRole() public {
        vm.startPrank(users.admin);

        // Add protocol admin role
        rolesManager.addProtocolAdminRole(users.alice);
        assertTrue(rolesManager.isProtocolAdmin(users.alice));

        // Remove protocol admin role
        rolesManager.removeProtocolAdminRole(users.alice);
        assertFalse(rolesManager.isProtocolAdmin(users.alice));

        vm.stopPrank();
    }

    function test_EmergencyAdminRole() public {
        vm.startPrank(users.admin);

        // Add emergency admin role
        rolesManager.addEmergencyAdminRole(users.bob);
        assertTrue(rolesManager.isEmergencyAdmin(users.bob));

        // Remove emergency admin role
        rolesManager.removeEmergencyAdminRole(users.bob);
        assertFalse(rolesManager.isEmergencyAdmin(users.bob));

        vm.stopPrank();
    }

    function test_GovernanceAdminRole() public {
        vm.startPrank(users.admin);

        // Add governance admin role
        rolesManager.addGovernanceAdminRole(users.charlie);
        assertTrue(rolesManager.isGovernanceAdmin(users.charlie));

        // Remove governance admin role
        rolesManager.removeGovernanceAdminRole(users.charlie);
        assertFalse(rolesManager.isGovernanceAdmin(users.charlie));

        vm.stopPrank();
    }

    function test_HandlerRole() public {
        vm.startPrank(users.admin);

        // Add handler role
        rolesManager.addHandlerRole(users.handler);
        assertTrue(rolesManager.isHandler(users.handler));

        // Remove handler role
        rolesManager.removeHandlerRole(users.handler);
        assertFalse(rolesManager.isHandler(users.handler));

        vm.stopPrank();
    }

    function test_RegistryRole() public {
        vm.startPrank(users.admin);

        // Add registry role
        rolesManager.addRegistryRole(users.vault);
        assertTrue(rolesManager.isRegistry(users.vault));

        // Remove registry role
        rolesManager.removeRegistryRole(users.vault);
        assertFalse(rolesManager.isRegistry(users.vault));

        vm.stopPrank();
    }

    function test_BridgeRole() public {
        vm.startPrank(users.admin);

        address bridge = makeAddr("bridge");

        // Add bridge role
        rolesManager.addBridgeRole(bridge);
        assertTrue(rolesManager.isBridge(bridge));

        // Remove bridge role
        rolesManager.removeBridgeRole(bridge);
        assertFalse(rolesManager.isBridge(bridge));

        vm.stopPrank();
    }

    function test_MinterRole() public {
        vm.startPrank(users.admin);

        address minter = makeAddr("minter");

        // Add minter role
        rolesManager.addMinterRole(minter);
        assertTrue(rolesManager.isMinter(minter));

        // Remove minter role
        rolesManager.removeMinterRole(minter);
        assertFalse(rolesManager.isMinter(minter));

        vm.stopPrank();
    }

    function test_MultipleRolesForSameAddress() public {
        vm.startPrank(users.admin);

        // Add multiple roles to same address
        rolesManager.addProtocolAdminRole(users.alice);
        rolesManager.addEmergencyAdminRole(users.alice);
        rolesManager.addGovernanceAdminRole(users.alice);

        // Verify all roles are active
        assertTrue(rolesManager.isProtocolAdmin(users.alice));
        assertTrue(rolesManager.isEmergencyAdmin(users.alice));
        assertTrue(rolesManager.isGovernanceAdmin(users.alice));

        // Remove one role
        rolesManager.removeProtocolAdminRole(users.alice);

        // Verify only that role was removed
        assertFalse(rolesManager.isProtocolAdmin(users.alice));
        assertTrue(rolesManager.isEmergencyAdmin(users.alice));
        assertTrue(rolesManager.isGovernanceAdmin(users.alice));

        vm.stopPrank();
    }

    function test_RevertWhen_UnauthorizedRoleManagement() public {
        // Try to add roles without being admin
        vm.startPrank(users.alice);

        vm.expectRevert();
        rolesManager.addProtocolAdminRole(users.bob);

        vm.expectRevert();
        rolesManager.addEmergencyAdminRole(users.bob);

        vm.expectRevert();
        rolesManager.addGovernanceAdminRole(users.bob);

        vm.expectRevert();
        rolesManager.addHandlerRole(users.bob);

        vm.stopPrank();
    }

    function test_RevertWhen_UnauthorizedRoleRemoval() public {
        // Set up a role first
        vm.startPrank(users.admin);
        rolesManager.addProtocolAdminRole(users.alice);
        vm.stopPrank();

        // Try to remove role without being admin
        vm.startPrank(users.bob);

        vm.expectRevert();
        rolesManager.removeProtocolAdminRole(users.alice);

        vm.stopPrank();

        // Verify role still exists
        assertTrue(rolesManager.isProtocolAdmin(users.alice));
    }

    function test_RoleHierarchy() public {
        vm.startPrank(users.admin);

        // Add protocol admin
        rolesManager.addProtocolAdminRole(users.alice);

        // Protocol admin should not be able to add other admins
        vm.stopPrank();
        vm.startPrank(users.alice);

        vm.expectRevert();
        rolesManager.addProtocolAdminRole(users.bob);

        vm.expectRevert();
        rolesManager.addEmergencyAdminRole(users.bob);

        vm.stopPrank();
    }

    function test_RolesManagerRole() public {
        // Verify admin has roles manager role from constructor
        assertTrue(rolesManager.hasAnyRole(users.admin, rolesManager.ROLES_MANAGER_ROLE()));

        vm.startPrank(users.admin);

        // Add roles manager role to another address through public function
        rolesManager.grantRoles(users.alice, rolesManager.ROLES_MANAGER_ROLE());
        assertTrue(rolesManager.hasAnyRole(users.alice, rolesManager.ROLES_MANAGER_ROLE()));

        // Remove roles manager role through public function
        rolesManager.revokeRoles(users.alice, rolesManager.ROLES_MANAGER_ROLE());
        assertFalse(rolesManager.hasAnyRole(users.alice, rolesManager.ROLES_MANAGER_ROLE()));

        vm.stopPrank();
    }
}
