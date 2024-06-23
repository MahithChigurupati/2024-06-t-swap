// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { PoolFactory } from "../../src/PoolFactory.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { TSwapPool } from "../../src/PoolFactory.sol";

contract TSwapTest is Test {
    PoolFactory factory;
    ERC20Mock mockWeth;
    ERC20Mock tokenA;
    ERC20Mock tokenB;

    function setUp() public {
        mockWeth = new ERC20Mock();
        factory = new PoolFactory(address(mockWeth));
        tokenA = new ERC20Mock();
        tokenB = new ERC20Mock();
    }

    function testZeroWethAddress() public {
        factory = new PoolFactory(address(0));
        TSwapPool pool = TSwapPool(factory.createPool(address(0)));

        assertEq(address(pool.getWeth()), address(0));
        assertEq(address(pool.getPoolToken()), address(0));

        vm.expectRevert();
        pool.deposit(1 ether, 1 ether, 1 ether, uint64(block.timestamp));
    }

    function testswapExactOutputIsWrong() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        address user1 = makeAddr("user1");
        poolToken.mint(user1, 100e18);

        vm.startPrank(user1);
        poolToken.approve(address(pool), 100e18);

        // what is 0.3% of 1e18 = 3e15
        // so, we need to pay tokenA of 1e18 + 3e15 = 1.003e18 in exchange of 1 weth
        // user1 starts with balance of 100e18. so, after swap, user balance must be -
        // 100e18 - 1.003e18 = 98.997e18

        pool.swapExactOutput(poolToken, weth, 1e18, uint64(block.timestamp));

        // so expected is - 98.997e18, lets see what we got -
        console.log(poolToken.balanceOf(user1));

        // user1 must have greater than 98e18 atleast, but he has less than that -
        assertFalse(poolToken.balanceOf(user1) > 98e18);
    }

    // function testSellPoolTokens() public {
    //     vm.startPrank(liquidityProvider);
    //     weth.approve(address(pool), 100e18);
    //     poolToken.approve(address(pool), 100e18);
    //     // deposit 50 weth and 100 pool tokens
    //     pool.deposit(50e18, 100e18, 100e18, uint64(block.timestamp));
    //     vm.stopPrank();

    //     // user has got 100 pool tokens and 100 weth
    //     uint256 tokenbalanceBefore = 10e18;
    //     uint256 wethbalanceBefore = 5e18;

    //     address user1 = makeAddr("user1");
    //     poolToken.mint(user1, tokenbalanceBefore);
    //     weth.mint(user1, wethbalanceBefore);

    //     vm.startPrank(user1);
    //     poolToken.approve(address(pool), tokenbalanceBefore);
    //     weth.approve(address(pool), wethbalanceBefore);

    //     console.log(poolToken.balanceOf(user1));
    //     console.log(weth.balanceOf(user1));

    //     // user1 wants to sell 1 pool token for weth
    //     pool.sellPoolTokens(1e18);

    //     console.log(poolToken.balanceOf(user1));
    //     console.log(weth.balanceOf(user1));

    //     // so, now user must have more weth and less pool tokens than before the sell
    //     // but he has less weth and more pool tokens than before the sell
    //     // which means he sold weth for pool tokens instead of pool tokens for weth
    //     // assertFalse(weth.balanceOf(user1) > wethbalanceBefore);
    //     // assertFalse(poolToken.balanceOf(user1) < tokenbalanceBefore);
    // }
}
