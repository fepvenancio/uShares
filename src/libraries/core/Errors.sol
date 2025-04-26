// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title Errors
 * @notice Library containing all custom errors used in the protocol
 * @dev Centralizes error definitions and provides validation utilities
 * @custom:security-contact security@ushares.com
 */
library Errors {
    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL ERRORS
    //////////////////////////////////////////////////////////////*/

    error RMAdminZeroAddress();
    /// @notice Thrown when caller is not the owner
    error NotOwner();
    /// @notice Thrown when caller is not a handler
    error NotHandler();
    /// @notice Thrown when caller is not authorized
    error Unauthorized();
    /// @notice Thrown when caller is not a bridge
    error NotBridge();
    /// @notice Thrown when caller is not an admin
    error NotAdmin();

    /*//////////////////////////////////////////////////////////////
                            INPUT VALIDATION ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an address parameter is zero
    error ZeroAddress();
    /// @notice Thrown when a bytes32 parameter is zero
    error ZeroBytes(bytes32 key);
    /// @notice Thrown when a number parameter is zero
    error ZeroNumber(uint256 num);
    /// @notice Thrown when a chain ID is zero
    error ZeroChainId();
    /// @notice Thrown when an amount is invalid
    error InvalidAmount();
    /// @notice Thrown when a configuration is invalid
    error InvalidConfig();
    /// @notice Thrown when a vault address is invalid
    error InvalidVault();
    /// @notice Thrown when a deposit ID is invalid
    error InvalidDeposit();
    /// @notice Thrown when a withdrawal ID is invalid
    error InvalidWithdrawal();
    /// @notice Thrown when the balance is lower than amount
    error InsufficientBalance();
    /// @notice Thrown when a fee is invalid
    error InvalidFee();
    /// @notice Thrown when a source chain is invalid
    error InvalidSource();

    /*//////////////////////////////////////////////////////////////
                            STATE ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a deadline is too far in the future
    error DeadlineTooFar();
    /// @notice Thrown when a deadline has expired
    error DeadlineExpired();
    /// @notice Thrown when a deadline has passed
    error InvalidDeadline();
    /// @notice Thrown when a token is not USDC
    error NotUSDC();
    /// @notice Thrown when vault is not active
    error VaultNotActive();
    /// @notice Thrown when vault is active but should not be
    error VaultActive();
    /// @notice Thrown when contract is paused
    error Paused();
    /// @notice Thrown when deposit has expired
    error DepositExpired();
    /// @notice Thrown when position already exists
    error PositionExists();
    /// @notice Thrown when position is not found
    error PositionNotFound();
    /// @notice Thrown when shares are insufficient
    error InsufficientShares();
    /// @notice Thrown when allowance is insufficient
    error InsufficientAllowance();
    /// @notice Thrown when withdrawal has expired
    error WithdrawalExpired();
    /// @notice Thrown when USDC amount is insufficient
    error InsufficientUSDC();
    /// @notice Thrown when rate limit is exceeded
    error RateLimitExceeded(address token, uint256 requested, uint256 available);
    /// @notice Thrown when deployment fails
    error FailedDeployment();
    /// @notice Thrown when fallback call fails
    error Fallback();
    /// @notice Thrown when a contract cannot receive ETH
    error CantReceiveETH();

    /*//////////////////////////////////////////////////////////////
                            VALIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that an address is not zero
     * @dev Reverts with ZeroAddress if address is zero
     * @param addr Address to verify
     */
    function verifyAddress(address addr) internal pure {
        if (addr == address(0)) {
            revert ZeroAddress();
        }
    }

    /**
     * @notice Verifies that a bytes32 value is not zero
     * @dev Reverts with ZeroBytes if value is zero
     * @param key Bytes32 value to verify
     */
    function verifyBytes32(bytes32 key) internal pure {
        if (key == bytes32(0)) {
            revert ZeroBytes(key);
        }
    }

    /**
     * @notice Verifies that a number is not zero
     * @dev Reverts with ZeroNumber if number is zero
     * @param num Number to verify
     */
    function verifyNumber(uint256 num) internal pure {
        if (num == 0) {
            revert ZeroNumber(num);
        }
    }

    /**
     * @notice Verifies that a chain ID is not zero
     * @dev Reverts with ZeroChainId if chain ID is zero
     * @param chainId Chain ID to verify
     */
    function verifyChainId(uint32 chainId) internal pure {
        if (chainId == 0) revert ZeroChainId();
    }

    /**
     * @notice Verifies that a vault is active
     * @dev Reverts with VaultNotActive if vault is not active
     * @param isActive Whether the vault is active
     */
    function verifyIfActive(bool isActive) internal pure {
        if (!isActive) revert VaultNotActive();
    }

    /**
     * @notice Verifies that a number is not zero
     * @dev Reverts with InvalidAmount if number is zero
     * @param value Number to verify
     */
    function verifyNotZero(uint256 value) internal pure {
        if (value == 0) revert InvalidAmount();
    }

    // Common errors
    error InvalidAddress(address addr);
    error InvalidDomain(uint32 domain);
    error InvalidLength(uint256 length);
    error InvalidSignature();
    error AlreadyInitialized();
    error NotInitialized();
    error InvalidState();
    error InvalidInput();
    error InvalidOperation();
    error OperationFailed();
    error ContractNotFound();
}
