// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

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
    ) external;
}

/// @title Interface for any Perp trading exchange
/// @notice Contains methods to manage positions by Lever vaults
contract GMX is IExchange {
    /*///////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of PositionRouter contract
    /// @dev Used to interact with the contract and manage positions
    address internal constant POSITION_ROUTER = 0x3D6bA331e3D9702C5e8A8d254e5d8a285F223aba;

    /*///////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    IPositionRouter internal immutable posRouter;

    /// @notice Deploy this
    constructor() {
        /// @dev Instantiate the Position Router contract using its address
        posRouter = IPositionRouter(POSITION_ROUTER);
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
        address[] memory path;
        path[0] = getCurrencyContract[market.baseAsset];
        path[1] = getCurrencyContract[market.quoteAsset];

        posRouter.createIncreasePosition(
            path,
            getCurrencyContract[market.quoteAsset],
            price,
            0,
            size,
            isLong,
            price,
            300000000000000, /// Dunno how much to put this
            bytes32(0)
        );
    }
}
