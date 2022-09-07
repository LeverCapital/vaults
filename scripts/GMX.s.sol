// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {GMXClient, IPositionRouter, IRouter} from "../src/modules/GMXClient.sol";
import {IExchange, Market, Order} from "../src/interfaces/IExchange.sol";
import {Vault} from "../src/Vault.sol";

import "forge-std/console.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

// Setup method before we can start placing orders on GMX
contract approveOrderBook is Script {
    function run() external {
        vm.startBroadcast();
        address ROUTER = 0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064;

        IRouter router = IRouter(ROUTER);
        router.approvePlugin(0x3D6bA331e3D9702C5e8A8d254e5d8a285F223aba);

        vm.stopBroadcast();
    }
}

contract marketBuyOrder is Script {
    function run() external {
        vm.startBroadcast();
        address POSITION_ROUTER = 0x3D6bA331e3D9702C5e8A8d254e5d8a285F223aba;

        IPositionRouter posRouter = IPositionRouter(POSITION_ROUTER);
        address[] memory path = new address[](2);
        path[0] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
        path[1] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

        uint256 executionFee = 300000000000000;

        posRouter.createIncreasePosition{value: executionFee}(
            path,
            0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            10000000,
            0,
            10941764059534511257600000000000,
            true,
            1168294400000000000000000000000000,
            executionFee, /// Dunno how much to put this
            bytes32(0)
        );

        vm.stopBroadcast();
    }
}

contract runGMXClient is GMXClient, Script {
    constructor() GMXClient(msg.sender) {
        approve();
        setManager(0x17C562B0E8Fa75354C1b45F4f5dD8a2b6f38d663);
    }

    function run() external {
        Market memory market = Market({quoteAsset: "ETH", baseAsset: "USDC"});
        Order memory order = Order({
            isBuy: false,
            market: market,
            acceptablePrice: 1168294400000000000000000000000000,
            size: 10941764059534511257600000000000,
            collateral: 100000
        });
        ERC20 usdc = ERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8); // USDC token address on Arbitrum

        // Approve GMX to spend user's funds
        vm.startBroadcast(0x17C562B0E8Fa75354C1b45F4f5dD8a2b6f38d663);
        usdc.approve(address(this), 3e45);
        usdc.transfer(address(this), 100000);
        vm.stopBroadcast();
        vm.startBroadcast();
        // Transfer some USDC into GMX
        // usdc.transferFrom(msg.sender, address(this), 100000);

        goShort(order, 1, 1);
        vm.stopBroadcast();
    }
}

interface IVault {
    function openPosition(Order memory order) external;

    function closePosition(Order memory order) external;
}

contract runOpenPosition is Script {
    function run() external {
        vm.startBroadcast();
        Market memory market = Market({quoteAsset: "ETH", baseAsset: "USDC"});
        Order memory order = Order({
            isBuy: false,
            market: market,
            acceptablePrice: 1168294400000000000000000000000000,
            size: 10941764059534511257600000000000,
            collateral: 100000
        });
        address VAULT = 0x916B9Eb0605945400Ab1dba4d74997c9688d8fC4;
        IVault v = IVault(VAULT);
        v.openPosition(order);
        vm.stopBroadcast();
    }
}

contract runClosePosition is Script {
    function run() external {
        vm.startBroadcast();
        Market memory market = Market({quoteAsset: "ETH", baseAsset: "USDC"});
        Order memory order = Order({
            isBuy: false,
            market: market,
            acceptablePrice: 1168294400000000000000000000000000,
            size: 10941764059534511257600000000000,
            collateral: 100000
        });
        address VAULT = 0x916B9Eb0605945400Ab1dba4d74997c9688d8fC4;
        IVault v = IVault(VAULT);
        v.closePosition(order);
        vm.stopBroadcast();
    }
}

// abstract contract runGoShort is Script {
//     function run() external {
//         // Open short position
//         address POSITION_ROUTER = 0x3D6bA331e3D9702C5e8A8d254e5d8a285F223aba;
//         IPositionRouter posRouter = IPositionRouter(POSITION_ROUTER);
//         address[] memory path = new address[](2);
//         path[0] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
//         path[1] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

//         // TODO: Can't hardcode exec fees
//         // May be set it as part of vault parameters
//         // Or read from a GMX smart contract
//         uint256 executionFee = 300000000000000;

//         posRouter.createIncreasePosition{value: executionFee}(
//             path,
//             0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
//             order.collateral,
//             0, // TODO: Investigate this
//             order.size,
//             order.isBuy,
//             order.acceptablePrice,
//             executionFee,
//             bytes32(0)
//         );

//         // Set stop loss trigger
//         order.acceptablePrice = ((100 + 1) / 100) * order.acceptablePrice;
//         orderBook.createDecreaseOrder{value: executionFee}(
//             getCurrencyContract[order.market.quoteAsset],
//             order.size,
//             getCurrencyContract[order.market.quoteAsset],
//             0,
//             order.isBuy,
//             order.acceptablePrice,
//             false
//         );
//         // Set take profit trigger
//         order.acceptablePrice = ((100 - 1) / 100) * order.acceptablePrice;
//         stopOrder(order, false);
//     }
// }
