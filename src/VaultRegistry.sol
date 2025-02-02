// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "solady/auth/Ownable.sol";
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
contract VaultRegistry is IVaultRegistry, Ownable {
    using SafeTransferLib for ERC20;
    using KeyManager for *;

    // State variables
    address public immutable usdc;
    mapping(bytes32 => DataTypes.VaultInfo) public vaults;
    mapping(uint32 => address[]) public chainVaults;
    mapping(uint32 => uint256) public chainVaultCount;
    bool public paused;

    // Events
    event VaultRegistered(uint32 indexed chainId, address indexed vault, bool active);
    event VaultUpdated(uint32 indexed chainId, address indexed vault, bool active);
    event VaultRemoved(uint32 indexed chainId, address indexed vault);
    event Paused(address account);
    event Unpaused(address account);

    modifier whenNotPaused() {
        if (paused) revert Errors.Paused();
        _;
    }

    constructor(address _usdc) {
        Errors.verifyNotZero(_usdc);
        usdc = _usdc;
        _initializeOwner(msg.sender);
    }

    function registerVault(
        uint32 chainId,
        address vault
    ) external override onlyOwner whenNotPaused {
        Errors.verifyNotZero(chainId);
        Errors.verifyNotZero(vault);

        // Create vault key
        bytes32 vaultKey = KeyManager.getVaultKey(chainId, vault);

        // Check vault doesn't exist
        if (vaults[vaultKey].vaultAddress != address(0))
            revert Errors.VaultExists();

        // Validate vault implements ERC4626 and uses USDC
        ERC4626 vaultContract = ERC4626(vault);
        if (address(vaultContract.asset()) != address(usdc))
            revert Errors.InvalidAsset();

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

    function updateVaultStatus(
        uint32 chainId,
        address vault,
        bool active
    ) external override onlyOwner whenNotPaused {
        bytes32 vaultKey = KeyManager.getVaultKey(chainId, vault);
        DataTypes.VaultInfo storage vaultInfo = vaults[vaultKey];
        Errors.verifyNotZero(vaultInfo.vaultAddress);

        vaultInfo.active = active;
        emit VaultUpdated(chainId, vault, active);
    }

    function removeVault(
        uint32 chainId,
        address vault
    ) external override onlyOwner whenNotPaused {
        bytes32 vaultKey = KeyManager.getVaultKey(chainId, vault);
        DataTypes.VaultInfo memory vaultInfo = vaults[vaultKey];
        
        Errors.verifyNotZero(vaultInfo.vaultAddress);
        if (vaultInfo.active) revert Errors.VaultActive();

        delete vaults[vaultKey];
        emit VaultRemoved(chainId, vault);
    }

    function getVaultInfo(
        uint32 chainId,
        address vault
    ) external view override returns (DataTypes.VaultInfo memory) {
        return vaults[KeyManager.getVaultKey(chainId, vault)];
    }

    function isVaultActive(
        uint32 chainId,
        address vault
    ) external view override returns (bool) {
        return vaults[KeyManager.getVaultKey(chainId, vault)].active;
    }

    function getChainVaults(
        uint32 chainId
    ) external view override returns (address[] memory) {
        return chainVaults[chainId];
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }
}
