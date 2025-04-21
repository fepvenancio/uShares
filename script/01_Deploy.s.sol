// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../src/USharesToken.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        // Load deployer private key from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy USharesToken on Base
        uint8 decimals = 6;
        string memory name = "uShares Token";
        string memory symbol = "uSHARES";
        uint256 maxSupply = type(uint256).max;
        uint256 preMint = 0;

        USharesToken token = new USharesToken(name, symbol, decimals, maxSupply, preMint);

        // Grant roles to the pool
        token.grantMintAndBurnRoles(deployer);

        console.log("Base Deployment Addresses:");
        console.log("USharesToken:", address(token));
        console.log("Deployer:", deployer);

        vm.stopBroadcast();
    }
}
