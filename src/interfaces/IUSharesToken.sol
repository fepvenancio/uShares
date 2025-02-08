// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DataTypes} from "../types/DataTypes.sol";

interface IUSharesToken {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event VaultRegistrySet(address indexed registry);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

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

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // View functions
    function chainId() external view returns (uint32);
    function vaultRegistry() external view returns (address);
    function paused() external view returns (bool);
    function chainToVaultMapping(uint32 chainId, address localVault) external view returns (address);
    function deposits(bytes32 depositId) external view returns (DataTypes.CrossChainDeposit memory);
    function withdrawals(bytes32 withdrawalId) external view returns (DataTypes.CrossChainWithdrawal memory);
    function USDC() external view returns (address);
    function isIssuingChain() external view returns (bool);
    function cctp() external view returns (address);

    // Admin functions
    function setVaultRegistry(address _vaultRegistry) external;
    function pause() external;
    function unpause() external;

    // Token functions
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;

    // Cross-chain operations
    function initiateDeposit(
        address targetVault,
        uint256 usdcAmount,
        uint32 destinationChain,
        uint256 minShares,
        uint256 deadline
    ) external returns (bytes32 depositId);

    function processCCTPCompletion(bytes32 depositId, bytes calldata attestation) external;

    function initiateWithdrawal(
        uint256 uSharesAmount,
        address targetVault,
        uint256 minUSDC,
        uint256 deadline
    ) external returns (bytes32 withdrawalId);

    function processWithdrawalCompletion(bytes32 withdrawalId, bytes calldata attestation) external;
}
