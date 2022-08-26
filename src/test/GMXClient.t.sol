// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "ds-test/test.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import "../modules/GMXClient.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract GMXClientTest is DSTestPlus, Script {
    GMXClient gmx;
    ERC20 usdc;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("arb_mainnet")); // Setup fork testing

        gmx = new GMXClient(address(this));
        gmx.approve();

        // Add some eth to the contract
        vm.deal(address(gmx), 1 ether);

        usdc = ERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8); // USDC token address on Arbitrum
        // Transfer some USDC into GMX
        vm.prank(address(usdc));
        usdc.transfer(address(gmx), 10000000000); // TODO: Should remove this!

        // Approve GMX to spend testrunner's USDC
        usdc.approve(address(gmx), type(uint256).max);

        // Approve the Router contract to spend GMX's USDC
        vm.prank(address(gmx));
        usdc.approve(0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064, 1e18);
    }

    /*///////////////////////////////////////////////////////////////
                        ORDER TESTS
    //////////////////////////////////////////////////////////////*/

    function testLongOpenPosition(uint256 price) public {
        // Questions
        // What happens at a very low/high price?
        // What is the units used for price?
        // What are units used for order size?
        // What are units used for collateral?
        // What is the range of collateral I can add?
        Market memory market = Market({quoteAsset: "ETH", baseAsset: "USDC"});
        Order memory buyOrder = Order({
            isBuy: true,
            market: market,
            acceptablePrice: price, //1168294400000000000000000000000000
            size: 10941764059534511257600000000000,
            collateral: 100000
        });

        gmx.openPosition(buyOrder);
    }

    function testShortOpenPosition(uint256 price) public {
        Market memory market = Market({quoteAsset: "ETH", baseAsset: "USDC"});
        Order memory sellOrder = Order({
            isBuy: false,
            market: market,
            acceptablePrice: price,
            size: 10941764059534511257600000000000,
            collateral: 100000
        });

        gmx.openPosition(sellOrder);
    }

    function testShortClosePosition(uint256 price) public {
        Market memory market = Market({quoteAsset: "ETH", baseAsset: "USDC"});
        Order memory sellOrder = Order({
            isBuy: false,
            market: market,
            acceptablePrice: price,
            size: 10941764059534511257600000000000,
            collateral: 100000
        });

        gmx.closePosition(sellOrder);
    }

    /*///////////////////////////////////////////////////////////////
                        BRACKET ORDER TESTS
    //////////////////////////////////////////////////////////////*/

    function testGoShort() public {
        Market memory market = Market({quoteAsset: "ETH", baseAsset: "USDC"});
        Order memory sellOrder = Order({
            isBuy: false,
            market: market,
            acceptablePrice: 1168294400000000000000000000000000,
            size: 10941764059534511257600000000000,
            collateral: 100000
        });
        gmx.goShort(sellOrder, 1, 1);
    }

    function testGoLong(uint256 price) public {
        Market memory market = Market({quoteAsset: "ETH", baseAsset: "USDC"});
        Order memory buyOrder = Order({
            isBuy: true,
            market: market,
            acceptablePrice: price, //1168294400000000000000000000000000
            size: 10941764059534511257600000000000,
            collateral: 100000
        });

        gmx.goLong(buyOrder, 1, 1);
    }

    /*///////////////////////////////////////////////////////////////
                        SECURITY SANITY CHECKS
    //////////////////////////////////////////////////////////////*/

    // TODO: Takes too long. But why?
    // function testFailNonManagerApprove(address rando) public {
    //     vm.assume(rando != address(this)); // Manager is the test runner here so not rando ;)
    //     vm.prank(rando);
    //     gmx.approve();
    // }
}
