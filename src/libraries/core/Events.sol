// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title Events
 * @notice Library containing events used in the UShares protocol
 */
library Events {
    // UShares Protocol
    event USharesProtocol();

    // Proxy
    event ProxyCreated(address indexed proxy, uint256 moduleId);

    // Modules
    event InstallerAddedModule(uint256 indexed moduleId, address indexed moduleImpl, bytes32 moduleVersion);

    // Vault Registry
    event VaultRegistered(address indexed vault);
    event VaultUpdated(address indexed vault, bool active);
    event VaultRemoved(address indexed vault);

    // Cross-chain
    event DepositInitiated(
        address indexed user, uint32 destinationChain, address indexed vault, uint256 amount, uint256 minSharesExpected
    );
    event WithdrawalInitiated(
        address indexed user, uint32 destinationChain, address indexed vault, uint256 shares, uint256 minUsdcExpected
    );
    event LimitsUpdated(uint32 domain, uint256 minAmount, uint256 maxAmount);
    event CrossChainDepositCompleted(
        bytes32 indexed depositId, address indexed user, address indexed vault, uint256 shares
    );
    event CrossChainWithdrawalInitiated(
        bytes32 indexed withdrawalId,
        address indexed user,
        address indexed vault,
        uint256 shares,
        uint256 minUsdcExpected
    );
    event CrossChainWithdrawalCompleted(
        bytes32 indexed withdrawalId, address indexed user, address indexed vault, uint256 usdcAmount
    );
    event DepositTimeout(bytes32 indexed depositId, address user, uint256 amount);
    event WithdrawalTimeout(bytes32 indexed withdrawalId, address user, uint256 shares);

    // uShares Token Registry
    event USharesTokenCreated(
        address indexed asset, address indexed uSharesToken, uint256 index
    );
    event GenericImplementationUpdated(address indexed genericImpl);

    // BaseModule
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event ChainFeeUpdated(uint32 chain, uint256 oldFee, uint256 newFee);
    event FeeCollectorUpdated(address oldCollector, address newCollector);
    event EmergencyWithdraw(address token, uint256 amount, address to);
    event ChainSelectorUpdated(uint32 chain, uint64 selector);
    event CrossVaultAddressUpdated(uint32 chain, address crossVault);
}
