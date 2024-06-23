# High

### [H-1] `TSwapPool::getInputAmountBasedOnOutput()` calculates pool fee as a wrong value, thereby taking more tokens than intended from caller

**Description:** 

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 


### [H-2] `TSwapPool::_swap()` function is giving away extra tokens of 1 ether for every 10 swaps, breaking system's invariant property

**Description:** 

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 

### [H-3] `sellPoolTokens` is calculating output instead of input .....??

**Description:** 

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 

### [H-4] `TSwapPool::swapExactOutput()` function is missing slippage protection check, causing caller to get less tokens than they expect

**Description:** 

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 

# Medium

### [M-1] `TSwapPool::deposit()` doesn't take `deadline` parameter into consideration, causing depositors to get unexpected lp token value for their deposit

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
        
    }

```

### [M-2] Rebase, fee-on-transfer, ERC777, and centralized ERC20s can break core invariant

**Description:** 

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 

# Low

### [L-1] `PoolFactory()::constructor()` must have a zero check, to avoid pool creation with `address(0)`

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

### [L-2] Incorrect parameter logs in `TSwapPool::LiquidityAdded` event

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

### [L-3] `swapExactInput` doesn't return expected `output` value

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

### [I-1] Test Coverage

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

### [I-2] `public` functions not used internally could be marked `external`

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

### [I-3] Define and use `constant` variables instead of using literals

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

### [I-4] Event is missing `indexed` fields

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

### [I-5] PUSH0 is not supported by all chains

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

### [I-6] Large literal values multiples of 10000 can be replaced with scientific notation

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

### [I-7] Unused Custom Error

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

### [I-8] Follow CEI

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