// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITokenMessenger} from "../interfaces/ITokenMessenger.sol";
import {ITokenMinter} from "../interfaces/ITokenMinter.sol";
import {Errors} from "../libraries/Errors.sol";

/**
 * @title BaseTokenPool
 * @notice Base contract for interacting with Circle's CCTP
 * @dev Handles USDC transfers between chains using Circle's TokenMessenger
 */
contract BaseTokenPool {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The USDC token contract
    IERC20 public immutable usdc;

    /// @notice The CCTP TokenMessenger contract
    ITokenMessenger public immutable tokenMessenger;

    /// @notice The destination domain ID for CCTP transfers
    uint32 public immutable destinationDomain;

    /// @notice Event emitted when bridging USDC via Chainlink CCT
    event TokensBridged(uint32 indexed destinationDomain, address indexed recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _usdc,
        address _tokenMessenger,
        uint32 _destinationDomain
    ) {
        Errors.verifyAddress(_usdc);
        Errors.verifyAddress(_tokenMessenger);
        Errors.verifyChainId(_destinationDomain);

        usdc = IERC20(_usdc);
        tokenMessenger = ITokenMessenger(_tokenMessenger);
        destinationDomain = _destinationDomain;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Bridges USDC to another chain using Circle's CCTP
     * @param recipient The recipient address on the destination chain
     * @param amount The amount of USDC to bridge
     */
    function bridgeUsdcViaCctp(address recipient, uint256 amount) external {
        // Get burn limit per message from the minter
        ITokenMinter minter = tokenMessenger.localMinter();
        uint256 burnLimit = minter.burnLimitsPerMessage(address(usdc));

        // If amount exceeds burn limit, split into multiple transfers
        uint256 remaining = amount;
        while (remaining > 0) {
            uint256 transferAmount = remaining > burnLimit ? burnLimit : remaining;
            
            // Approve TokenMessenger to spend USDC
            usdc.safeIncreaseAllowance(address(tokenMessenger), transferAmount);
            
            // Deposit USDC for burning and transfer
            tokenMessenger.depositForBurn(
                transferAmount,
                destinationDomain,
                bytes32(uint256(uint160(recipient))), // Convert address to bytes32
                address(usdc)
            );
            
            remaining -= transferAmount;
        }
    }

    /**
     * @notice Checks if an amount exceeds the burn limit
     * @param amount The amount to check
     * @return Whether the amount exceeds the burn limit
     */
    function exceedsBurnLimit(uint256 amount) external view returns (bool) {
        ITokenMinter minter = tokenMessenger.localMinter();
        uint256 burnLimit = minter.burnLimitsPerMessage(address(usdc));
        return amount > burnLimit;
    }

    /**
     * @notice Gets the burn limit per message
     * @return The burn limit
     */
    function getBurnLimit() external view returns (uint256) {
        ITokenMinter minter = tokenMessenger.localMinter();
        return minter.burnLimitsPerMessage(address(usdc));
    }
} 