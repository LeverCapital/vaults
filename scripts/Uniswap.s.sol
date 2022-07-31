// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/GMX.sol";
import "forge-std/console.sol";

interface IUniswapV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);
}

contract getPoolInfo is Script {
    function run() external {
        vm.startBroadcast();
        address FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
        IUniswapV3Factory factory = IUniswapV3Factory(FACTORY);

        address eth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        address usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
        address pool = factory.getPool(eth, usdc, 3000);
        console.log(pool);
        vm.stopBroadcast();
    }
}
