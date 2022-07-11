// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Auth} from "solmate/auth/Auth.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Strategy, ERC20Strategy, ETHStrategy} from "./interfaces/Strategy.sol";

/// @title WAGMI Vault (wagToken)
/// @author prampey
/// @notice Vault contract which keeps track of PnL and ensures secure and non-custodial:
/// - deposits and withdrawals
/// - trade orders on any DEX
contract Vault is ERC4626, Auth {
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

    /// @notice The underlying token the Vault accepts.
    ERC20 public immutable UNDERLYING;

    /// @notice The base unit of the underlying token and hence rvToken.
    /// @dev Equal to 10 ** decimals. Used for fixed point arithmetic.
    uint256 internal immutable BASE_UNIT;

    /// @notice Creates a new Vault
    /// @param _UNDERLYING The ERC20 compliant token the Vault should accept.
    constructor(ERC20 _UNDERLYING, string memory _stratName,
        string memory _stratSymbol)
        ERC4626(
            // Underlying token
            _UNDERLYING,
            // ex: Zeno's Keep
            string(abi.encodePacked(_stratName, "'s Keep")),
            // ex: zKeep
            string(abi.encodePacked(_stratSymbol, "Keep"))
        )
        Auth(Auth(msg.sender).owner(), Auth(msg.sender).authority())
    {
        UNDERLYING = _UNDERLYING;

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
    function setFeePercent(uint256 newFeePercent) external requiresAuth {
        // A fee percentage over 100% doesn't make sense.
        require(newFeePercent <= 100, "FEE_TOO_HIGH");

        // Update the fee percentage.
        feePercent = newFeePercent;

        emit FeePercentUpdated(msg.sender, newFeePercent);
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// TODO: Transfer vault tokens to the depositor 
    function afterDeposit(uint256, uint256) internal override {}

    /// @notice Deposits funds into the vault and mint vault tokens for the depositor
    /// @param usdcAmount Amount to deposit
    function deposit(uint256 usdcAmount) public returns (uint256) {

        uint256 fundValue = totalFundValue();

        require(
            IERC20(getAssetProxy(_SUSD_KEY)).transferFrom(
                msg.sender,
                address(this),
                usdcAmount
            ),
            "token transfer failed"
        );

        uint256 vaultTokensMinted;
        if (totalSupply > 0) {
            //total balance converted to susd that this contract holds
            //need to calculate total value of synths in this contract
            vaultTokensMinted = usdcAmount.mul(totalSupply).div(fundValue);
        } else {
            vaultTokensMinted = usdcAmount;
        }

        _mint(msg.sender, vaultTokensMinted);

        emit Deposit(
            address(this),
            msg.sender,
            _susdAmount,
            liquidityMinted,
            balanceOf(msg.sender),
            fundValue.add(_susdAmount),
            totalSupplyBefore.add(liquidityMinted),
            block.timestamp
        );

        return vaultTokensMinted;
    }



    /*///////////////////////////////////////////////////////////////
                        VAULT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates the total amount of underlying tokens the Vault holds.
    /// @return totalUnderlyingHeld The total amount of underlying tokens the Vault holds.
    function totalAssets() public view override returns (uint256 totalUnderlyingHeld) {
        unchecked {
            // Cannot underflow as locked profit can't exceed total strategy holdings.
            totalUnderlyingHeld = totalStrategyHoldings - lockedProfit();
        }

        // Include our floating balance in the total.
        totalUnderlyingHeld += totalFloat();
    }

    /// @notice Calculates the current amount of locked profit.
    /// @return The current amount of locked profit.
    function lockedProfit() public view returns (uint256) {
        // Get the last harvest and harvest delay.
        uint256 previousHarvest = lastHarvest;
        uint256 harvestInterval = harvestDelay;

        unchecked {
            // If the harvest delay has passed, there is no locked profit.
            // Cannot overflow on human timescales since harvestInterval is capped.
            if (block.timestamp >= previousHarvest + harvestInterval) return 0;

            // Get the maximum amount we could return.
            uint256 maximumLockedProfit = maxLockedProfit;

            // Compute how much profit remains locked based on the last harvest and harvest delay.
            // It's impossible for the previous harvest to be in the future, so this will never underflow.
            return maximumLockedProfit - (maximumLockedProfit * (block.timestamp - previousHarvest)) / harvestInterval;
        }
    }

    /// @notice Returns the amount of underlying tokens that idly sit in the Vault.
    /// @return The amount of underlying tokens that sit idly in the Vault.
    function totalFloat() public view returns (uint256) {
        return UNDERLYING.balanceOf(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                    STRATEGY DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after the Vault deposits into a strategy contract.
    /// @param user The authorized user who triggered the deposit.
    /// @param strategy The strategy that was deposited into.
    /// @param underlyingAmount The amount of underlying tokens that were deposited.
    event StrategyDeposit(address indexed user, Strategy indexed strategy, uint256 underlyingAmount);

    /// @notice Emitted after the Vault withdraws funds from a strategy contract.
    /// @param user The authorized user who triggered the withdrawal.
    /// @param strategy The strategy that was withdrawn from.
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event StrategyWithdrawal(address indexed user, Strategy indexed strategy, uint256 underlyingAmount);

    /// @notice Deposit a specific amount of float into a trusted strategy.
    /// @param strategy The trusted strategy to deposit into.
    /// @param underlyingAmount The amount of underlying tokens in float to deposit.
    function depositIntoStrategy(Strategy strategy, uint256 underlyingAmount) external requiresAuth {
        // A strategy must be trusted before it can be deposited into.
        require(getStrategyData[strategy].trusted, "UNTRUSTED_STRATEGY");

        // Increase totalStrategyHoldings to account for the deposit.
        totalStrategyHoldings += underlyingAmount;

        unchecked {
            // Without this the next harvest would count the deposit as profit.
            // Cannot overflow as the balance of one strategy can't exceed the sum of all.
            getStrategyData[strategy].balance += underlyingAmount.safeCastTo248();
        }

        emit StrategyDeposit(msg.sender, strategy, underlyingAmount);

        // We need to deposit differently if the strategy takes ETH.
        if (strategy.isCEther()) {
            // Unwrap the right amount of WETH.
            WETH(payable(address(UNDERLYING))).withdraw(underlyingAmount);

            // Deposit into the strategy and assume it will revert on error.
            ETHStrategy(address(strategy)).mint{value: underlyingAmount}();
        } else {
            // Approve underlyingAmount to the strategy so we can deposit.
            UNDERLYING.safeApprove(address(strategy), underlyingAmount);

            // Deposit into the strategy and revert if it returns an error code.
            require(ERC20Strategy(address(strategy)).mint(underlyingAmount) == 0, "MINT_FAILED");
        }
    }

    /// @notice Withdraw a specific amount of underlying tokens from a strategy.
    /// @param strategy The strategy to withdraw from.
    /// @param underlyingAmount  The amount of underlying tokens to withdraw.
    /// @dev Withdrawing from a strategy will not remove it from the withdrawal stack.
    function withdrawFromStrategy(Strategy strategy, uint256 underlyingAmount) external requiresAuth {
        // A strategy must be trusted before it can be withdrawn from.
        require(getStrategyData[strategy].trusted, "UNTRUSTED_STRATEGY");

        // Without this the next harvest would count the withdrawal as a loss.
        getStrategyData[strategy].balance -= underlyingAmount.safeCastTo248();

        unchecked {
            // Decrease totalStrategyHoldings to account for the withdrawal.
            // Cannot underflow as the balance of one strategy will never exceed the sum of all.
            totalStrategyHoldings -= underlyingAmount;
        }

        emit StrategyWithdrawal(msg.sender, strategy, underlyingAmount);

        // Withdraw from the strategy and revert if it returns an error code.
        require(strategy.redeemUnderlying(underlyingAmount) == 0, "REDEEM_FAILED");

        // Wrap the withdrawn Ether into WETH if necessary.
        if (strategy.isCEther()) WETH(payable(address(UNDERLYING))).deposit{value: underlyingAmount}();
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
    function claimFees(uint256 rvTokenAmount) external requiresAuth {
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
    function initialize() external requiresAuth {
        // Ensure the Vault has not already been initialized.
        require(!isInitialized, "ALREADY_INITIALIZED");

        // Mark the Vault as initialized.
        isInitialized = true;

        // Open for deposits.
        totalSupply = 0;

        emit Initialized(msg.sender);
    }

    /// @notice Self destructs a Vault, enabling it to be redeployed.
    /// @dev Caller will receive any ETH held as float in the Vault.
    function destroy() external requiresAuth {
        selfdestruct(payable(msg.sender));
    }

    /*///////////////////////////////////////////////////////////////
                          RECIEVE ETHER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Required for the Vault to receive unwrapped ETH.
    receive() external payable {}
}
