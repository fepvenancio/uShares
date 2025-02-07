// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/USharesToken.sol";
import "../src/VaultRegistry.sol";
import "../src/PositionManager.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

contract ConfigureScript is Script {
    // Chain configuration
    uint32 constant SOURCE_CHAIN = 1; // Ethereum mainnet
    uint32 constant DEST_CHAIN = 43114; // Avalanche

    // Role constants from USharesToken
    uint256 constant TOKEN_POOL_ROLE = 1 << 3; // _ROLE_3

    function run() external {
        // Load deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Load contract addresses from environment
        address token = vm.envAddress("USHARES_TOKEN");
        address registry = vm.envAddress("VAULT_REGISTRY");
        address positionManager = vm.envAddress("POSITION_MANAGER");
        
        // Load configuration addresses
        address vault = vm.envAddress("VAULT_ADDRESS");
        address tokenPool = vm.envAddress("TOKEN_POOL");
        address ccipAdmin = vm.envAddress("CCIP_ADMIN");

        console.log("Configuring uShares protocol with deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Configure VaultRegistry
        console.log("Configuring VaultRegistry...");
        VaultRegistry(registry).registerVault(DEST_CHAIN, vault);
        
        // Initialize share tracking
        uint256 initialShares = ERC4626(vault).totalSupply();
        VaultRegistry(registry).updateVaultShares(DEST_CHAIN, vault, uint96(initialShares));
        
        console.log("Vault registered:", vault);
        console.log("Initial shares:", initialShares);

        // 2. Configure PositionManager
        console.log("Configuring PositionManager...");
        PositionManager(positionManager).configureHandler(token, true);
        PositionManager(positionManager).configureHandler(tokenPool, true);
        console.log("Handlers configured for token and pool");

        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("CCIP_ADMIN_KEY"));
        
        // 3. Configure token pools and CCTP settings
        console.log("Configuring token pools and CCTP...");
        USharesToken(token).configureTokenPool(tokenPool, true);
        USharesToken(token).setVaultMapping(DEST_CHAIN, tokenPool, vault);
        
        // Set up cross-chain mappings
        USharesToken(token).setVaultMapping(SOURCE_CHAIN, tokenPool, vault);
        
        console.log("Token pool configured:", tokenPool);
        console.log("Vault mappings set for chains:", SOURCE_CHAIN, DEST_CHAIN);

        vm.stopBroadcast();
        vm.startBroadcast(deployerPrivateKey);

        // 4. Configure emergency controls
        console.log("Configuring emergency controls...");
        // Start unpaused
        VaultRegistry(registry).unpause();
        
        // 5. Verify configuration
        console.log("\nVerifying configuration:");
        console.log("------------------------");
        bool isVaultActive = VaultRegistry(registry).isVaultActive(DEST_CHAIN, vault);
        bool isTokenPoolConfigured = USharesToken(token).hasAnyRole(tokenPool, TOKEN_POOL_ROLE);
        bool isHandlerConfigured = PositionManager(positionManager).isHandler(token);
        address mappedVault = USharesToken(token).getVaultMapping(DEST_CHAIN, tokenPool);
        
        require(isVaultActive, "Vault not active");
        require(isTokenPoolConfigured, "Token pool not configured");
        require(isHandlerConfigured, "Handler not configured");
        require(mappedVault == vault, "Invalid vault mapping");

        // Log final configuration state
        console.log("\nConfiguration Summary:");
        console.log("----------------------");
        console.log("Vault active:", isVaultActive);
        console.log("Token pool configured:", isTokenPoolConfigured);
        console.log("Handler configured:", isHandlerConfigured);
        console.log("Mapped vault:", mappedVault);
        console.log("Initial shares:", initialShares);

        vm.stopBroadcast();
    }
} 