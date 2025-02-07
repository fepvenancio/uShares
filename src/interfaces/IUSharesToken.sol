// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DataTypes} from "../types/DataTypes.sol";

/**
 * @title IUSharesToken
 * @notice Interface for uShares cross-chain token standard
 * @dev Based on Chainlink's CCT (Cross-Chain Token) standard
 */
interface IUSharesToken {
    // Events
    event DepositInitiated(
        bytes32 indexed depositId,
        address indexed user,
        uint256 usdcAmount,
        address targetVault,
        uint32 destinationChain,
        uint256 minShares,
        uint256 deadline
    );

    event CCTPCompleted(
        bytes32 indexed depositId, 
        uint256 usdcAmount, 
        uint32 destinationChain,
        address targetVault
    );

    event VaultSharesReceived(
        bytes32 indexed depositId,
        address indexed vault,
        uint256 vaultShares
    );

    event SharesIssued(
        bytes32 indexed depositId, 
        address indexed user, 
        uint256 uSharesAmount,
        uint256 vaultShares
    );

    event WithdrawalInitiated(
        bytes32 indexed withdrawalId,
        address indexed user,
        uint256 uSharesAmount,
        address targetVault,
        uint32 destinationChain,
        uint256 minUSDC,
        uint256 deadline
    );

    event WithdrawalCompleted(
        bytes32 indexed withdrawalId,
        address indexed user,
        uint256 usdcAmount
    );

    event VaultMapped(uint32 indexed chainId, address indexed localVault, address indexed remoteVault);

    event TokensMinted(address indexed to, uint256 amount, uint32 sourceChain, bytes32 messageId);

    event TokensBurned(address indexed from, uint256 amount, uint32 destinationChain, bytes32 messageId);

    // Role management events
    event MinterConfigured(address indexed minter, bool status);
    event BurnerConfigured(address indexed burner, bool status);
    event TokenPoolConfigured(address indexed pool, bool status);
    event RemotePoolUpdated(uint32 chainId, address pool, bool allowed);
    event CCIPAdminUpdated(address oldAdmin, address newAdmin);

    // Core functions
    function initiateDeposit(
        address targetVault,
        uint256 usdcAmount,
        uint64 destinationChainSelector,
        uint256 minShares,
        uint256 deadline
    ) external returns (bytes32 depositId);

    function processCCTPCompletion(bytes32 depositId, bytes memory attestation) external;

    function mintSharesFromDeposit(bytes32 depositId, uint256 vaultShares) external;

    // Withdrawal functions
    function initiateWithdrawal(
        uint256 uSharesAmount,
        address targetVault,
        uint256 minUSDC,
        uint256 deadline
    ) external returns (bytes32 withdrawalId);

    function processWithdrawalCompletion(bytes32 withdrawalId, bytes calldata attestation) external;

    function recoverStaleWithdrawal(bytes32 withdrawalId) external;

    // Admin functions
    function setVaultMapping(uint32 chainId, address localVault, address remoteVault) external;

    function setCCTPContract(address cctp) external;
    function setTokenPool(address pool) external;

    // Role management functions
    function configureMinter(address minter, bool status) external;
    function configureBurner(address burner, bool status) external;
    function configureTokenPool(address pool, bool status) external;

    // View functions
    function getDeposit(bytes32 depositId) external view returns (DataTypes.CrossChainDeposit memory);
    function getWithdrawal(bytes32 withdrawalId) external view returns (DataTypes.CrossChainWithdrawal memory);
    function getVaultMapping(uint32 chainId, address localVault) external view returns (address);
    function getCCTPContract() external view returns (address);
    function getChainId() external view returns (uint32);
    function getCCIPAdmin() external view returns (address);
    function getTokenPool() external view returns (address);
}
