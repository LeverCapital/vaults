// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "ds-test/test.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import "../GMX.sol";

contract GMXTest is DSTestPlus, Script {
    GMX gmx;

    function setUp() public {
        gmx = new GMX();
        // Add some eth to the contract
        vm.deal(address(gmx), 1 ether);
        // TODO: Add some ERC20 too!
    }

    // /*///////////////////////////////////////////////////////////////
    //                     SETUP TESTS
    // //////////////////////////////////////////////////////////////*/

    // function testOrderBookApproved() public {
    //     IRouter router = IRouter(gmx.ROUTER);
    //     gmx.approveOrderBook();
    //     assert(router.approvedPlugins
    // }

    /*///////////////////////////////////////////////////////////////
                        POSITIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function testLongOpenPosition() public {
        Market memory market = Market({quoteAsset: "ETH", baseAsset: "USDC"});
        gmx.openPosition(OrderType.Buy, market, 1168294400000000000000000000000000, 10941764059534511257600000000000);
    }
}
