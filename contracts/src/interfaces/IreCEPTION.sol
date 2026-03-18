// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IreCEPTION {
    struct Request {
        address requester;
        uint8 rType;
        string input;
        address target;
        bool fulfilled;
        string result;
        uint256 fee;
        bool paid;
        address paymentToken;
        uint256 createdAt;
        uint256 feeQuotedAt;
        bytes32 apiKeyHash;
        address callback;
    }

    function hookRequestAnalysis(
        address target,
        address paymentToken
    ) external returns (bytes32);

    function hookRequestAnalysisFor(
        address requester,
        address target,
        address paymentToken
    ) external returns (bytes32);

    function payFeeETH(bytes32 id) external payable;

    function payFeeToken(bytes32 id, uint256 amount) external;

    function requests(
        bytes32 id
    )
        external
        view
        returns (
            address requester,
            uint8 rType,
            string memory input,
            address target,
            bool fulfilled,
            string memory result,
            uint256 fee,
            bool paid,
            address paymentToken,
            uint256 createdAt,
            uint256 feeQuotedAt,
            bytes32 apiKeyHash,
            address callback
        );
}
