// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BurnMintERC677} from "chainlink/contracts/src/v0.8/shared/token/ERC677/BurnMintERC677.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title USharesToken
 * @notice Implementation of the UShares token contract extending BurnMintERC677
 * @dev This contract extends Chainlink's BurnMintERC677 for CCT compatibility
 * @custom:security-contact security@ushares.com
 */
contract USharesToken is BurnMintERC677 {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Whether the contract is paused
    bool public paused;

    /// @notice The CCIP admin address
    address public ccipAdmin;

    /// @notice Minimum amount for transactions
    uint256 public minAmount = 1e6; // 1 USDC

    /// @notice Maximum amount for transactions
    uint256 public maxAmount = 1000000e6; // 1M USDC

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CCIPAdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event Paused(address account);
    event Unpaused(address account);
    event LimitsUpdated(uint256 minAmount, uint256 maxAmount);
    event MaxSlippageUpdated(uint256 maxSlippage);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier whenNotPaused() {
        if (paused) revert Errors.Paused();
        _;
    }

    modifier onlyOwnerOrCCIPAdmin() {
        require(msg.sender == owner() || msg.sender == ccipAdmin, "Not owner or CCIP admin");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 maxSupply_,
        uint256 preMint
    ) BurnMintERC677(name_, symbol_, decimals_, maxSupply_) {
        ccipAdmin = msg.sender;
        
        // Pre-mint initial supply if requested
        if (preMint > 0) {
            _mint(msg.sender, preMint);
        }

        // Grant minting and burning roles to deployer
        grantMintRole(msg.sender);
        grantBurnRole(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the CCIP admin address
     * @return The current CCIP admin address
     */
    function getCCIPAdmin() external view returns (address) {
        return ccipAdmin;
    }

    /**
     * @notice Transfer CCIP admin role to new address
     * @param newAdmin Address of new admin
     */
    function transferCCIPAdmin(address newAdmin) external onlyOwner {
        require(newAdmin != address(0), "Zero address not allowed");
        address oldAdmin = ccipAdmin;
        ccipAdmin = newAdmin;
        emit CCIPAdminTransferred(oldAdmin, newAdmin);
    }

    /**
     * @notice Pause the contract
     */
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Update transaction limits
     * @param _minAmount New minimum amount
     * @param _maxAmount New maximum amount
     */
    function updateLimits(uint256 _minAmount, uint256 _maxAmount) external onlyOwner {
        if (_minAmount == 0 || _maxAmount == 0) revert Errors.InvalidAmount();
        if (_minAmount >= _maxAmount) revert Errors.InvalidConfig();
        
        minAmount = _minAmount;
        maxAmount = _maxAmount;
        emit LimitsUpdated(_minAmount, _maxAmount);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}

