// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";

import {
    SwapParams,
    ModifyLiquidityParams
} from "v4-core/types/PoolOperation.sol";

import "../src/TestToken.sol";

interface ISwapRouter {
    function swap(
        PoolKey memory key,
        SwapParams memory params,
        bytes calldata hookData
    ) external returns (int256);
}

contract TestHookFlow is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(pk);

        address poolManagerAddr = vm.envAddress("POOL_MANAGER");
        address hookAddr = vm.envAddress("HOOK_ADDRESS");
        address swapRouterAddr = vm.envAddress("SWAP_ROUTER");

        IPoolManager poolManager = IPoolManager(poolManagerAddr);
        ISwapRouter swapRouter = ISwapRouter(swapRouterAddr);

        vm.startBroadcast(pk);

        //---------------------------------------
        // Deploy tokens
        //---------------------------------------

        TestToken tokenA = new TestToken("TokenA", "TKA");
        TestToken tokenB = new TestToken("TokenB", "TKB");

        console.log("TokenA deployed:", address(tokenA));
        console.log("TokenB deployed:", address(tokenB));

        //---------------------------------------
        // Mint tokens
        //---------------------------------------

        tokenA.mint(user, 100 ether);
        tokenB.mint(user, 100 ether);

        //---------------------------------------
        // Approve PoolManager
        //---------------------------------------

        tokenA.approve(poolManagerAddr, type(uint256).max);
        tokenB.approve(poolManagerAddr, type(uint256).max);

        //---------------------------------------
        // Sort tokens
        //---------------------------------------

        (address token0, address token1) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));

        //---------------------------------------
        // Create pool key
        //---------------------------------------

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 0x800000, // dynamic fee
            tickSpacing: 60,
            hooks: IHooks(hookAddr)
        });

        //---------------------------------------
        // Initialize pool
        //---------------------------------------

        uint160 sqrtPriceX96 = 79228162514264337593543950336;

        poolManager.initialize(key, sqrtPriceX96);

        console.log("Pool initialized");

        //---------------------------------------
        // Add liquidity
        //---------------------------------------

        /*poolManager.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: -120,
                tickUpper: 120,
                liquidityDelta: int256(10 ether),
                salt: bytes32(0)
            }),
            ""
        );

        console.log("Liquidity added");

        //---------------------------------------
        // Execute swap (trigger hook)
        //---------------------------------------

        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: int256(1 ether),
                sqrtPriceLimitX96: 0
            }),
            abi.encode(user)
        );

        console.log("Swap executed -> hook triggered");*/

        vm.stopBroadcast();
    }
}
