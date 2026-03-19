// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

import "../src/reCEPTIONHook.sol";

contract Deploy is Script {
    function run() external {
        address create2deployer = vm.envAddress("CREATE2_DEPLOYER");
        address manager = vm.envAddress("POOL_MANAGER");
        address oracle = vm.envAddress("ORACLE_ADDRESS");
        address registry = vm.envAddress("REGISTRY_ADDRESS");

        uint160 flags = Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.AFTER_INITIALIZE_FLAG |
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG;

        bytes memory constructorArgs = abi.encode(manager, oracle, registry);
        (address hookAddress, bytes32 salt) = HookMiner.find(
            create2deployer,
            flags,
            type(reCEPTIONHook).creationCode,
            constructorArgs
        );

        vm.startBroadcast();

        reCEPTIONHook reception = new reCEPTIONHook{salt: salt}(
            IPoolManager(manager),
            oracle,
            registry
        );
        require(
            address(reception) == hookAddress,
            "Deploy: hook address mismatch"
        );

        vm.stopBroadcast();
    }
}
