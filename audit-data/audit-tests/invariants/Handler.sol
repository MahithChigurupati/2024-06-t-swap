// SPDX-License-Identifier: GNU General Public License v3.0
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";

import { TSwapPool } from "../../src/TSwapPool.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    TSwapPool public pool;
    ERC20Mock public weth;
    ERC20Mock public token;

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    uint256 public actualDeltaWeth;
    uint256 public actualDeltaToken;

    uint256 public expectedDeltaWeth;
    uint256 public expectedDeltaToken;

    uint256 startingWeth;
    uint256 startingToken;

    constructor(address _tswapPool, address _weth, address _token) {
        pool = TSwapPool(_tswapPool);
        weth = ERC20Mock(_weth);
        token = ERC20Mock(_token);
    }

    function deposit(uint256 wethToDeposit) public {
        bound(wethToDeposit, pool.getMinimumWethDepositAmount(), type(uint64).max);
        uint256 poolTokenToDeposit = pool.getPoolTokensToDepositBasedOnWeth(wethToDeposit);

        startingWeth = weth.balanceOf(address(pool));
        startingToken = token.balanceOf(address(pool));

        expectedDeltaToken = poolTokenToDeposit;
        expectedDeltaWeth = wethToDeposit;

        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, wethToDeposit);
        token.mint(liquidityProvider, poolTokenToDeposit);

        weth.approve(address(pool), wethToDeposit);
        token.approve(address(pool), poolTokenToDeposit);

        pool.deposit(wethToDeposit, 0, poolTokenToDeposit, uint64(block.timestamp));
        vm.stopPrank();

        actualDeltaWeth = weth.balanceOf(address(pool)) - startingWeth;
        actualDeltaToken = token.balanceOf(address(pool)) - startingToken;
    }

    function swap(uint256 outputWethAmount) public {
        bound(outputWethAmount, 0, weth.balanceOf(address(pool)));
        uint256 inputTokenAmount = pool.getInputAmountBasedOnOutput(
            outputWethAmount, token.balanceOf(address(pool)), weth.balanceOf(address(pool))
        );

        startingWeth = weth.balanceOf(address(pool));
        startingToken = token.balanceOf(address(pool));

        expectedDeltaWeth = weth.balanceOf(address(pool)) - outputWethAmount;
        expectedDeltaToken = token.balanceOf(address(pool)) + inputTokenAmount;

        vm.prank(user);
        token.mint(user, inputTokenAmount);
        token.approve(address(pool), inputTokenAmount);
        pool.swapExactOutput(token, weth, outputWethAmount, uint64(block.timestamp));
        vm.stopPrank();

        actualDeltaWeth = weth.balanceOf(address(pool)) - startingWeth;
        actualDeltaToken = token.balanceOf(address(pool)) - startingToken;
    }
}
