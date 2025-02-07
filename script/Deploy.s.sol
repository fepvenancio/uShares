// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/USharesToken.sol";
import "../src/VaultRegistry.sol";
import "../src/PositionManager.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

contract DeployScript is Script {
    // Configuration
    string constant NAME = "uShares";
    string constant SYMBOL = "uSHR";
    uint32 constant SOURCE_CHAIN = 1; // Ethereum mainnet

    function run() external {
        // Load deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Load addresses from environment
        address usdc = vm.envAddress("USDC_ADDRESS");
        address tokenMessenger = vm.envAddress("TOKEN_MESSENGER_ADDRESS");
        address messageTransmitter = vm.envAddress("MESSAGE_TRANSMITTER_ADDRESS");
        address router = vm.envAddress("ROUTER_ADDRESS");
        address ccipAdmin = vm.envAddress("CCIP_ADMIN");

        console.log("Deploying uShares protocol with deployer:", deployer);
        console.log("USDC address:", usdc);
        console.log("Token Messenger address:", tokenMessenger);
        console.log("Message Transmitter address:", messageTransmitter);
        console.log("Router address:", router);
        console.log("CCIP admin:", ccipAdmin);

        // Verify CCTP contracts
        require(tokenMessenger != address(0), "Invalid token messenger");
        require(messageTransmitter != address(0), "Invalid message transmitter");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy VaultRegistry
        console.log("Deploying VaultRegistry...");
        VaultRegistry registry = new VaultRegistry(usdc);
        console.log("VaultRegistry deployed at:", address(registry));

        // 2. Deploy PositionManager
        console.log("Deploying PositionManager...");
        PositionManager positionManager = new PositionManager(address(registry));
        console.log("PositionManager deployed at:", address(positionManager));

        // 3. Deploy USharesToken
        console.log("Deploying USharesToken...");
        USharesToken token = new USharesToken(
            NAME,
            SYMBOL,
            SOURCE_CHAIN,
            address(positionManager),
            ccipAdmin,
            tokenMessenger,
            usdc,
            router
        );
        console.log("USharesToken deployed at:", address(token));

        // 4. Configure initial permissions
        console.log("Configuring permissions...");
        
        // Configure PositionManager permissions
        positionManager.configureHandler(address(token), true);
        
        // Configure token permissions
        token.setVaultRegistry(address(registry));
        token.configureMinter(address(positionManager), true);
        token.configureBurner(address(positionManager), true);

        vm.stopBroadcast();

        // Log final deployment addresses
        console.log("\nDeployment Summary:");
        console.log("-------------------");
        console.log("VaultRegistry:", address(registry));
        console.log("PositionManager:", address(positionManager));
        console.log("USharesToken:", address(token));
    }
} 