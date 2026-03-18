# reCEPTION Hook

## Cross-Chain Security Firewall for Uniswap v4

reCEPTION is a **security-first Uniswap v4 Hook** that protects decentralized exchanges from malicious tokens, compromised routers, and risky smart contracts.

The hook integrates with the **reCEPTION AI security oracle** to analyze smart contracts interacting with pools and dynamically adjusts behavior to:

- block malicious assets
- quarantine risky tokens
- dynamically adjust swap fees
- limit unknown tokens
- propagate threats across chains

When a malicious contract is detected, **all pools using that token are automatically frozen**, and the threat intelligence is broadcast across chains using Reactive Network.

---

# Problem

DeFi users are constantly exposed to:

- malicious tokens
- rug pulls
- proxy contract upgrades
- compromised routers
- hidden backdoors
- honeypots

Most DEXs treat **all tokens equally**, meaning malicious contracts can freely create pools and exploit users.

reCEPTION introduces a **security layer directly inside the DEX swap path**.

---

# Solution

reCEPTION is a **Uniswap v4 Hook security firewall** that evaluates contracts interacting with pools and dynamically applies security policies.

The hook:

✔ scans tokens and routers  
✔ dynamically adjusts swap fees  
✔ blocks malicious contracts  
✔ freezes compromised pools  
✔ limits unknown tokens  
✔ propagates threats cross-chain

---

# Architecture

Trader  
 │  
 ▼  
Swap Router  
│  
▼  
Uniswap Pool Manager  
│  
▼  
reCEPTIONHook  
│  
├── SecurityRegistry  
│  
├── AI Security Oracle  
│  
└── Cross-Chain Threat Broadcast  
│  
▼  
Reactive Network  
│  
▼  
Other Chains Update Registry

The hook sits directly inside the **swap execution path**.

Every interaction is evaluated before execution.

---

# Security Model

Each contract interacting with a pool is classified as:

| Status     | Behavior          |
| ---------- | ----------------- |
| SAFE       | normal fees       |
| SUSPICIOUS | elevated fees     |
| HIGH_RISK  | swaps blocked     |
| MALICIOUS  | pools frozen      |
| UNKNOWN    | swap size limited |

These classifications are determined by the **reCEPTION AI analysis engine**.

---

# Hook Lifecycle

The hook uses the following **Uniswap v4 hook points**.

## beforeInitialize

Ensures the pool uses **dynamic fees**.

```shell
MustUseDynamicFee()
```

---

## afterInitialize

When a pool is created:

- both tokens are registered
- analysis is requested
- pool-token mappings are stored

```shell
_requestAnalysis(token)
```

---

## beforeAddLiquidity

Liquidity is only allowed when both tokens are **SAFE**.

This prevents liquidity providers from accidentally depositing funds into unsafe pools.

---

## beforeSwap

This is the core firewall.

Before every swap the hook checks:

- router security
- token security
- contract integrity
- analysis state
- swap limits

Possible results:

- swap allowed
- swap rejected
- dynamic fee applied
- analysis triggered

---

# Dynamic Security Fees

Fees adjust automatically depending on token risk.

| Status     | Fee     |
| ---------- | ------- |
| SAFE       | 0.3%    |
| SUSPICIOUS | 0.8%    |
| UNKNOWN    | 1.5%    |
| HIGH_RISK  | blocked |
| MALICIOUS  | blocked |

Unknown tokens also have **swap size limits**.

```shell
UNKNOWN_MAX_SWAP = 10 ETH
```

This prevents large trades against unverified contracts.

---

# Contract Integrity Protection

To prevent **proxy upgrades or code replacement attacks**, the hook stores the analyzed code hash.

```shell
analyzedCodeHash[token]
```

If a token changes its code after being analyzed, swaps revert immediately.

---

# Pool Freeze Mechanism

If a contract is classified as **MALICIOUS**, all pools using that token are frozen.

```shell
_freezeAllPools(token)
```

Every affected pool will have swaps permanently disabled until manual review.

---

# Oracle Integration

The hook communicates with the **reCEPTION AI analysis oracle**.

When a new contract interacts with a pool:

```shell
hookRequestAnalysis(target)
```

The oracle evaluates the contract and returns:

```shell
SAFE
SUSPICIOUS
HIGH_RISK
MALICIOUS
```

The hook processes the result via:

```shell
oracleFulfill(requestId, result)
```

---

# Cross-Chain Threat Intelligence

When a malicious contract is detected, the hook emits:

ThreatBroadcast(token, status)

This event is monitored by **Reactive Network**, which propagates the threat to other chains.

Other chains then update their registries automatically.

```shell
registry.updateStatus(token, MALICIOUS)
```

Result:

If a malicious token is detected on **one chain**, it becomes blocked across **all chains running reCEPTION**.

This creates a **cross-chain DeFi security network**.

---

# Testing

The repository includes extensive Foundry tests validating:

- pool initialization
- security analysis requests
- liquidity restrictions
- swap validation
- dynamic fee logic
- swap size limits
- malicious token blocking
- high risk token blocking

Tests simulate the oracle callback using a mock oracle.

Example:

```shell
hook.oracleFulfill(requestId, "SAFE")
```

---

# Running Tests

Install dependencies and run tests using **Foundry**.

```shell
cd contracts
forge install
forge test
```

---

# Project Structure

contracts/  
└ src/  
├ reCEPTIONHook.sol  
├ SecurityRegistry.sol  
├ interfaces/  
└ reactive/

└ test/  
├ reCEPTIONHook.t.sol  
└ mocks/

The `reactive` folder contains contracts used for cross-chain threat propagation.

---

# Why This Matters

DeFi currently lacks **native security infrastructure**.

reCEPTION transforms DEX pools into **self-defending liquidity infrastructure**.

Instead of relying on off-chain warnings, the protocol itself enforces security policies.

---

# Key Benefits

✔ protects traders from malicious tokens  
✔ protects LPs from rug pulls  
✔ reduces attack surface for routers  
✔ introduces dynamic risk pricing  
✔ automatically quarantines threats  
✔ shares threat intelligence across chains

---

# Future Improvements

- risk score based fees
- decentralized security oracle network
- cross-DEX threat registry
- automated LP migration from compromised pools
- on-chain threat reputation system

---

# Conclusion

reCEPTION transforms Uniswap v4 hooks into a **DeFi security firewall**.

By combining:

- AI contract analysis
- dynamic fee enforcement
- pool quarantine
- cross-chain threat intelligence

reCEPTION creates the first **autonomous cross-chain DEX security network**.
