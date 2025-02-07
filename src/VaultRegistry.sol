// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {IVaultRegistry} from "./interfaces/IVaultRegistry.sol";
import {DataTypes} from "./types/DataTypes.sol";
import {KeyManager} from "./libs/KeyManager.sol";
import {Errors} from "./libs/Errors.sol";

/**
 * @title VaultRegistry
 * @notice Manages the registration and validation of ERC4626 vaults across different chains
 */
contract VaultRegistry is IVaultRegistry, OwnableRoles {
    using SafeTransferLib for ERC20;
    using KeyManager for *;

    // Roles
    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant HANDLER_ROLE = _ROLE_1;
    uint256 public constant PAUSER_ROLE = _ROLE_2;

    // State variables
    address public immutable usdc;
    mapping(bytes32 => DataTypes.VaultInfo) public vaults;
    mapping(uint32 => address[]) public chainVaults;
    mapping(uint32 => uint256) public chainVaultCount;
    mapping(bytes32 => uint256) public lastSharePrice; // Track last share price for validation
    bool public paused;

    // Events
    event VaultRegistered(uint32 indexed chainId, address indexed vault, bool active);
    event VaultUpdated(uint32 indexed chainId, address indexed vault, bool active);
    event VaultRemoved(uint32 indexed chainId, address indexed vault);
    event SharesUpdated(uint32 indexed chainId, address indexed vault, uint96 totalShares);
    event SharePriceUpdated(uint32 indexed chainId, address indexed vault, uint256 sharePrice);
    event Paused(address account);
    event Unpaused(address account);

    // Share price deviation threshold (1% = 100)
    uint256 public constant SHARE_PRICE_DEVIATION_THRESHOLD = 1000; // 10%

    modifier whenNotPaused() {
        if (paused) revert Errors.Paused();
        _;
    }

    constructor(address _usdc) {
        Errors.verifyAddress(_usdc);
        usdc = _usdc;
        _initializeOwner(msg.sender);
        _grantRoles(msg.sender, ADMIN_ROLE | HANDLER_ROLE | PAUSER_ROLE);
    }

    function registerVault(uint32 chainId, address vault) external override onlyRoles(ADMIN_ROLE) whenNotPaused {
        Errors.verifyChainId(chainId);
        Errors.verifyAddress(vault);

        // Create vault key
        bytes32 vaultKey = KeyManager.getVaultKey(chainId, vault);

        // Check vault doesn't exist
        if (vaults[vaultKey].vaultAddress != address(0)) {
            revert Errors.VaultExists();
        }

        // Validate vault implements ERC4626 and uses USDC
        ERC4626 vaultContract = ERC4626(vault);
        if (address(vaultContract.asset()) != address(usdc)) {
            revert Errors.InvalidAsset();
        }

        // Store vault info
        vaults[vaultKey] = DataTypes.VaultInfo({
            vaultAddress: vault,
            chainId: chainId,
            totalShares: 0,
            lastUpdate: uint64(block.timestamp),
            active: true
        });

        // Update chain tracking
        chainVaults[chainId].push(vault);
        chainVaultCount[chainId]++;

        emit VaultRegistered(chainId, vault, true);
    }

    function updateVaultStatus(uint32 chainId, address vault, bool active) external override onlyRoles(ADMIN_ROLE) whenNotPaused {
        bytes32 vaultKey = KeyManager.getVaultKey(chainId, vault);
        DataTypes.VaultInfo storage vaultInfo = vaults[vaultKey];
        Errors.verifyAddress(vaultInfo.vaultAddress);

        vaultInfo.active = active;
        emit VaultUpdated(chainId, vault, active);
    }

    function removeVault(uint32 chainId, address vault) external override onlyRoles(ADMIN_ROLE) whenNotPaused {
        bytes32 vaultKey = KeyManager.getVaultKey(chainId, vault);
        DataTypes.VaultInfo memory vaultInfo = vaults[vaultKey];

        Errors.verifyAddress(vaultInfo.vaultAddress);
        if (vaultInfo.active) revert Errors.VaultActive();

        delete vaults[vaultKey];
        emit VaultRemoved(chainId, vault);
    }

    function updateVaultShares(uint32 chainId, address vault, uint96 newTotalShares) external override onlyRoles(HANDLER_ROLE) whenNotPaused {
        Errors.verifyChainId(chainId);
        Errors.verifyAddress(vault);
        Errors.verifyNumber(newTotalShares);

        bytes32 vaultKey = KeyManager.getVaultKey(chainId, vault);
        DataTypes.VaultInfo storage vaultInfo = vaults[vaultKey];
        Errors.verifyAddress(vaultInfo.vaultAddress);

        // Update total shares
        vaultInfo.totalShares = newTotalShares;

        // Update share price if vault is on this chain
        if (chainId == block.chainid) {
            ERC4626 vaultContract = ERC4626(vault);
            uint256 currentSharePrice = vaultContract.convertToAssets(1e6);
            
            // If this is first update, just record it
            if (lastSharePrice[vaultKey] == 0) {
                lastSharePrice[vaultKey] = currentSharePrice;
            } else {
                // Check for suspicious share price changes
                uint256 priceChange = currentSharePrice > lastSharePrice[vaultKey] 
                    ? ((currentSharePrice - lastSharePrice[vaultKey]) * 10000) / lastSharePrice[vaultKey]
                    : ((lastSharePrice[vaultKey] - currentSharePrice) * 10000) / lastSharePrice[vaultKey];
                
                if (priceChange > SHARE_PRICE_DEVIATION_THRESHOLD) revert Errors.SuspiciousSharePriceChange();
                lastSharePrice[vaultKey] = currentSharePrice;
            }
            
            emit SharePriceUpdated(chainId, vault, currentSharePrice);
        }

        emit SharesUpdated(chainId, vault, newTotalShares);
    }

    function pause() external onlyRoles(PAUSER_ROLE) {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyRoles(PAUSER_ROLE) {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // Role management functions
    function grantRoles(address user, uint256 roles) public payable virtual override onlyRoles(ADMIN_ROLE) {
        _grantRoles(user, roles);
    }

    function revokeRoles(address user, uint256 roles) public payable virtual override onlyRoles(ADMIN_ROLE) {
        _removeRoles(user, roles);
    }

    function renounceRoles(uint256 roles) public payable virtual override {
        _removeRoles(msg.sender, roles);
    }

    // View functions
    function getVaultInfo(uint32 chainId, address vault) external view override returns (DataTypes.VaultInfo memory) {
        return vaults[KeyManager.getVaultKey(chainId, vault)];
    }

    function isVaultActive(uint32 chainId, address vault) external view override returns (bool) {
        return vaults[KeyManager.getVaultKey(chainId, vault)].active;
    }

    function getChainVaults(uint32 chainId) external view override returns (address[] memory) {
        return chainVaults[chainId];
    }

    function validateVaultOperation(uint32 chainId, address vault, uint256 shareAmount) external view returns (bool) {
        bytes32 vaultKey = KeyManager.getVaultKey(chainId, vault);
        DataTypes.VaultInfo memory vaultInfo = vaults[vaultKey];
        
        if (!vaultInfo.active) return false;
        
        // Check if vault exists and is active
        if (vaultInfo.vaultAddress == address(0)) return false;
        
        // If vault is on this chain, perform additional validations
        if (chainId == block.chainid) {
            ERC4626 vaultContract = ERC4626(vault);
            
            // Validate share price hasn't changed suspiciously
            uint256 currentSharePrice = vaultContract.convertToAssets(1e6);
            if (lastSharePrice[vaultKey] != 0) {
                uint256 priceChange = currentSharePrice > lastSharePrice[vaultKey]
                    ? ((currentSharePrice - lastSharePrice[vaultKey]) * 10000) / lastSharePrice[vaultKey]
                    : ((lastSharePrice[vaultKey] - currentSharePrice) * 10000) / lastSharePrice[vaultKey];
                
                if (priceChange > SHARE_PRICE_DEVIATION_THRESHOLD) return false;
            }
            
            // Validate vault has enough capacity for operation
            uint256 maxDeposit = vaultContract.maxDeposit(address(this));
            if (shareAmount > maxDeposit) return false;
        }
        
        return true;
    }
}
