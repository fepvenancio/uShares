// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/USharesToken.sol";

contract DeployUSharesToken is Script {
    function run() external {
        // Load deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Token parameters
        string memory name = "CCTDemo";
        string memory symbol = "CCTD";
        uint8 decimals = 6;
        uint256 maxSupply = 0;
        uint256 initialSupply = 0;

        // Start broadcast
        vm.startBroadcast(deployerPrivateKey);

        // Deploy token
        USharesToken token = new USharesToken(
            name,
            symbol,
            decimals,
            maxSupply,
            initialSupply
        );

        // Log deployment info
        console.log("USharesToken deployed to:", address(token));
        console.log("Owner:", token.owner());
        console.log("CCIP Admin:", token.getCCIPAdmin());
        console.log("Total Supply:", token.totalSupply());

        vm.stopBroadcast();

        // Output verification command
        console.log("\nVerify contract:");
        console.log("forge verify-contract", address(token), "USharesToken", "--chain base");
    }
}
