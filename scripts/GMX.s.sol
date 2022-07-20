// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/GMX.sol";

contract MyScript is Script {
    function run() external {
        vm.startBroadcast();

        GMX gmx = new GMX();

        vm.stopBroadcast();
    }
}
