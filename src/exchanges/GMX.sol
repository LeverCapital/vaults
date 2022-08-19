// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {IExchange, OrderType, Market} from "../interfaces/IExchange.sol";

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

/// @title Interface to the GMX exchange
/// @notice Contains methods to manage positions by Lever vaults
contract GMX is IExchange {
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

    /// @notice Deploy this
    constructor() {
        /// @dev Instantiate the Position Router contract using its address
        posRouter = IPositionRouter(POSITION_ROUTER);
        // Setup logic
        getCurrencyContract["USDC"] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
        getCurrencyContract["ETH"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        _approveAllPlugins();
    }

    /*///////////////////////////////////////////////////////////////
                                 POSITIONS LOGIC
    //////////////////////////////////////////////////////////////*/

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
        bool isLong = order == OrderType.Buy ? true : false;
        address[] memory path = new address[](2);
        path[0] = getCurrencyContract[market.baseAsset];
        path[1] = getCurrencyContract[market.quoteAsset];

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

    /*///////////////////////////////////////////////////////////////
                                 SETUP LOGIC
    //////////////////////////////////////////////////////////////*/

    function _approveAllPlugins() internal {
        IRouter router = IRouter(ROUTER);
        router.approvePlugin(POSITION_ROUTER);
    }
}
