// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {RegistryModuleOwnerCustom} from "chainlink/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {USharesToken} from "../../src/USharesToken.sol";
import {AddressBook} from "./utils/AddressBook.sol";
import {Config} from "./utils/Config.s.sol";

contract ClaimAdminRole is Script {
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

        // Fetch the network configuration
        Config config = new Config();
        (, , , , address registryModuleOwnerCustom, , , ) = config
            .activeNetworkConfig();

        require(tokenAddress != address(0), "Invalid token address");
        require(
            registryModuleOwnerCustom != address(0),
            "Registry module owner custom is not defined for this network"
        );

        vm.startBroadcast(deployerPrivateKey);

        USharesToken token = USharesToken(tokenAddress);
        RegistryModuleOwnerCustom registryContract = RegistryModuleOwnerCustom(
            registryModuleOwnerCustom
        );
        
        require(
            token.getCCIPAdmin() == tokenAdmin,
            "CCIP admin of token does not match the token admin address provided."
        );

        registryContract.registerAdminViaGetCCIPAdmin(tokenAddress);
        console.log("Admin claimed successfully for token:", tokenAddress);
        vm.stopBroadcast();
    }
}
