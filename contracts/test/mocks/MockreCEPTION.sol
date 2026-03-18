// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/interfaces/IreCEPTION.sol";

contract MockreCEPTION is IreCEPTION {
    uint256 public counter;

    mapping(bytes32 => address) public requestTarget;

    mapping(address => bytes32) public lastRequestForTarget;

    function hookRequestAnalysis(
        address target,
        address
    ) external returns (bytes32 requestId) {
        counter++;

        requestId = keccak256(abi.encode(counter));

        requestTarget[requestId] = target;

        lastRequestForTarget[target] = requestId;

        return requestId;
    }

    function hookRequestAnalysisFor(
        address target,
        address,
        address
    ) external returns (bytes32 requestId) {
        counter++;

        requestId = keccak256(abi.encode(counter));

        requestTarget[requestId] = target;

        lastRequestForTarget[target] = requestId;

        return requestId;
    }

    function payFeeETH(bytes32) external payable {}

    function payFeeToken(bytes32, uint256) external {}

    function requests(
        bytes32
    )
        external
        pure
        returns (
            address,
            uint8,
            string memory,
            address,
            bool,
            string memory,
            uint256,
            bool,
            address,
            uint256,
            uint256,
            bytes32,
            address
        )
    {
        revert();
    }
}
