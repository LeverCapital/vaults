// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {IExchange, Market, Order} from "../interfaces/IExchange.sol";

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

/// @title Interface to the GMX exchange
/// @notice Contains methods to manage positions by Lever vaults
contract GMX {
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
    constructor() {
        /// @dev Instantiate the Position Router contract using its address
        posRouter = IPositionRouter(POSITION_ROUTER);
        orderBook = IOrderBook(ORDER_BOOK);
        getCurrencyContract["USDC"] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // Setup logic
        getCurrencyContract["ETH"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    }

    /*///////////////////////////////////////////////////////////////
                                 ORDER LOGIC
    //////////////////////////////////////////////////////////////*/

    mapping(string => address) getCurrencyContract;

    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param order the initial sqrt price of the pool as a Q64.96
    function stopOrder(Order memory order, bool triggerAbovePrice) public {
        // TODO: Add an emit event here
        address[] memory path = new address[](2);
        path[0] = getCurrencyContract[order.market.baseAsset];
        // path[1] = getCurrencyContract[order.market.quoteAsset];

        // TODO: Can't hardcode exec fees
        // May be set it as part of vault parameters
        // Or read from a GMX smart contract
        uint256 executionFee = 300000000000000;

        orderBook.createDecreaseOrder{value: executionFee}(
            getCurrencyContract[order.market.quoteAsset],
            order.size,
            getCurrencyContract[order.market.quoteAsset],
            0,
            order.isBuy,
            order.acceptablePrice,
            triggerAbovePrice
        );
    }

    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param order the initial sqrt price of the pool as a Q64.96
    function openPosition(Order memory order) public {
        // TODO: Add an emit event here
        address[] memory path = new address[](2);
        path[0] = getCurrencyContract[order.market.baseAsset];
        path[1] = getCurrencyContract[order.market.quoteAsset];

        // TODO: Can't hardcode exec fees
        // May be set it as part of vault parameters
        // Or read from a GMX smart contract
        uint256 executionFee = 300000000000000;

        posRouter.createIncreasePosition{value: executionFee}(
            path,
            getCurrencyContract[order.market.quoteAsset],
            order.collateral,
            0, // TODO: Investigate this
            order.size,
            order.isBuy,
            order.acceptablePrice,
            executionFee,
            bytes32(0)
        );
    }

    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param order the initial sqrt price of the pool as a Q64.96
    function closePosition(Order memory order) public {
        // TODO: Add an emit event here
        address[] memory path = new address[](2);
        path[0] = getCurrencyContract[order.market.baseAsset];
        // path[1] = getCurrencyContract[order.market.quoteAsset];

        // TODO: Can't hardcode exec fees
        // May be set it as part of vault parameters
        // Or read from a GMX smart contract
        uint256 executionFee = 300000000000000;

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
    }

    /*///////////////////////////////////////////////////////////////
                    APPROVAL LOGIC
    //////////////////////////////////////////////////////////////*/
    function approve() external {
        IRouter router = IRouter(ROUTER);
        router.approvePlugin(POSITION_ROUTER);
    }
}
