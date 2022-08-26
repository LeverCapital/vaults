// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {GMXClient, IPositionRouter, IRouter} from "../src/modules/GMXClient.sol";
import {IExchange, Market, Order} from "../src/interfaces/IExchange.sol";
import {Vault} from "../src/Vault.sol";

import "forge-std/console.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract deployVault is Script {
    function run() external {
        vm.startBroadcast();
        ERC20 usdc = ERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

        Vault vault = new Vault(usdc, "Test Vault", "TST", msg.sender, msg.sender);

        vm.stopBroadcast();
    }
}
