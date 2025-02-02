// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Errors {
    error InvalidAmount();
    error InvalidChain();
    error InvalidVault();
    error VaultNotActive();
    error VaultActive();
    error PositionNotFound();
    error Unauthorized();
    error InvalidDestination();
    error InsufficientShares();
    error VaultExists();
    error InvalidAsset();
    error ActiveShares();
    error Paused();
    error PositionExists();
    error DuplicateMessage();
    error RateLimitExceeded();
    error InsufficientAllowance();
    error NotHandler();
    error NotMinter();
    error NotBurner();
    error NotTokenPool();
    error NotPositionManager();
    error NotCCIPAdmin();
    error ExceedsMaxSize();

    error ZeroAddress(address addr);
    error ZeroBytes(bytes32 key);
    error ZeroNumber(uint256 num);

    function verifyNotZero(address addr) internal pure {
        if (addr == address(0)) {
            revert ZeroAddress(addr);
        }
    }

    function verifyNotZero(bytes32 key) internal pure {
        if (key == bytes32(0)) {
            revert ZeroBytes(key);
        }
    }

    function verifyNotZero(uint256 num) internal pure {
        if (num == 0) {
            revert ZeroNumber(num);
        }
    }
}
