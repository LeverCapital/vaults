// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/GMX.sol";
import "forge-std/console.sol";

interface IRouter {
    function approvePlugin(address _plugin) external;
}

// Setup method before we can start placing orders on GMX
contract approveOrderBook is Script {
    function run() external {
        vm.startBroadcast();
        address ROUTER = 0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064;

        IRouter router = IRouter(ROUTER);
        address orderBook = 0x09f77E8A13De9a35a7231028187e9fD5DB8a2ACB;

        router.approvePlugin(orderBook);

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
        console.log();

        vm.stopBroadcast();
    }
}

interface IVault {
    function poolAmounts(address _token) external view returns (uint256);
}

contract getPoolAmount is Script {
    function run() external {
        vm.startBroadcast();
        address VAULT = 0x489ee077994B6658eAfA855C308275EAd8097C4A;

        IVault v = IVault(VAULT);
        console.log(v.poolAmounts(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8));

        vm.stopBroadcast();
    }
}
