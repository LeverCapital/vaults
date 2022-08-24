// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {WETH} from "solmate/tokens/WETH.sol";
import {Authority} from "solmate/auth/Auth.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import "forge-std/Script.sol";

import {Vault} from "../Vault.sol";
import {VaultFactory} from "../VaultFactory.sol";
import {IExchange, Market, Order} from "../interfaces/IExchange.sol";

import "forge-std/console.sol";

contract VaultTest is DSTestPlus, Script {
    Vault vault;
    MockERC20 asset;

    function setUp() public {
        asset = new MockERC20("Mock Token", "TKN", 18);

        vault = new VaultFactory().deployVault(asset, "test_strat", "TST");

        vault.setFeePercent(5);

        vault.initialize();
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testAtomicDepositWithdraw() public {
        asset.mint(address(this), 1e18);
        asset.approve(address(vault), 1e18);
        uint256 preDepositBal = asset.balanceOf(address(this));

        vault.deposit(1e18, address(this));
        {
            assertEq(vault.totalAssets(), 1e18);

            assertEq(vault.totalSupply(), 1e18);
            assertEq(vault.convertToShares(1e18), vault.totalSupply());

            assertEq(asset.balanceOf(address(this)), preDepositBal - 1e18);
            assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
        }

        vault.withdraw(1e18, address(this), address(this));
        {
            assertEq(vault.totalSupply(), 0);

            assertEq(vault.totalAssets(), 0);

            assertEq(asset.balanceOf(address(this)), preDepositBal);
        }
    }

    function testDepositWithdraw(uint256 amount) public {
        amount = bound(amount, 1, 1e27);
        asset.mint(address(this), amount);
        asset.approve(address(vault), amount);
        uint256 preDepositBal = asset.balanceOf(address(this));

        vault.deposit(amount, address(this));
        {
            assertEq(vault.totalAssets(), amount);

            assertEq(vault.totalSupply(), amount);
            assertEq(vault.convertToShares(amount), vault.totalSupply());

            assertEq(asset.balanceOf(address(this)), preDepositBal - amount);
            assertEq(vault.convertToAssets(amount), amount);
        }

        vault.withdraw(amount, address(this), address(this));
        {
            assertEq(vault.totalSupply(), 0);

            assertEq(vault.totalAssets(), 0);

            assertEq(asset.balanceOf(address(this)), preDepositBal);
        }
    }

    //     function testAtomicDepositRedeem() public {
    //         asset.mint(address(this), 1e18);
    //         asset.approve(address(vault), 1e18);

    //         uint256 preDepositBal = asset.balanceOf(address(this));

    //         vault.deposit(1e18, address(this));

    //         assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
    //         assertEq(vault.totalAssets(), 1e18);
    //         assertEq(vault.balanceOf(address(this)), 1e18);
    //         assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 1e18);
    //         assertEq(asset.balanceOf(address(this)), preDepositBal - 1e18);

    //         vault.redeem(1e18, address(this), address(this));

    //         assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
    //         assertEq(vault.totalAssets(), 0);
    //         assertEq(vault.balanceOf(address(this)), 0);
    //         assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
    //         assertEq(asset.balanceOf(address(this)), preDepositBal);
    //     }

    //     function testDepositRedeem(uint256 amount) public {
    //         amount = bound(amount, 1e5, 1e27);

    //         asset.mint(address(this), amount);
    //         asset.approve(address(vault), amount);

    //         uint256 preDepositBal = asset.balanceOf(address(this));

    //         vault.deposit(amount, address(this));

    //         assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
    //         assertEq(vault.totalAssets(), amount);
    //         assertEq(vault.balanceOf(address(this)), amount);
    //         assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);
    //         assertEq(asset.balanceOf(address(this)), preDepositBal - amount);

    //         vault.redeem(amount, address(this), address(this));

    //         assertEq(vault.convertToAssets(10**vault.decimals()), 1e18);
    //         assertEq(vault.totalAssets(), 0);
    //         assertEq(vault.balanceOf(address(this)), 0);
    //         assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
    //         assertEq(asset.balanceOf(address(this)), preDepositBal);
    //     }

    /*///////////////////////////////////////////////////////////////
                 DEPOSIT/WITHDRAWAL SANITY CHECK TESTS
    //////////////////////////////////////////////////////////////*/

    function testFailDepositWithNotEnoughApproval(uint256 amount) public {
        asset.mint(address(this), amount / 2);
        asset.approve(address(vault), amount / 2);

        vault.deposit(amount, address(this));
    }

    function testFailWithdrawWithNotEnoughBalance(uint256 amount) public {
        asset.mint(address(this), amount / 2);
        asset.approve(address(vault), amount / 2);

        vault.deposit(amount / 2, address(this));

        vault.withdraw(amount, address(this), address(this));
    }

    function testFailRedeemWithNotEnoughBalance(uint256 amount) public {
        asset.mint(address(this), amount / 2);
        asset.approve(address(vault), amount / 2);

        vault.deposit(amount / 2, address(this));

        vault.redeem(amount, address(this), address(this));
    }

    function testFailWithdrawWithNoBalance(uint256 amount) public {
        if (amount == 0) amount = 1;
        vault.withdraw(amount, address(this), address(this));
    }

    function testFailRedeemWithNoBalance(uint256 amount) public {
        vault.redeem(amount, address(this), address(this));
    }

    function testFailDepositWithNoApproval(uint256 amount) public {
        vault.deposit(amount, address(this));
    }

    /*///////////////////////////////////////////////////////////////
                 DEPOSIT/WITHDRAWAL SECURITY TESTS
    //////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                 VAULT MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function testFailInitializeTwice() public {
        vault.initialize();
    }

    function testDestroyVault() public {
        vault.destroy();
    }
}

contract VaultPositionsTest is DSTestPlus, Script {
    Vault vault;
    ERC20 usdc;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("arb_mainnet")); // Setup fork testing

        usdc = ERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8); // USDC token address on Arbitrum

        vault = new VaultFactory().deployVault(usdc, "test_strat", "TST");

        vault.setFeePercent(5);

        vault.initialize(); // Open for deposits/withdrawals

        vault.approve(); // Open for trading!

        // Add some eth to the contract
        vm.deal(address(vault), 1 ether);
        // Deposit some USDC in the vault
        vm.prank(address(usdc));
        usdc.transfer(address(this), 1e10);
        usdc.approve(address(vault), 1e18);
        vault.deposit(1e10, address(this));
    }

    /*///////////////////////////////////////////////////////////////
                        POSITIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function testGoShort(uint256 price) public {
        Market memory market = Market({quoteAsset: "ETH", baseAsset: "USDC"});
        Order memory sellOrder = Order({
            isBuy: false,
            market: market,
            acceptablePrice: price, //1168294400000000000000000000000000
            size: 10941764059534511257600000000000,
            collateral: 100000
        });

        vault.goShort(sellOrder, 1, 1);
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

        vault.goLong(buyOrder, 1, 1);
    }
}
