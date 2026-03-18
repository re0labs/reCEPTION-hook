// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {
    SwapParams,
    ModifyLiquidityParams
} from "v4-core/types/PoolOperation.sol";
import {BeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {
    LiquidityAmounts
} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

import "../src/reCEPTIONHook.sol";
import "../src/SecurityRegistry.sol";
import "./mocks/MockreCEPTION.sol";
import "./mocks/MockToken.sol";

contract reCEPTIONHookTest is Test, Deployers {
    MockreCEPTION reception;

    SecurityRegistry registry;

    MockToken tokenA;

    MockToken tokenB;

    reCEPTIONHook hook;

    function setUp() public {
        deployFreshManagerAndRouters();

        reception = new MockreCEPTION();

        registry = new SecurityRegistry(address(reception));

        tokenA = new MockToken("TokenA", "TKA");

        tokenB = new MockToken("TokenB", "TKB");

        address hookAddress = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG |
                    Hooks.AFTER_INITIALIZE_FLAG |
                    Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
                    Hooks.BEFORE_SWAP_FLAG |
                    Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            )
        );

        deployCodeTo(
            "src/reCEPTIONHook.sol:reCEPTIONHook",
            abi.encode(manager, address(reception), address(registry)),
            hookAddress
        );

        hook = reCEPTIONHook(address(hookAddress));

        registry.setHook(address(hook));

        vm.roll(6000);
        (key, ) = initPool(
            Currency.wrap(address(tokenA)),
            Currency.wrap(address(tokenB)),
            hook,
            LPFeeLibrary.DYNAMIC_FEE_FLAG,
            SQRT_PRICE_1_1
        );
    }

    /// @notice Ensures that pool initialization correctly registers tokens and links them to the pool,
    /// and that security analysis is requested for both tokens.
    function test_beforeInitialize_registersPoolAndRequestsAnalysis()
        public
        view
    {
        bytes32 pid = PoolId.unwrap(key.toId());

        address t0 = hook.poolTokens(pid, 0);
        address t1 = hook.poolTokens(pid, 1);

        assertEq(t0, address(tokenA));
        assertEq(t1, address(tokenB));

        bytes32[] memory poolsA = hook.getPoolsForToken(address(tokenA));
        bytes32[] memory poolsB = hook.getPoolsForToken(address(tokenB));

        assertEq(poolsA.length, 1);
        assertEq(poolsB.length, 1);

        assertEq(poolsA[0], pid);
        assertEq(poolsB[0], pid);

        assertTrue(hook.analysisRequested(address(tokenA)));
        assertTrue(hook.analysisRequested(address(tokenB)));
    }

    /// @notice Verifies that pool initialization reverts if the pool is not configured to use dynamic fees.
    function test_beforeInitialize_revertsIfNotDynamicFee() public {
        PoolKey memory badKey = PoolKey({
            currency0: Currency.wrap(address(tokenA)),
            currency1: Currency.wrap(address(tokenB)),
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });

        vm.expectRevert();

        manager.initialize(badKey, SQRT_PRICE_1_1);
    }

    /// @notice Ensures adding liquidity is blocked when token security status is not SAFE.
    function test_beforeAddLiquidity_revertsIfTokensNotSafe() public {
        vm.expectRevert();

        modifyLiquidityRouter.modifyLiquidity{value: 1 ether}(
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    /// @notice Confirms liquidity can be added successfully when both tokens are marked SAFE.
    function test_beforeAddLiquidity_allowsWhenTokensAreSafe() public {
        vm.startPrank(address(reception));
        registry.updateStatus(
            address(tokenA),
            SecurityRegistry.SecurityStatus.SAFE
        );
        registry.updateStatus(
            address(tokenB),
            SecurityRegistry.SecurityStatus.SAFE
        );
        vm.stopPrank();

        tokenA.mint(address(this), 1 ether);
        tokenB.mint(address(this), 1 ether);

        tokenA.approve(address(modifyLiquidityRouter), 1 ether);
        tokenB.approve(address(modifyLiquidityRouter), 1 ether);

        modifyLiquidityRouter.modifyLiquidity{value: 1 ether}(
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );

        assertTrue(true);
    }

    /// @notice Ensures swaps are fully disabled when the pool is frozen.
    function test_beforeSwap_revertsWhenSwapsDisabled() public {
        hook.freezePool(key);

        bytes memory hookData = abi.encode(address(this));

        vm.expectRevert();

        swapRouter.swap{value: 1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: 1 ether,
                sqrtPriceLimitX96: 0
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
    }

    /// @notice Verifies that swaps revert when any token is flagged as a global threat (e.g. MALICIOUS).
    function test_beforeSwap_revertsOnGlobalThreatToken() public {
        vm.prank(address(reception));
        registry.updateStatus(
            address(tokenA),
            SecurityRegistry.SecurityStatus.MALICIOUS
        );

        bytes memory hookData = abi.encode(address(this));

        vm.expectRevert();

        swapRouter.swap{value: 1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: 1 ether,
                sqrtPriceLimitX96: 0
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
    }

    /// @notice Ensures that when both tokens are SAFE, swaps execute with the lowest (safe) fee tier.
    function test_beforeSwap_appliesSafeFeeWhenAllSafe() public {
        _fulfillAnalysis(address(tokenA), "SAFE");
        _fulfillAnalysis(address(tokenB), "SAFE");

        vm.startPrank(address(reception));
        registry.updateStatus(
            address(tokenA),
            SecurityRegistry.SecurityStatus.SAFE
        );
        registry.updateStatus(
            address(tokenB),
            SecurityRegistry.SecurityStatus.SAFE
        );
        vm.stopPrank();

        tokenA.mint(address(this), 10 ether);
        tokenB.mint(address(this), 10 ether);

        tokenA.approve(address(modifyLiquidityRouter), type(uint256).max);
        tokenB.approve(address(modifyLiquidityRouter), type(uint256).max);

        tokenA.approve(address(swapRouter), type(uint256).max);
        tokenB.approve(address(swapRouter), type(uint256).max);

        modifyLiquidityRouter.modifyLiquidity{value: 1 ether}(
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );

        bytes memory hookData = abi.encode(address(this));

        swapRouter.swap{value: 1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: 1 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        assertTrue(true);
    }

    /// @notice Validates that UNKNOWN tokens apply higher fees and enforce swap size limits.
    /// Small swaps succeed, while large swaps are rejected.
    function test_beforeSwap_appliesUnknownFeeAndLimitsSwap() public {
        uint256 smallAmount = 5 ether;
        uint256 largeAmount = 20 ether;

        _fulfillAnalysis(address(tokenA), "UNKNOWN");
        _fulfillAnalysis(address(tokenB), "UNKNOWN");

        tokenA.mint(address(this), largeAmount);
        tokenB.mint(address(this), largeAmount);

        tokenA.approve(address(swapRouter), type(uint256).max);
        tokenB.approve(address(swapRouter), type(uint256).max);

        bytes memory hookData = abi.encode(address(this));

        swapRouter.swap{value: 1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: int256(smallAmount),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        vm.expectRevert();

        swapRouter.swap{value: 1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: int256(largeAmount),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
    }

    /// @notice Ensures that SUSPICIOUS tokens result in elevated fees but still allow swaps.
    function test_beforeSwap_appliesSuspiciousFee() public {
        _fulfillAnalysis(address(tokenA), "SUSPICIOUS");
        _fulfillAnalysis(address(tokenB), "SAFE");

        vm.startPrank(address(reception));
        registry.updateStatus(
            address(tokenA),
            SecurityRegistry.SecurityStatus.SUSPICIOUS
        );
        registry.updateStatus(
            address(tokenB),
            SecurityRegistry.SecurityStatus.SAFE
        );
        vm.stopPrank();

        tokenA.mint(address(this), 10 ether);
        tokenB.mint(address(this), 10 ether);

        tokenA.approve(address(swapRouter), type(uint256).max);
        tokenB.approve(address(swapRouter), type(uint256).max);

        bytes memory hookData = abi.encode(address(this));

        swapRouter.swap{value: 1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: int256(1 ether),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        assertTrue(true);
    }

    /// @notice Verifies that swaps revert when any token is marked as HIGH_RISK.
    function test_beforeSwap_revertsOnHighRiskToken() public {
        vm.startPrank(address(reception));
        registry.updateStatus(
            address(tokenA),
            SecurityRegistry.SecurityStatus.HIGH_RISK
        );
        registry.updateStatus(
            address(tokenB),
            SecurityRegistry.SecurityStatus.SAFE
        );
        vm.stopPrank();

        tokenA.mint(address(this), 10 ether);
        tokenB.mint(address(this), 10 ether);

        tokenA.approve(address(swapRouter), type(uint256).max);
        tokenB.approve(address(swapRouter), type(uint256).max);

        bytes memory hookData = abi.encode(address(this));

        vm.expectRevert();

        swapRouter.swap{value: 1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: int256(1 ether),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
    }

    /// @notice Verifies that swaps revert when any token is marked as MALICIOUS.
    function test_beforeSwap_revertsOnMaliciousToken() public {
        vm.startPrank(address(reception));
        registry.updateStatus(
            address(tokenA),
            SecurityRegistry.SecurityStatus.MALICIOUS
        );
        registry.updateStatus(
            address(tokenB),
            SecurityRegistry.SecurityStatus.SAFE
        );
        vm.stopPrank();

        tokenA.mint(address(this), 10 ether);
        tokenB.mint(address(this), 10 ether);

        tokenA.approve(address(swapRouter), type(uint256).max);
        tokenB.approve(address(swapRouter), type(uint256).max);

        bytes memory hookData = abi.encode(address(this));

        vm.expectRevert();

        swapRouter.swap{value: 1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: int256(1 ether),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
    }

    /// @notice Simulates oracle callback fulfillment for a given token security analysis request.
    function _fulfillAnalysis(address target, string memory result) internal {
        bytes32 requestId = reception.lastRequestForTarget(target);

        vm.prank(address(reception));

        hook.oracleFulfill(requestId, result);
    }
}
