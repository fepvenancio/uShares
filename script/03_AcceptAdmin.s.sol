// SPDX-License-Identifier: MIT
pragma solidity 0.8.29; // Network configuration helper

import { AddressBook } from "./utils/AddressBook.sol";
import { Config } from "./utils/Config.s.sol";
import { TokenAdminRegistry } from "chainlink/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import { Script, console } from "forge-std/Script.sol"; // Common addresses used in scripts

contract AcceptAdminRole is Script {
    address tokenAddress;
    address tokenAdmin;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        if (block.chainid == AddressBook.OPTIMISM) {
            tokenAddress = AddressBook.OP_USharesToken;
        } else if (block.chainid == AddressBook.BASE) {
            tokenAddress = AddressBook.BASE_USharesToken;
        } else {
            revert("Unsupported chain ID");
        }

        tokenAdmin = AddressBook.DEPLOYER_ADDRESS;

        // Fetch the network configuration to get the TokenAdminRegistry address
        Config config = new Config();
        (,,, address tokenAdminRegistry,,,,) = config.activeNetworkConfig();

        // Ensure the token address and TokenAdminRegistry address are valid
        require(tokenAddress != address(0), "Invalid token address");
        require(tokenAdminRegistry != address(0), "TokenAdminRegistry is not defined for this network");

        vm.startBroadcast(deployerPrivateKey);

        // Get the address of the signer (the account executing the script)
        address signer = AddressBook.DEPLOYER_ADDRESS;

        // Instantiate the TokenAdminRegistry contract
        TokenAdminRegistry tokenAdminRegistryContract = TokenAdminRegistry(tokenAdminRegistry);

        // Fetch the token configuration for the given token address
        TokenAdminRegistry.TokenConfig memory tokenConfig = tokenAdminRegistryContract.getTokenConfig(tokenAddress);

        // Get the pending administrator for the token
        address pendingAdministrator = tokenConfig.pendingAdministrator;

        // Ensure the signer is the pending administrator
        require(pendingAdministrator == signer, "Only the pending administrator can accept the admin role");

        // Accept the admin role for the token
        tokenAdminRegistryContract.acceptAdminRole(tokenAddress);

        console.log("Accepted admin role for token:", tokenAddress);

        vm.stopBroadcast();
    }
}
