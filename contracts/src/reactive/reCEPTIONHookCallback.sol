// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol";
import "../SecurityRegistry.sol";

contract reCEPTIONHookCallback is AbstractCallback {
    SecurityRegistry public registry;

    constructor(
        address _callback_sender,
        address _registry
    ) payable AbstractCallback(_callback_sender) {
        registry = SecurityRegistry(_registry);
    }

    function callback(
        address sender,
        bytes memory data
    ) external authorizedSenderOnly rvmIdOnly(sender) {
        (address token, uint8 status) = abi.decode(data, (address, uint8));
        registry.updateStatus(token, SecurityRegistry.SecurityStatus(status));
    }
}
