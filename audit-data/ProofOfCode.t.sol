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
}
