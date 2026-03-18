// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SecurityRegistry {
    enum SecurityStatus {
        UNKNOWN,
        PENDING,
        SAFE,
        SUSPICIOUS,
        HIGH_RISK,
        MALICIOUS,
        QUARANTINED
    }

    address public owner;
    address public oracle;
    address public hook;

    mapping(address => SecurityStatus) public securityStatus;

    event SecurityUpdated(address indexed target, SecurityStatus status);
    event GlobalThreatDetected(address indexed target, SecurityStatus status);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle || msg.sender == hook, "Not oracle");
        _;
    }

    constructor(address _oracle) {
        owner = msg.sender;
        oracle = _oracle;
    }

    function setHook(address _hook) external onlyOwner {
        hook = _hook;
    }

    function updateStatus(
        address target,
        SecurityStatus status
    ) external onlyOracle {
        securityStatus[target] = status;

        emit SecurityUpdated(target, status);

        if (
            status == SecurityStatus.MALICIOUS ||
            status == SecurityStatus.HIGH_RISK
        ) {
            emit GlobalThreatDetected(target, status);
        }
    }

    function getStatus(address target) public view returns (SecurityStatus) {
        return securityStatus[target];
    }

    function isThreat(address target) external view returns (bool) {
        SecurityStatus s = securityStatus[target];

        return (s == SecurityStatus.MALICIOUS || s == SecurityStatus.HIGH_RISK);
    }
}
