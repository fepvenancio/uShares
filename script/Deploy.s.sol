// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import {USharesToken} from "../src/USharesToken.sol";
import {VaultRegistry} from "../src/VaultRegistry.sol";
import {PositionManager} from "../src/PositionManager.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

contract DeployScript is Script {
    // Configuration
    string constant NAME = "uShares";
    string constant SYMBOL = "uSHR";
    uint32 constant SOURCE_CHAIN = 1; // Ethereum mainnet
    uint8 constant TOKEN_DECIMALS = 6;

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
        address tokenPool = vm.envAddress("TOKEN_POOL_ADDRESS");

        console.log("Deploying uShares protocol with deployer:", deployer);
        console.log("USDC address:", usdc);
        console.log("Token Messenger address:", tokenMessenger);
        console.log("Message Transmitter address:", messageTransmitter);
        console.log("Router address:", router);
        console.log("CCIP admin:", ccipAdmin);
        console.log("Token Pool address:", tokenPool);

        // Verify CCTP contracts
        require(tokenMessenger != address(0), "Invalid token messenger");
        require(messageTransmitter != address(0), "Invalid message transmitter");
        require(tokenPool != address(0), "Invalid token pool");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy VaultRegistry
        console.log("Deploying VaultRegistry...");
        VaultRegistry registry = new VaultRegistry(usdc);
        console.log("VaultRegistry deployed at:", address(registry));

        // 2. Deploy PositionManager
        console.log("Deploying PositionManager...");
        PositionManager positionManager = new PositionManager(address(registry));
        console.log("PositionManager deployed at:", address(positionManager));

        // 3. Deploy USharesToken with CCT support
        console.log("Deploying USharesToken...");
        USharesToken token = new USharesToken(
            NAME,
            SYMBOL,
            SOURCE_CHAIN,
            true, // isIssuingChain
            address(positionManager),
            tokenMessenger,
            usdc,
            tokenPool
        );
        console.log("USharesToken deployed at:", address(token));

        // 4. Configure initial permissions
        console.log("Configuring permissions...");
        
        // Configure PositionManager permissions
        positionManager.configureHandler(address(token), true);
        positionManager.configureTokenPool(SOURCE_CHAIN, tokenPool);
        
        // Configure token permissions
        token.setVaultRegistry(address(registry));
        token.configureMinter(address(positionManager), true);
        token.configureBurner(address(positionManager), true);
        token.configureTokenPool(tokenPool, true);

        // Configure registry permissions
        registry.grantRoles(address(positionManager), registry.HANDLER_ROLE());
        registry.grantRoles(tokenPool, registry.TOKEN_POOL_ROLE());

        vm.stopBroadcast();

        // Log final deployment addresses
        console.log("\nDeployment Summary:");
        console.log("-------------------");
        console.log("VaultRegistry:", address(registry));
        console.log("PositionManager:", address(positionManager));
        console.log("USharesToken:", address(token));
        console.log("Token Pool:", tokenPool);
    }
}

contract DeployBase is Script {
    // Base Mainnet Configuration (Source/Issuing Chain)
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant TOKEN_MESSENGER = 0x1682Ae6375C4E4A97e4B583BC394c861A46D8962;
    uint32 constant BASE_CHAIN_ID = 8453;
    bool constant IS_ISSUING_CHAIN = true; // Base is our issuing chain

    function run() external {
        // Load deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying uShares protocol on Base with deployer:", deployer);
        console.log("USDC:", USDC);
        console.log("TokenMessenger:", TOKEN_MESSENGER);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy VaultRegistry
        console.log("Deploying VaultRegistry...");
        VaultRegistry registry = new VaultRegistry(USDC);
        console.log("VaultRegistry deployed at:", address(registry));

        // 2. Deploy PositionManager
        console.log("Deploying PositionManager...");
        PositionManager positionManager = new PositionManager(address(registry));
        console.log("PositionManager deployed at:", address(positionManager));

        // 3. Deploy USharesToken
        console.log("Deploying USharesToken...");
        USharesToken token = new USharesToken(
            BASE_CHAIN_ID,
            IS_ISSUING_CHAIN,
            TOKEN_MESSENGER,
            USDC
        );
        console.log("USharesToken deployed at:", address(token));

        // 4. Configure initial permissions
        console.log("Configuring permissions...");
        
        // Configure PositionManager permissions
        positionManager.grantRoles(address(token), positionManager.HANDLER_ROLE());
        
        // Configure token permissions
        token.setVaultRegistry(address(registry));
        token.grantRoles(address(positionManager), token.MINTER_ROLE() | token.BURNER_ROLE());

        // Configure registry permissions
        registry.grantRoles(address(positionManager), registry.HANDLER_ROLE());

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\nDeployment Summary (Base):");
        console.log("-------------------");
        console.log("VaultRegistry:", address(registry));
        console.log("PositionManager:", address(positionManager));
        console.log("USharesToken:", address(token));
    }
}

contract DeployOptimism is Script {
    // Optimism Configuration (Destination Chain)
    address constant USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address constant TOKEN_MESSENGER = 0x2B4069517957735bE00ceE0fadAE88a26365528f;
    uint32 constant OPTIMISM_CHAIN_ID = 10;
    bool constant IS_ISSUING_CHAIN = false; // Optimism is not the issuing chain

    function run() external {
        // Load deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying uShares protocol on Optimism with deployer:", deployer);
        console.log("USDC:", USDC);
        console.log("TokenMessenger:", TOKEN_MESSENGER);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy VaultRegistry
        console.log("Deploying VaultRegistry...");
        VaultRegistry registry = new VaultRegistry(USDC);
        console.log("VaultRegistry deployed at:", address(registry));

        // 2. Deploy PositionManager
        console.log("Deploying PositionManager...");
        PositionManager positionManager = new PositionManager(address(registry));
        console.log("PositionManager deployed at:", address(positionManager));

        // 3. Deploy USharesToken
        console.log("Deploying USharesToken...");
        USharesToken token = new USharesToken(
            OPTIMISM_CHAIN_ID,
            IS_ISSUING_CHAIN,
            TOKEN_MESSENGER,
            USDC
        );
        console.log("USharesToken deployed at:", address(token));

        // 4. Configure initial permissions
        console.log("Configuring permissions...");
        
        // Configure PositionManager permissions
        positionManager.grantRoles(address(token), positionManager.HANDLER_ROLE());
        
        // Configure token permissions
        token.setVaultRegistry(address(registry));
        token.grantRoles(address(positionManager), token.MINTER_ROLE() | token.BURNER_ROLE());

        // Configure registry permissions
        registry.grantRoles(address(positionManager), registry.HANDLER_ROLE());

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\nDeployment Summary (Optimism):");
        console.log("-------------------");
        console.log("VaultRegistry:", address(registry));
        console.log("PositionManager:", address(positionManager));
        console.log("USharesToken:", address(token));
    }
} 