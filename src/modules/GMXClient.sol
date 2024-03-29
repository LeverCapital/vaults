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

import {IExchange, Market, Order} from "../interfaces/IExchange.sol";
import {Managed} from "./Managed.sol";

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

    function createDecreasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _acceptablePrice,
        uint256 _minOut,
        uint256 _executionFee,
        bool _withdrawETH
    ) external payable;
}

interface IOrderBook {
    function createDecreaseOrder(
        address _indexToken,
        uint256 _sizeDelta,
        address _collateralToken,
        uint256 _collateralDelta,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external payable;
}

interface IRouter {
    function approvePlugin(address _plugin) external;
}

/// @title Client to interact with the GMX exchange
/// @notice Contains methods to manage positions by Lever vaults
contract GMXClient is Managed {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PositionOpened(Order indexed order);
    event PositionClosed(Order indexed order);

    /*///////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

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

    IPositionRouter internal immutable posRouter;
    IOrderBook internal immutable orderBook;

    /// @notice Deploy this
    constructor(address _manager) Managed(_manager) {
        /// @dev Instantiate the Position Router contract using its address
        posRouter = IPositionRouter(POSITION_ROUTER);
        orderBook = IOrderBook(ORDER_BOOK);
        getCurrencyContract["USDC"] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // Setup logic
        getCurrencyContract["ETH"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    }

    /*///////////////////////////////////////////////////////////////
                                 EXECUTION FEE LOGIC
    //////////////////////////////////////////////////////////////*/

    uint256 executionFee = 100000000000000;

    function setExecFee(uint256 newFee) external onlyManager {
        executionFee = newFee;
    }

    /*///////////////////////////////////////////////////////////////
                                 ORDER LOGIC
    //////////////////////////////////////////////////////////////*/

    mapping(string => address) getCurrencyContract;

    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param order the initial sqrt price of the pool as a Q64.96
    function stopOrder(Order memory order, bool triggerAbovePrice) public onlyManager {
        // TODO: Add an emit event here
        address[] memory path = new address[](2);
        path[0] = getCurrencyContract[order.market.baseAsset];
        // path[1] = getCurrencyContract[order.market.quoteAsset];

        orderBook.createDecreaseOrder{value: executionFee*3}(
            getCurrencyContract[order.market.quoteAsset],
            order.size,
            getCurrencyContract[order.market.quoteAsset],
            0,
            order.isBuy,
            order.acceptablePrice,
            triggerAbovePrice
        );
    }

    bool public positionOpen;

    /// @notice Opens a position on the GMX orderbook
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param order the initial sqrt price of the pool as a Q64.96
    function openPosition(Order memory order) public onlyManager {
        address[] memory path = new address[](2);
        path[0] = getCurrencyContract[order.market.baseAsset];
        path[1] = getCurrencyContract[order.market.quoteAsset];

        posRouter.createIncreasePosition{value: executionFee}( //TODO: who pays the execution fees?
            path,
            getCurrencyContract[order.market.quoteAsset],
            order.collateral,
            0, // TODO: Investigate this (_minOut)
            order.size,
            order.isBuy,
            order.acceptablePrice,
            executionFee,
            bytes32(0)
        );
        positionOpen = true;
        emit PositionOpened(order);
    }

    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param order the initial sqrt price of the pool as a Q64.96
    function closePosition(Order memory order) public onlyManager {
        // TODO: Add an emit event here
        address[] memory path = new address[](2);
        path[0] = getCurrencyContract[order.market.quoteAsset];
        path[1] = getCurrencyContract[order.market.baseAsset];

        posRouter.createDecreasePosition{value: executionFee}(
            path,
            getCurrencyContract[order.market.quoteAsset],
            0,
            order.size,
            order.isBuy,
            address(this),
            order.acceptablePrice,
            0,
            executionFee,
            false
        );
        positionOpen = false;
        emit PositionClosed(order);
    }

    function isAnyPositionOpen() public onlyManager returns (bool) {}

    /*///////////////////////////////////////////////////////////////
                             BRACKET ORDERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Opena a SHORT position with stop loss and take profit triggers
    /// @param order The amount of rvTokens to claim.
    /// @dev Accrued fees are measured as rvTokens held by the Vault.
    function goShort(
        Order memory order,
        uint256 stopLoss,
        uint256 takeProfit
    ) public {
        // TODO: Numerical checks for stoploss, takeprofit
        // Open short position
        openPosition(order); //createIncreasePositions
        // Set stop loss trigger
        order.acceptablePrice = ((100 + stopLoss) / 100) * order.acceptablePrice;
        stopOrder(order, true);
        // Set take profit trigger
        order.acceptablePrice = ((100 - takeProfit) / 100) * order.acceptablePrice;
        stopOrder(order, false);
    }

    /// @notice Opena a SHORT position with stop loss and take profit triggers
    /// @param order The amount of rvTokens to claim.
    /// @dev Accrued fees are measured as rvTokens held by the Vault.
    function goLong(
        Order memory order,
        uint256 stopLoss,
        uint256 takeProfit
    ) public {
        // TODO: Checks for stoploss, takeprofit
        // Open short position
        openPosition(order); //createIncreasePositions
        // Set stop loss trigger
        order.acceptablePrice = ((100 - stopLoss) / 100) * order.acceptablePrice;
        stopOrder(order, false);
        // Set take profit trigger
        order.acceptablePrice = ((100 + takeProfit) / 100) * order.acceptablePrice;
        stopOrder(order, true);
    }

    /*///////////////////////////////////////////////////////////////
                    APPROVAL LOGIC
    //////////////////////////////////////////////////////////////*/
    function approve() public onlyManager {
        IRouter router = IRouter(ROUTER);
        router.approvePlugin(POSITION_ROUTER);
    }
}
