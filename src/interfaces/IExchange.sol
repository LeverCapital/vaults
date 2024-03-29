// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

struct Market {
    string quoteAsset;
    string baseAsset;
}

struct Order {
    bool isBuy;
    Market market;
    uint256 acceptablePrice;
    uint256 size;
    uint256 collateral;
}

/// @title Interface for any Perp trading exchange
/// @notice Contains methods to manage positions
interface IExchange {
    /// @notice Open a Long/short position
    /// @dev This method creates a market order
    /// @param price Create an order at this price or 'better'
    function openPosition(
        Market calldata market,
        uint256 price,
        uint256 size
    ) external;

    /// @notice Close a Long/short position
    /// @dev This method creates a market order
    /// @param price Create an order at this price or 'better'
    // function closePosition(
    //     OrderType order,
    //     Market calldata market,
    //     uint256 price,
    //     uint256 size
    // ) external;
    // function openPositionAt(uint160 sqrtPriceX96) external;
} // function closePositionAt(uint160 sqrtPriceX96) external;
