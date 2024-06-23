// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { Test, StdInvariant } from "forge-std/Test.sol";

import { TSwapPool } from "../../src/TSwapPool.sol";
import { PoolFactory } from "../../src/PoolFactory.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { Handler } from "./Handler.sol";

contract Invariant is StdInvariant, Test {
    TSwapPool public pool;
    PoolFactory public factory;
    ERC20Mock public token;
    ERC20Mock public weth;
    Handler public handler;

    address liquidityProvider = makeAddr("liquidityProvider");

    uint256 public STARTING_WETH = 100 ether;
    uint256 public STARTING_TOKEN = 50 ether;

    function setUp() public {
        factory = new PoolFactory(address(weth));

        weth = new ERC20Mock();
        token = new ERC20Mock();

        pool = TSwapPool(factory.createPool(address(token)));

        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, STARTING_WETH);
        token.mint(liquidityProvider, STARTING_TOKEN);
        pool.deposit(STARTING_WETH, STARTING_WETH, STARTING_TOKEN, uint64(block.timestamp));

        handler = new Handler(address(pool), address(weth), address(token));

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = handler.deposit.selector;
        selectors[1] = handler.swap.selector;

        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
        targetContract(address(handler));
    }

    function stateful_InvariantX() public view {
        assertEq(handler.actualDeltaWeth(), handler.expectedDeltaWeth());
    }

    function stateful_InvariantY() public view {
        assertEq(handler.actualDeltaToken(), handler.expectedDeltaToken());
    }
}
