// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AddressBook } from "./utils/AddressBook.sol";
import { Config } from "./utils/Config.s.sol";
import { TokenAdminRegistry } from "chainlink/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import { Script, console } from "forge-std/Script.sol";

// Script contract to set the token pool in the TokenAdminRegistry
contract SetPool is Script {
    address tokenAddress;
    address tokenAdmin;
    address poolAddress;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        if (block.chainid == AddressBook.OPTIMISM) {
            tokenAddress = AddressBook.OP_USharesToken;
            poolAddress = AddressBook.OP_POOL;
        } else if (block.chainid == AddressBook.BASE) {
            tokenAddress = AddressBook.BASE_USharesToken;
            poolAddress = AddressBook.BASE_POOL;
        } else {
            revert("Unsupported chain ID");
        }

        // Fetch the network configuration to get the TokenAdminRegistry address
        Config config = new Config();
        (,,, address tokenAdminRegistry,,,,) = config.activeNetworkConfig();

        require(tokenAddress != address(0), "Invalid token address");
        require(poolAddress != address(0), "Invalid pool address");
        require(tokenAdminRegistry != address(0), "TokenAdminRegistry is not defined for this network");

        vm.startBroadcast(deployerPrivateKey);

        // Instantiate the TokenAdminRegistry contract
        TokenAdminRegistry tokenAdminRegistryContract = TokenAdminRegistry(tokenAdminRegistry);

        // Fetch the token configuration to get the administrator's address
        TokenAdminRegistry.TokenConfig memory tokenConfig = tokenAdminRegistryContract.getTokenConfig(tokenAddress);
        address tokenAdministratorAddress = AddressBook.DEPLOYER_ADDRESS;

        console.log("Setting pool for token:", tokenAddress);
        console.log("New pool address:", poolAddress);
        console.log("Action performed by admin:", tokenAdministratorAddress);
        console.log("TokenConfig: ", tokenConfig.pendingAdministrator);
        // Use the administrator's address to set the pool for the token
        tokenAdminRegistryContract.setPool(tokenAddress, poolAddress);

        console.log("Pool set for token", tokenAddress, "to", poolAddress);

        vm.stopBroadcast();
    }
}
