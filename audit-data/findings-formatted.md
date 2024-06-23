---
title: TSwap Protocol Audit Report
author: mahithchigurupati.me
date: June 22, 2024
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---

\begin{titlepage}
    \centering
    \begin{figure}[h]
        \centering
        \includegraphics[width=0.5\textwidth]{logo.pdf} 
    \end{figure}
    \vspace*{2cm}
    {\Huge\bfseries TSwap Protocol Audit Report\par}
    \vspace{1cm}
    {\Large Version 1.0\par}
    \vspace{2cm}
    {\Large\itshape mahithchigurupati.me\par}
    \vfill
    {\large \today\par}
\end{titlepage}

\maketitle

<!-- Your report starts here! -->

Prepared by: [Mahith](https://x.com/0xmahith)

</br>
Lead Auditors: 
- Mahith

# Table of Contents
- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
  - [TSwap](#tswap)
  - [TSwap Pools](#tswap-pools)
  - [Liquidity Providers](#liquidity-providers)
  - [Why would I want to add tokens to the pool?](#why-would-i-want-to-add-tokens-to-the-pool)
  - [LP Example](#lp-example)
  - [Core Invariant](#core-invariant)
  - [Make a swap](#make-a-swap)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
- [High](#high)
  - [\[H-1\] `TSwapPool::getInputAmountBasedOnOutput()` calculates pool fee as a wrong value, thereby taking more tokens than intended from caller](#h-1-tswappoolgetinputamountbasedonoutput-calculates-pool-fee-as-a-wrong-value-thereby-taking-more-tokens-than-intended-from-caller)
  - [\[H-2\] `TSwapPool::_swap()` is giving away extra tokens, breaking system's invariant property](#h-2-tswappool_swap-is-giving-away-extra-tokens-breaking-systems-invariant-property)
  - [\[H-3\] `sellPoolTokens` is calculating w.r.to output instead of input](#h-3-sellpooltokens-is-calculating-wrto-output-instead-of-input)
  - [\[H-4\] `TSwapPool::swapExactOutput()` function is missing slippage protection check, causing caller to get less tokens than they expect](#h-4-tswappoolswapexactoutput-function-is-missing-slippage-protection-check-causing-caller-to-get-less-tokens-than-they-expect)
  - [\[H-5\] `TSwapPool::deposit()` doesn't take `deadline` parameter into consideration, causing depositors to get unexpected lp token value for their deposit](#h-5-tswappooldeposit-doesnt-take-deadline-parameter-into-consideration-causing-depositors-to-get-unexpected-lp-token-value-for-their-deposit)
- [Medium](#medium)
  - [\[M-1\] weird-ERC20, ERC777 can break protocol invariant](#m-1-weird-erc20-erc777-can-break-protocol-invariant)
- [Low](#low)
  - [\[L-1\] `PoolFactory()::constructor()` must have a zero check, to avoid pool creation with `address(0)`](#l-1-poolfactoryconstructor-must-have-a-zero-check-to-avoid-pool-creation-with-address0)
  - [\[L-2\] Incorrect parameter logs in `TSwapPool::LiquidityAdded` event](#l-2-incorrect-parameter-logs-in-tswappoolliquidityadded-event)
  - [\[L-3\] `swapExactInput` doesn't return expected `output` value](#l-3-swapexactinput-doesnt-return-expected-output-value)
- [Informational/ Non-critical](#informational-non-critical)
  - [\[I-1\] Test Coverage](#i-1-test-coverage)
  - [\[I-2\] `public` functions not used internally could be marked `external`](#i-2-public-functions-not-used-internally-could-be-marked-external)
  - [\[I-3\] Define and use `constant` variables instead of using literals](#i-3-define-and-use-constant-variables-instead-of-using-literals)
  - [\[I-4\] Event is missing `indexed` fields](#i-4-event-is-missing-indexed-fields)
  - [\[I-5\] PUSH0 is not supported by all chains](#i-5-push0-is-not-supported-by-all-chains)
  - [\[I-6\] Large literal values multiples of 10000 can be replaced with scientific notation](#i-6-large-literal-values-multiples-of-10000-can-be-replaced-with-scientific-notation)
  - [\[I-7\] Unused Custom Error](#i-7-unused-custom-error)
  - [\[I-8\] Follow CEI](#i-8-follow-cei)

# Protocol Summary

## TSwap

This project is meant to be a permissionless way for users to swap assets between each other at a fair price. You can think of T-Swap as a decentralized asset/token exchange (DEX). 
T-Swap is known as an [Automated Market Maker (AMM)](https://chain.link/education-hub/what-is-an-automated-market-maker-amm) because it doesn't use a normal "order book" style exchange, instead it uses "Pools" of an asset. 
It is similar to Uniswap. To understand Uniswap, please watch this video: [Uniswap Explained](https://www.youtube.com/watch?v=DLu35sIqVTM)

## TSwap Pools
The protocol starts as simply a `PoolFactory` contract. This contract is used to create new "pools" of tokens. It helps make sure every pool token uses the correct logic. But all the magic is in each `TSwapPool` contract. 

You can think of each `TSwapPool` contract as it's own exchange between exactly 2 assets. Any ERC20 and the [WETH](https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2) token. These pools allow users to permissionlessly swap between an ERC20 that has a pool and WETH. Once enough pools are created, users can easily "hop" between supported ERC20s. 

For example:
1. User A has 10 USDC
2. They want to use it to buy DAI
3. They `swap` their 10 USDC -> WETH in the USDC/WETH pool
4. Then they `swap` their WETH -> DAI in the DAI/WETH pool

Every pool is a pair of `TOKEN X` & `WETH`. 

There are 2 functions users can call to swap tokens in the pool. 
- `swapExactInput`
- `swapExactOutput`

We will talk about what those do in a little. 

## Liquidity Providers
In order for the system to work, users have to provide liquidity, aka, "add tokens into the pool". 

## Why would I want to add tokens to the pool? 
The TSwap protocol accrues fees from users who make swaps. Every swap has a `0.3` fee, represented in `getInputAmountBasedOnOutput` and `getOutputAmountBasedOnInput`. Each applies a `997` out of `1000` multiplier. That fee stays in the protocol. 

When you deposit tokens into the protocol,  you are rewarded with an LP token. You'll notice `TSwapPool` inherits the `ERC20` contract. This is because the `TSwapPool` gives out an ERC20 when Liquidity Providers (LP)s deposit tokens. This represents their share of the pool, how much they put in. When users swap funds, 0.03% of the swap stays in the pool, netting LPs a small profit. 

## LP Example
1. LP A adds 1,000 WETH & 1,000 USDC to the USDC/WETH pool
   1. They gain 1,000 LP tokens
2. LP B adds 500 WETH & 500 USDC to the USDC/WETH pool 
   1. They gain 500 LP tokens
3. There are now 1,500 WETH & 1,500 USDC in the pool
4. User A swaps 100 USDC -> 100 WETH. 
   1. The pool takes 0.3%, aka 0.3 USDC.
   2. The pool balance is now 1,400.3 WETH & 1,600 USDC
   3. aka: They send the pool 100 USDC, and the pool sends them 99.7 WETH

Note, in practice, the pool would have slightly different values than 1,400.3 WETH & 1,600 USDC due to the math below. 

## Core Invariant 

Our system works because the ratio of Token A & WETH will always stay the same. Well, for the most part. Since we add fees, our invariant technially increases. 

`x * y = k`

- x = Token Balance X
- y = Token Balance Y
- k = The constant ratio between X & Y

Our protocol should always follow this invariant in order to keep swapping correctly!

## Make a swap

After a pool has liquidity, there are 2 functions users can call to swap tokens in the pool. 
- `swapExactInput`
- `swapExactOutput`

A user can either choose exactly how much to input (ie: I want to use 10 USDC to get however much WETH the market says it is), or they can choose exactly how much they want to get out (ie: I want to get 10 WETH from however much USDC the market says it is. 

*This codebase is based loosely on [Uniswap v1](https://github.com/Uniswap/v1-contracts/tree/master)*

# Disclaimer

Mahith makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details 

NA

## Scope 

- Commit Hash: XXX
- In Scope:
```
./src/
#-- PoolFactory.sol
#-- TSwapPool.sol
```
- Solc Version: 0.8.20
- Chain(s) to deploy contract to: Ethereum
- Tokens:
  - Any ERC20 token

## Roles

- Liquidity Providers: Users who have liquidity deposited into the pools. Their shares are represented by the LP ERC20 tokens. They gain a 0.3% fee every time a swap is made. 
- Users: Users who want to swap tokens.


# Executive Summary

NA

## Issues found

| Severity | Number of issues found |
| -------- | ---------------------- |
| High     | 5                      |
| Medium   | 1                      |
| Low      | 3                      |
| Info     | 8                      |
| Total    | 17                     |

# Findings
# High

## [H-1] `TSwapPool::getInputAmountBasedOnOutput()` calculates pool fee as a wrong value, thereby taking more tokens than intended from caller

**Description:** 

`TSwapPool::swapExactOutput` calls `TSwapPool::getInputAmountBasedOnOutput` to get input amount to supply based on output amount expected, but the function `getInputAmountBasedOnOutput` calculate fee with an error. The actual fee expected by the protocol is 0.3% of the swap amount requested. But, this function is calculating fee as 90.3% of the swap thereby taking away more amount than user expects.

**Impact:**
user loses 90% more tokens as fee than what protocol says i.e., 0.3% thereby user lose of funds for user.

**Proof of Concept:**

Place below code in `Tswap.t.sol` and run `forge test --mt testswapExactOutputIsWrong`

```javascript
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
```

**Recommended Mitigation:** 

Make below code changes in `TSwapPool.sol`

```diff
    function getInputAmountBasedOnOutput(
        ...
    )
        ...
    {
-        return ((inputReserves * outputAmount) * 10000) / ((outputReserves - outputAmount) * 997);
+        return ((inputReserves * outputAmount) * 1000) / ((outputReserves - outputAmount) * 997);

    }
``` 


## [H-2] `TSwapPool::_swap()` is giving away extra tokens, breaking system's invariant property

**Description:**
for every 10 swaps, there is an additional transfer of 1 ether to the swapper hence, the protocol invariant breaks

**Impact:**
protocol breaks and becomes unusable if invariant breaks.

**Proof of Concept:**

<details>
<summary> code </summary>

Place below code in `test/invariants/Invariant.t.sol`

```javascript
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

```

Place below code in `test/invariants/Handler.sol`

```javascript
// SPDX-License-Identifier: MIT
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

```

Now run `forge test --mt stateful_InvariantX` and `forge test --mt stateful_InvariantY` to see if invariant breaks or no.

</details>

**Recommended Mitigation:** 

Make below code changes in `TSwapPool.sol`

```diff
    function _swap(
        ...
    ) private {
        ...

-       swap_count++;
-       if (swap_count >= SWAP_COUNT_MAX) {
-           swap_count = 0;
-           outputToken.safeTransfer(msg.sender, 1_000_000_000_000_000_000);
-       }

        emit Swap(msg.sender, inputToken, inputAmount, outputToken, outputAmount);

        inputToken.safeTransferFrom(msg.sender, address(this), inputAmount);
        outputToken.safeTransfer(msg.sender, outputAmount);
    }
```

## [H-3] `sellPoolTokens` is calculating w.r.to output instead of input

**Description:** 
`TSwapPoolTokens:sellPoolTokens()` is called by user expecting protocol to give him weth by taking in his pool tokens i.e., he is trying to see pool tokens. instead, the `sellPoolTokens` is calling `swapExactOutput()` instead of `swapExactInput` considering user is inputing exact input tokens he wants to sell.

Also, the function should have a slippage protection additionally to protect user's from MEV attacks or any inflationary/deflationary attacks to help user get the value what he's expecting to get.

**Recommended Mitigation:** 

Make below code changes in `TSwapPool.sol`

```diff

    function sellPoolTokens(
        uint256 poolTokenAmount
    ) external returns (uint256 wethAmount) {
        return
-            swapExactOutput(...);
+            swapExactInput(...);
    }

```

## [H-4] `TSwapPool::swapExactOutput()` function is missing slippage protection check, causing caller to get less tokens than they expect

**Description:** 
`TSwapPool::swapExactOutput` function doesn't have a slippage protection check to help users get the value that they are expecting to get in return of swap. 

Not having the check will let user submit a transaction without knowing what he's expecting to get out of the pool hence, an attacker or MEV bot who sees the transaction may place an order just before the swapper to manipulate the pool or even a big whale may place an order that changes the value of pool immensely thereby swapper getting the less tokens than he intended to get.

**Impact:** 
pool takes in more tokens than what user want to spend for the output he places the order for.

**Recommended Mitigation:** 

```diff
    function swapExactOutput(
        IERC20 inputToken,
+       uint256 maxInputTokens
        IERC20 outputToken,
        uint256 outputAmount,
        uint64 deadline
    )
        ...
    {
        uint256 inputReserves = inputToken.balanceOf(address(this));
        uint256 outputReserves = outputToken.balanceOf(address(this));

        inputAmount = getInputAmountBasedOnOutput(
            outputAmount,
            inputReserves,
            outputReserves
        );

+       if(inputAmount > maxInputTokens){
+           revert TSwapPool__InputTooLow(inputAmount, maxInputTokens);
        }

        _swap(inputToken, inputAmount, outputToken, outputAmount);
    }
```

## [H-5] `TSwapPool::deposit()` doesn't take `deadline` parameter into consideration, causing depositors to get unexpected lp token value for their deposit

**Description:** 
1. When user expects a `deposit` transaction to be executed before an x block.timestamp by passing the deadline to get his expected price of lp token from the pool, there is a possibility that tx can be executed at later point after deadline expires hence provising depositor with a lp token of value that he didn't expect.

2. Also, MEV can take advantage of this bug to inflate/deflate the pool before depositor's transaction to make good profit causing loss to depositor by making his tx execute at later point after deadline expires.

**Impact:** 
depositor receives unfair and unexpected value for his deposit.

**Proof of Concept:**

Place below code in `TswapPool.t.sol` and run `forge test --mt testDepositAfterDeadline`

```javascript
    function testDepositAfterDeadline() public {
        vm.warp(10);
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        assertEq(block.timestamp, 10);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp) + 1000);

        assertEq(pool.balanceOf(liquidityProvider), 100e18);
    }
```

**Recommended Mitigation:** 

Make below code changes in `TSwapPool.sol`

```diff
    function deposit(
        ...
        uint64 deadline
    )
        ...
+        revertIfDeadlinePassed(deadline)
    {
        ...
        
    

```

# Medium


## [M-1] weird-ERC20, ERC777 can break protocol invariant

**Description:** 
1. `ERC777` will have hooks that execute before and after a transaction. This might cause some intended behavior to happen.
2. `weird-erc20` - for eg., `USDT` is weird during transfers, not providing a return value for transaction status.
3. `USDC` is centralized and is a proxy contract, so there can be possibility of `Circle` saying they charge a fee of `x%` on transfers, which will break the protocol invariant.

**Impact:**
breaks protocol invariant, hence protocol becomes unusable.

**Recommended Mitigation:** 

1. restricting weird erc20's thats potential risk to the protocol or only allow allowlisted erc20's to be traded.
2. Follow `FREI-PI/CEI` design pattern to revert any transaction that is breaking the invariant to always maintain the property.
3. use at your own risk.

# Low

## [L-1] `PoolFactory()::constructor()` must have a zero check, to avoid pool creation with `address(0)`

**Description:** 
PoolFactory contract can be deployed with weth address as `0x0`. so, all the TSwapPool's will be created with zero address hence failing the protocol.

Additionally have a similar check for `PoolFactory()::CreatePool()` function to have a zero check.

**Impact:** 
Since, `i_wethToken` is immutable, the address can't be overwritten at later point and all the contracts must be deployed again for protocol to function.

**Proof of Concept:**

Place below code in `PoolFactoryTest.t.sol` and run - `forge test --mt testZeroWethAddress`

```javascript
    function testZeroWethAddress() public {
        factory = new PoolFactory(address(0));
        TSwapPool pool = TSwapPool(factory.createPool(address(tokenA)));

        assertEq(address(pool.getWeth()), address(0));

        vm.expectRevert();
        pool.deposit(1 ether, 1 ether, 1 ether, uint64(block.timestamp));
    }
```

## [L-2] Incorrect parameter logs in `TSwapPool::LiquidityAdded` event

**Description:** 

values of wethDeposited and poolTokensDeposited are interchanged and doesn't match what is expected as shown below.
second and third place in parameters must be interchanged while emitting.

```javascript
    //expected
    event LiquidityAdded(address indexed liquidityProvider, uint256 wethDeposited, uint256 poolTokensDeposited);

    // emitted
    emit LiquidityAdded(msg.sender, poolTokensToDeposit, wethToDeposit);
```

**Impact:** 
Systems reading Protocol logs like frontend or event indexers like `The Graph` protocol or any other off chain systems relying on protocol data will misinterpret the information logged due to the error

**Recommended Mitigation:** 

Make below code changes in `TSwapPool.sol`

```diff
    function _addLiquidityMintAndTransfer(...){
        .
        .
        .
-        emit LiquidityAdded(msg.sender, poolTokensToDeposit, wethToDeposit);
+        emit LiquidityAdded(msg.sender, wethToDeposit, poolTokensToDeposit);

    }
```

Make below code changes in `PoolFactory.sol`

```diff

+   error PoolFactory__ZeroAddress();

    constructor(address wethToken) {
+        if(wethToken == address(0)){
+            revert PoolFactory__ZeroAddress();
        }
        i_wethToken = wethToken;
    }

```

## [L-3] `swapExactInput` doesn't return expected `output` value

**Description:** 
`swapExactInput` is expected to return correct calculated `output` value, instead it just returns the 0 value without it being assigned anywhere in the function call hence causing callers to believe output is 0.

**Recommended Mitigation:**

Make below code changes in `TSwap.sol`

```diff
    function swapExactInput(
        ...
    )
        ...
        returns (
-            uint256 output 
+            uint256 outputAmount
        )
    {
        ...

        uint256 outputAmount = getOutputAmountBasedOnInput(inputAmount, inputReserves, outputReserves);

        ...
    }

```

# Informational/ Non-critical

## [I-1] Test Coverage

**Description:** 
The current test coverage for the project is below 90%, indicating that several parts of the codebase are not adequately tested.

**Impact:** 
Low test coverage increases the risk of undetected bugs and potential vulnerabilities in the code, leading to unreliable software.

**Proof of Concept:**

```bash
| File                     | % Lines        | % Statements    | % Branches     | % Funcs        |
|--------------------------|----------------|-----------------|----------------|----------------|
| script/DeployTSwap.t.sol | 0.00% (0/6)    | 0.00% (0/7)     | 0.00% (0/2)    | 0.00% (0/1)    |
| src/PoolFactory.sol      | 84.62% (11/13) | 88.89% (16/18)  | 100.00% (2/2)  | 60.00% (3/5)   |
| src/TSwapPool.sol        | 53.16% (42/79) | 55.24% (58/105) | 33.33% (8/24)  | 45.00% (9/20)  |
| Total                    | 54.08% (53/98) | 56.92% (74/130) | 35.71% (10/28) | 46.15% (12/26) |
```

**Recommended Mitigation:** 

To improve test coverage and reduce the risk of potential bugs, we recommend the following actions:

1. **Identify Untested Code:**
   - Use the test coverage report to pinpoint the specific areas of the code that are not covered by tests.

2. **Write Additional Tests:**
   - Create unit tests for the uncovered functions, branches, and statements. Focus on critical and complex logic first.

3. **Increase Branch Coverage:**
   - Ensure that all possible branches and conditions in the code are tested to catch edge cases.

4. **Review and Refactor:**
   - Regularly review the test suite and refactor both the tests and the code to maintain high coverage and code quality.

By systematically addressing these areas, the test coverage can be improved, leading to more robust and reliable software.

---

## [I-2] `public` functions not used internally could be marked `external`

**Description:** 
Instead of marking a function as `public`, consider marking it as `external` if it is not used internally.

**Impact:** 
Marking functions as `external` instead of `public` can save gas costs as `external` functions are less expensive to call.

**Proof of Concept:**

<details><summary>1 Found Instances</summary>

- Found in src/TSwapPool.sol [Line: 248](src/TSwapPool.sol#L248)

    ```solidity
        function swapExactInput(
    ```

</details>

**Recommended Mitigation:** 
Update the visibility of functions that are not used internally to `external`.

---

## [I-3] Define and use `constant` variables instead of using literals

**Description:** 
If the same constant literal value is used multiple times, create a constant state variable and reference it throughout the contract.

**Impact:** 
Using constant variables improves code readability and maintainability, reducing the risk of introducing errors when updating values.

**Proof of Concept:**

<details><summary>4 Found Instances</summary>

- Found in src/TSwapPool.sol [Line: 228](src/TSwapPool.sol#L228)

    ```solidity
            uint256 inputAmountMinusFee = inputAmount * 997;
    ```

- Found in src/TSwapPool.sol [Line: 245](src/TSwapPool.sol#L245)

    ```solidity
            return ((inputReserves * outputAmount) * 10000) / ((outputReserves - outputAmount) * 997);
    ```

- Found in src/TSwapPool.sol [Line: 378](src/TSwapPool.sol#L378)

    ```solidity
            1e18, i_wethToken.balanceOf(address(this)), i_poolToken.balanceOf(address(this))
    ```

- Found in src/TSwapPool.sol [Line: 384](src/TSwapPool.sol#L384)

    ```solidity
            1e18, i_poolToken.balanceOf(address(this)), i_wethToken.balanceOf(address(this))
    ```

</details>

**Recommended Mitigation:** 
Define and use constant variables for repeated literals.

---

## [I-4] Event is missing `indexed` fields

**Description:** 
Index event fields make the field more quickly accessible to off-chain tools that parse events.

**Impact:** 
Not indexing event fields makes it harder for off-chain services to search for and filter events, potentially reducing the efficiency of data retrieval.

**Proof of Concept:**

<details><summary>4 Found Instances</summary>

- Found in src/PoolFactory.sol [Line: 39](src/PoolFactory.sol#L39)

    ```solidity
        event PoolCreated(address tokenAddress, address poolAddress);
    ```

- Found in src/TSwapPool.sol [Line: 43](src/TSwapPool.sol#L43)

    ```solidity
        event LiquidityAdded(address indexed liquidityProvider, uint256 wethDeposited, uint256 poolTokensDeposited);
    ```

- Found in src/TSwapPool.sol [Line: 44](src/TSwapPool.sol#L44)

    ```solidity
        event LiquidityRemoved(address indexed liquidityProvider, uint256 wethWithdrawn, uint256 poolTokensWithdrawn);
    ```

- Found in src/TSwapPool.sol [Line: 45](src/TSwapPool.sol#L45)

    ```solidity
        event Swap(address indexed swapper, IERC20 tokenIn, uint256 amountTokenIn, IERC20 tokenOut, uint256 amountTokenOut);
    ```

</details>

**Recommended Mitigation:** 
Add `indexed` to event fields where applicable.

---

## [I-5] PUSH0 is not supported by all chains

**Description:** 
Solc compiler version 0.8.20 switches the default target EVM version to Shanghai, which means that the generated bytecode will include PUSH0 opcodes. Ensure compatibility with deployment chains.

**Impact:** 
Using PUSH0 opcodes may cause deployment failures on chains that do not support them.

**Proof of Concept:**

<details><summary>2 Found Instances</summary>

- Found in src/PoolFactory.sol [Line: 15](src/PoolFactory.sol#L15)

    ```solidity
    pragma solidity 0.8.20;
    ```

- Found in src/TSwapPool.sol [Line: 15](src/TSwapPool.sol#L15)

    ```solidity
    pragma solidity 0.8.20;
    ```

</details>

**Recommended Mitigation:** 
Select an appropriate EVM version for compatibility with intended deployment chains.

---

## [I-6] Large literal values multiples of 10000 can be replaced with scientific notation

**Description:** 
Use `e` notation for large literal values to improve code readability.

**Impact:** 
Using scientific notation makes the code easier to read and understand.

**Proof of Concept:**

<details><summary>3 Found Instances</summary>

- Found in src/TSwapPool.sol [Line: 36](src/TSwapPool.sol#L36)

    ```solidity
        uint256 private constant MINIMUM_WETH_LIQUIDITY = 1_000_000_000;
    ```

- Found in src/TSwapPool.sol [Line: 245](src/TSwapPool.sol#L245)

    ```solidity
        return ((inputReserves * outputAmount) * 10000) / ((outputReserves - outputAmount) * 997);
    ```

- Found in src/TSwapPool.sol [Line: 335](src/TSwapPool.sol#L335)

    ```solidity
        outputToken.safeTransfer(msg.sender, 1_000_000_000_000_000_000);
    ```

</details>

**Recommended Mitigation:** 
Replace large literal values with scientific notation.

---

## [I-7] Unused Custom Error

**Description:** 
An unused custom error is defined in the code. 

**Impact:** 
Unused custom errors add unnecessary bloat to the code and can be removed for clarity.

**Proof of Concept:**

<details><summary>1 Found Instances</summary>

- Found in src/PoolFactory.sol [Line: 24](src/PoolFactory.sol#L24)

    ```solidity
        error PoolFactory__PoolDoesNotExist(address tokenAddress);
    ```

</details>

**Recommended Mitigation:** 
Remove unused custom error definitions.

## [I-8] Follow CEI

**Description:** 

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 

```diff
    function deposit(
        ...
    )
        ...
    {
        ...

        if (totalLiquidityTokenSupply() > 0) {

           ...
           ...

        } else {

+            liquidityTokensToMint = wethToDeposit;

            _addLiquidityMintAndTransfer(wethToDeposit, maximumPoolTokensToDeposit, wethToDeposit);

-            liquidityTokensToMint = wethToDeposit;
        }
    }

```