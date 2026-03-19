// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SecurityRegistry.sol";

contract Deploy is Script {
    function run() external returns (SecurityRegistry registry) {
        address oracle = vm.envAddress("ORACLE_ADDRESS");

        vm.startBroadcast();

        registry = new SecurityRegistry(oracle);

        vm.stopBroadcast();
    }
}
