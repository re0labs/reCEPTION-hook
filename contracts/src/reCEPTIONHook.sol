// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {
    BeforeSwapDelta,
    BeforeSwapDeltaLibrary
} from "v4-core/types/BeforeSwapDelta.sol";
import {
    ModifyLiquidityParams,
    SwapParams
} from "v4-core/types/PoolOperation.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";

import "./interfaces/IreCEPTION.sol";
import "./SecurityRegistry.sol";

contract reCEPTIONHook is BaseHook {
    /// ----------------------------------------------------
    /// STORAGE
    /// ----------------------------------------------------

    IreCEPTION public immutable reception;

    SecurityRegistry public registry;

    address public owner;

    using LPFeeLibrary for uint24;

    uint24 public constant SAFE_FEE = 3000;
    uint24 public constant SUSPICIOUS_FEE = 8000;
    uint24 public constant HIGH_RISK_FEE = 20000;
    uint24 public constant UNKNOWN_FEE = 15000;
    uint256 public constant UNKNOWN_MAX_SWAP = 10 ether;
    uint256 public constant ANALYSIS_COOLDOWN = 5000;

    uint256 public lastOracleBlock;
    uint256 public oracleRequestsThisBlock;
    uint256 public constant MAX_ORACLE_PER_BLOCK = 10;

    mapping(bytes32 => bool) public swapBlocked;
    mapping(address => bytes32[]) public poolsForToken;
    mapping(bytes32 => address[2]) public poolTokens;

    mapping(address => bool) public analysisRequested;
    mapping(address => uint256) public lastAnalysisBlock;

    mapping(bytes32 => address) public requestTarget;

    mapping(address => bytes32) public analyzedCodeHash;

    /// ----------------------------------------------------
    /// EVENTS
    /// ----------------------------------------------------

    event SwapsDisabled(bytes32 indexed poolId);
    event AnalysisRequested(address indexed target, bytes32 requestId);
    event AddressMarkedSafe(address indexed target);
    event AddressMarkedMalicious(address indexed target);
    event PoolFrozen(bytes32 indexed poolId);
    event AddressUnblocked(address indexed target);
    event ThreatBroadcast(address indexed token, uint8 status);

    /// ----------------------------------------------------
    /// ERRORS
    /// ----------------------------------------------------

    error MustUseDynamicFee();

    /// ----------------------------------------------------
    /// MODIFIERS
    /// ----------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == address(reception), "Not oracle");
        _;
    }

    /// ----------------------------------------------------
    /// CONSTRUCTOR
    /// ----------------------------------------------------

    constructor(
        IPoolManager _manager,
        address _reception,
        address _registry
    ) BaseHook(_manager) {
        reception = IreCEPTION(_reception);
        registry = SecurityRegistry(_registry);

        owner = msg.sender;
    }

    /// ----------------------------------------------------
    /// HOOK PERMISSIONS
    /// ----------------------------------------------------

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: true,
                afterInitialize: true,
                beforeAddLiquidity: true,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: true,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    /// ----------------------------------------------------
    /// INITIALIZATION
    /// ----------------------------------------------------
    function _beforeInitialize(
        address,
        PoolKey calldata key,
        uint160
    ) internal pure override returns (bytes4) {
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();

        return this.beforeInitialize.selector;
    }

    function _afterInitialize(
        address,
        PoolKey calldata key,
        uint160,
        int24
    ) internal override returns (bytes4) {
        bytes32 pid = PoolId.unwrap(key.toId());

        require(!swapBlocked[pid], "Swaps disabled");

        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        require(!registry.isThreat(token0), "Global threat");
        require(!registry.isThreat(token1), "Global threat");

        _requestAnalysis(token0);
        _requestAnalysis(token1);

        poolsForToken[token0].push(pid);
        poolsForToken[token1].push(pid);

        poolTokens[pid] = [token0, token1];

        return this.afterInitialize.selector;
    }

    function getPoolsForToken(
        address token
    ) external view returns (bytes32[] memory) {
        return poolsForToken[token];
    }

    /// ----------------------------------------------------
    /// LIQUIDITY
    /// ----------------------------------------------------

    function _beforeAddLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) internal view override returns (bytes4) {
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        require(
            registry.getStatus(token0) ==
                SecurityRegistry.SecurityStatus.SAFE &&
                registry.getStatus(token1) ==
                SecurityRegistry.SecurityStatus.SAFE,
            "Pool quarantined"
        );

        return this.beforeAddLiquidity.selector;
    }

    /// ----------------------------------------------------
    /// FIREWALL
    /// ----------------------------------------------------

    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        bytes32 pid = PoolId.unwrap(key.toId());

        address router = sender;

        require(!swapBlocked[pid], "Swaps disabled");

        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        require(!registry.isThreat(router), "Malicious router");
        require(!registry.isThreat(token0), "Global threat");
        require(!registry.isThreat(token1), "Global threat");

        SecurityRegistry.SecurityStatus s0 = registry.getStatus(token0);
        SecurityRegistry.SecurityStatus s1 = registry.getStatus(token1);

        require(token0.code.length > 0, "Token destroyed");
        require(token1.code.length > 0, "Token destroyed");

        if (analyzedCodeHash[token0] != bytes32(0)) {
            require(analyzedCodeHash[token0] == token0.codehash);
        }

        if (analyzedCodeHash[token1] != bytes32(0)) {
            require(analyzedCodeHash[token1] == token1.codehash);
        }

        require(
            s0 != SecurityRegistry.SecurityStatus.MALICIOUS &&
                s1 != SecurityRegistry.SecurityStatus.MALICIOUS,
            "Malicious token"
        );

        require(
            s0 != SecurityRegistry.SecurityStatus.HIGH_RISK &&
                s1 != SecurityRegistry.SecurityStatus.HIGH_RISK,
            "High risk token"
        );

        require(!analysisRequested[router], "Router under analysis");
        require(!analysisRequested[token0], "Token under analysis");
        require(!analysisRequested[token1], "Token under analysis");

        _requestAnalysis(router);
        _requestAnalysis(token0);
        _requestAnalysis(token1);

        uint24 fee = SAFE_FEE;

        if (
            s0 == SecurityRegistry.SecurityStatus.UNKNOWN ||
            s1 == SecurityRegistry.SecurityStatus.UNKNOWN
        ) {
            require(_abs(params.amountSpecified) <= UNKNOWN_MAX_SWAP);
            fee = UNKNOWN_FEE;
        }

        fee = _maxRiskFee(fee, router);
        fee = _maxRiskFee(fee, token0);
        fee = _maxRiskFee(fee, token1);

        return (
            this.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            fee | LPFeeLibrary.OVERRIDE_FEE_FLAG
        );
    }

    /// ----------------------------------------------------
    /// REQUEST ANALYSIS
    /// ----------------------------------------------------

    function _requestAnalysis(address target) internal {
        SecurityRegistry.SecurityStatus cached = registry.getStatus(target);

        if (cached != SecurityRegistry.SecurityStatus.UNKNOWN) {
            return;
        }

        if (target.code.length == 0) return;

        if (analysisRequested[target]) return;

        if (block.number < lastAnalysisBlock[target] + ANALYSIS_COOLDOWN)
            return;

        lastAnalysisBlock[target] = block.number;

        if (block.number != lastOracleBlock) {
            lastOracleBlock = block.number;
            oracleRequestsThisBlock = 0;
        }

        if (oracleRequestsThisBlock >= MAX_ORACLE_PER_BLOCK) return;

        oracleRequestsThisBlock++;

        bytes32 requestId = reception.hookRequestAnalysis(target, address(0));

        requestTarget[requestId] = target;

        analysisRequested[target] = true;

        emit AnalysisRequested(target, requestId);
    }

    /// ----------------------------------------------------
    /// ORACLE CALLBACK
    /// ----------------------------------------------------

    function oracleFulfill(
        bytes32 requestId,
        string calldata result
    ) external onlyOracle {
        address target = requestTarget[requestId];

        bytes32 hash = keccak256(bytes(result));

        SecurityRegistry.SecurityStatus status;

        if (hash == keccak256(bytes("MALICIOUS"))) {
            status = SecurityRegistry.SecurityStatus.MALICIOUS;
        } else if (hash == keccak256(bytes("HIGH_RISK"))) {
            status = SecurityRegistry.SecurityStatus.HIGH_RISK;
        } else if (hash == keccak256(bytes("SUSPICIOUS"))) {
            status = SecurityRegistry.SecurityStatus.SUSPICIOUS;
        } else {
            status = SecurityRegistry.SecurityStatus.SAFE;
        }

        if (status == SecurityRegistry.SecurityStatus.MALICIOUS) {
            _freezeAllPools(target);
        }

        registry.updateStatus(target, status);

        analysisRequested[target] = false;

        analyzedCodeHash[target] = target.codehash;

        delete requestTarget[requestId];

        emit ThreatBroadcast(target, uint8(status));
    }

    /// ----------------------------------------------------
    /// POOL FREEZE
    /// ----------------------------------------------------

    function _freezeAllPools(address token) internal {
        bytes32[] storage pools = poolsForToken[token];

        for (uint256 i; i < pools.length; i++) {
            swapBlocked[pools[i]] = true;
            emit SwapsDisabled(pools[i]);
        }
    }

    /// ----------------------------------------------------
    /// ADMIN
    /// ----------------------------------------------------

    function unblockAddress(address target) external onlyOwner {
        registry.updateStatus(target, SecurityRegistry.SecurityStatus.SAFE);
        emit AddressUnblocked(target);
    }

    function freezePool(PoolKey calldata key) external onlyOwner {
        bytes32 pid = PoolId.unwrap(key.toId());

        swapBlocked[pid] = true;

        emit PoolFrozen(pid);
    }

    /// ----------------------------------------------------
    /// FEES
    /// ----------------------------------------------------

    function _maxRiskFee(
        uint24 currentFee,
        address target
    ) internal view returns (uint24) {
        SecurityRegistry.SecurityStatus status = registry.getStatus(target);

        if (status == SecurityRegistry.SecurityStatus.MALICIOUS) {
            revert("Malicious address detected");
        }

        if (status == SecurityRegistry.SecurityStatus.HIGH_RISK) {
            return HIGH_RISK_FEE;
        }

        if (
            status == SecurityRegistry.SecurityStatus.SUSPICIOUS &&
            currentFee < SUSPICIOUS_FEE
        ) {
            return SUSPICIOUS_FEE;
        }

        return currentFee;
    }

    /// ----------------------------------------------------
    /// HELPERS
    /// ----------------------------------------------------

    function _abs(int256 x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }
}
