// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Auth} from "solmate/auth/Auth.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IExchange, OrderType, Market} from "./interfaces/IExchange.sol";

interface IPositionRouter {
    function createIncreasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _acceptablePrice,
        uint256 _executionFee,
        bytes32 _referralCode
    ) external payable;
}

interface IRouter {
    function approvePlugin(address _plugin) external;
}

/// @title Perpetual Vault
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
    /// @notice Address of PositionRouter contract
    /// @dev Used to interact with the contract and manage positions
    address internal constant POSITION_ROUTER = 0x3D6bA331e3D9702C5e8A8d254e5d8a285F223aba;
    /// @notice Address of OrderBook contract
    address internal constant ORDER_BOOK = 0x09f77E8A13De9a35a7231028187e9fD5DB8a2ACB;
    /// @notice Address of Router contract
    address constant ROUTER = 0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064;

    /*///////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The underlying token the Vault accepts.

    IPositionRouter internal immutable posRouter;

    /// @notice The base unit of the underlying token and hence rvToken.
    /// @dev Equal to 10 ** decimals. Used for fixed point arithmetic.
    uint256 internal immutable BASE_UNIT;

    /// @notice Creates a new Vault
    /// @param _asset The ERC20 compliant token the Vault should accept.
    constructor(
        ERC20 _asset,
        string memory _stratName,
        string memory _stratSymbol
    )
        // Underlying token
        ERC4626(
            _asset,
            // ex: Zeno's Keep
            string(abi.encodePacked(_stratName, "'s Keep")),
            // ex: zKeep
            string(abi.encodePacked(_stratSymbol, "Keep"))
        )
        Auth(Auth(msg.sender).owner(), Auth(msg.sender).authority())
    {
        BASE_UNIT = 10**decimals;

        // Prevent minting of shares until
        // the initialize function is called.
        totalSupply = type(uint256).max;
        /// @dev Instantiate the Position Router contract using its address
        posRouter = IPositionRouter(POSITION_ROUTER);
        // Setup logic
        getCurrencyContract["USDC"] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
        getCurrencyContract["ETH"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
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

    function afterDeposit(uint256, uint256) internal override {}

    /*///////////////////////////////////////////////////////////////
                        VAULT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates the total amount of assets the Vault holds.
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                             VAULT POSITIONS LOGIC
    //////////////////////////////////////////////////////////////*/

    bool public positionOpen = false;

    mapping(string => address) getCurrencyContract;

    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param price the initial sqrt price of the pool as a Q64.96
    function openPosition(
        OrderType order,
        Market calldata market,
        uint256 price,
        uint256 size
    ) public {
        // Add an emit event here
        bool isLong = order == OrderType.Buy ? true : false;
        address[] memory path = new address[](2);
        path[0] = getCurrencyContract[market.baseAsset];
        path[1] = getCurrencyContract[market.quoteAsset];

        // TODO: Can't hardcode exec fees
        // May be set it as part of vault parameters
        // Or read from a GMX smart contract
        uint256 executionFee = 300000000000000;

        posRouter.createIncreasePosition{value: executionFee}(
            path,
            getCurrencyContract[market.quoteAsset],
            10000000, // TODO: Dunno what this is
            0,
            size,
            isLong,
            price,
            executionFee,
            bytes32(0)
        );
    }

    function setBracketOrders() public {}

    /// @notice Open a Long position with stop loss and take profit
    /// @param rvTokenAmount The amount of rvTokens to claim.
    /// @dev Accrued fees are measured as rvTokens held by the Vault.
    function goLong(uint256 rvTokenAmount) external requiresAuth {
        emit FeesClaimed(msg.sender, rvTokenAmount);

        // Transfer the provided amount of rvTokens to the caller.
        ERC20(this).safeTransfer(msg.sender, rvTokenAmount);
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
                    APPROVAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the Vault, enabling it to receive deposits.
    /// @dev All critical parameters must already be set before calling.
    function approve() external requiresAuth {
        IRouter router = IRouter(ROUTER);
        router.approvePlugin(POSITION_ROUTER);
        // Approve router to spend USDC
        asset.approve(ROUTER, 1e18); // TODO: Approve upto MAX spend limit
    }

    /*///////////////////////////////////////////////////////////////
                          RECIEVE ETHER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Required for the Vault to receive unwrapped ETH.
    receive() external payable {}
}
