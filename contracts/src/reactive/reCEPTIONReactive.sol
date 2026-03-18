// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/reactive-lib/src/interfaces/IReactive.sol";
import "../../lib/reactive-lib/src/abstract-base/AbstractReactive.sol";
import "../../lib/reactive-lib/src/interfaces/ISystemContract.sol";

contract reCEPTIONReactive is IReactive, AbstractReactive {
    uint256 public originChainId;
    uint256 public destinationChainId;
    uint64 private constant GAS_LIMIT = 1000000;

    address private callback;

    constructor(
        address _service,
        uint256 _originChainId,
        uint256 _destinationChainId,
        address _contract,
        uint256 _topic_0,
        address _callback
    ) payable {
        service = ISystemContract(payable(_service));

        originChainId = _originChainId;
        destinationChainId = _destinationChainId;
        callback = _callback;

        if (!vm) {
            service.subscribe(
                originChainId,
                _contract,
                _topic_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    function react(LogRecord calldata log) external vmOnly {
        bytes memory payload = abi.encodePacked("callback(address)", log.data);
        emit Callback(destinationChainId, callback, GAS_LIMIT, payload);
    }
}
