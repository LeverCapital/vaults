//        ___       ___           ___           ___           ___
//       /\__\     /\  \         /\__\         /\  \         /\  \
//      /:/  /    /::\  \       /:/  /        /::\  \       /::\  \
//     /:/  /    /:/\:\  \     /:/  /        /:/\:\  \     /:/\:\  \
//    /:/  /    /::\~\:\  \   /:/__/  ___   /::\~\:\  \   /::\~\:\  \
//   /:/__/    /:/\:\ \:\__\  |:|  | /\__\ /:/\:\ \:\__\ /:/\:\ \:\__\
//   \:\  \    \:\~\:\ \/__/  |:|  |/:/  / \:\~\:\ \/__/ \/_|::\/:/  /
//    \:\  \    \:\ \:\__\    |:|__/:/  /   \:\ \:\__\      |:|::/  /
//     \:\  \    \:\ \/__/     \::::/__/     \:\ \/__/      |:|\/__/
//      \:\__\    \:\__\        ~~~~          \:\__\        |:|  |
//       \/__/     \/__/                       \/__/         \|__|
//
//   Lever Capital - https://sigma-ui.on.fleek.co/#/perp-vaults
//
//   SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC4626} from "./modules/ERC4626.sol";

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IExchange, Order} from "./interfaces/IExchange.sol";
import {GMXClient} from "./modules/GMXClient.sol";

interface IRouter {
    function approvePlugin(address _plugin) external;
}

/// @title Perpetual Vault
/// @author prampey
/// @notice Vault contract which keeps track of PnL and ensures secure and non-custodial:
/// - trade orders on GMX
/// - Lock funds during trading window
/// - Performance fees, manager fees
/// - Two access roles: Owner and Manager
/// - Claim trading rewards
contract Vault is ERC4626, Owned, GMXClient {
    using SafeCastLib for uint256;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The maximum number of elements allowed on the withdrawal stack.
    /// @dev Needed to prevent denial of service attacks by queue operators.
    uint256 internal constant MAX_WITHDRAWAL_STACK_SIZE = 32;

    /*///////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The base unit of the underlying token and hence rvToken.
    /// @dev Equal to 10 ** decimals. Used for fixed point arithmetic.
    uint256 internal immutable BASE_UNIT;

    /// @notice Creates a new Vault
    /// @param _asset The ERC20 compliant token the Vault should accept.
    constructor(
        ERC20 _asset,
        string memory _stratName,
        string memory _stratSymbol,
        address _owner,
        address _manager
    )
        ERC4626(_asset, string(abi.encodePacked(_stratName)), string(abi.encodePacked(_stratSymbol)))
        Owned(_owner)
        GMXClient(_manager)
    {
        BASE_UNIT = 10**decimals;

        // Prevent minting of shares until
        // the initialize function is called.
        totalSupply = type(uint256).max;
    }

    /*///////////////////////////////////////////////////////////////
                           FEE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Fees taken as a percentage of the profits realised during withdrawal
    /// @dev A fixed point number where 100 represents 100% and 0 represents 0%.
    uint256 public feePercent;

    /// @notice Emitted when the fee percentage is updated.
    /// @param user The authorized user who triggered the update.
    /// @param newFeePercent The new fee percentage.
    event FeePercentUpdated(address indexed user, uint256 newFeePercent);

    /// @notice Sets a new fee percentage.
    /// @param newFeePercent The new fee percentage.
    function setFeePercent(uint256 newFeePercent) external onlyOwner {
        // A fee percentage over 100% doesn't make sense.
        require(newFeePercent <= 100, "FEE_TOO_HIGH");

        // Update the fee percentage.
        feePercent = newFeePercent;

        emit FeePercentUpdated(msg.sender, newFeePercent);
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function beforeDeposit(uint256, uint256) internal view override {
        require(!positionOpen, "Trading currently in progress!");
    }

    function beforeWithdraw(uint256, uint256) internal view override {
        require(!positionOpen, "Trading currently in progress!");
    }

    /*///////////////////////////////////////////////////////////////
                        VAULT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates the total amount of assets the Vault holds.
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                             FEE CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after fees are claimed.
    /// @param user The authorized user who claimed the fees.
    /// @param rvTokenAmount The amount of rvTokens that were claimed.
    event FeesClaimed(address indexed user, uint256 rvTokenAmount);

    /// @notice Claims fees accrued from harvests.
    /// @param rvTokenAmount The amount of rvTokens to claim.
    /// @dev Accrued fees are measured as rvTokens held by the Vault.
    function claimFees(uint256 rvTokenAmount) external onlyOwner {
        emit FeesClaimed(msg.sender, rvTokenAmount);

        // Transfer the provided amount of rvTokens to the caller.
        ERC20(this).safeTransfer(msg.sender, rvTokenAmount);
    }

    /*///////////////////////////////////////////////////////////////
                    INITIALIZATION AND DESTRUCTION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the Vault is initialized.
    /// @param user The authorized user who triggered the initialization.
    event Initialized(address indexed user);

    /// @notice Whether the Vault has been initialized yet.
    /// @dev Can go from false to true, never from true to false.
    bool public isInitialized;

    /// @notice Initializes the Vault, enabling it to receive deposits.
    /// @dev All critical parameters must already be set before calling.
    function initialize() external onlyOwner {
        // Ensure the Vault has not already been initialized.
        require(!isInitialized, "ALREADY_INITIALIZED");

        // Mark the Vault as initialized.
        isInitialized = true;

        // Open for deposits.
        totalSupply = 0;

        // Open for trading with router
        asset.approve(ROUTER, type(uint256).max); // TODO: Approve upto MAX spend limit?

        emit Initialized(msg.sender);
    }

    /// @notice Self destructs a Vault, enabling it to be redeployed.
    /// @dev Caller will receive any ETH held as float in the Vault.
    function destroy() external onlyOwner {
        selfdestruct(payable(msg.sender));
    }

    /*///////////////////////////////////////////////////////////////
                          MANAGER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows vault owner to set the fund manager
    function setManager(address newManager) public override onlyOwner {
        manager = newManager;
        emit ManagerUpdated(msg.sender, newManager);
    }

    /*///////////////////////////////////////////////////////////////
                          RECIEVE ETHER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Required for the Vault to receive unwrapped ETH.
    receive() external payable {}
}
