## Usage

```shell
$ cd contracts
```

### Install libraries

```shell
$ forge install
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Environment Variables

- `PRIVATE_KEY`=
- `RPC_URL`=
- `ETHERSCAN_API_KEY`=
- `ORACLE_ADDRESS`=
- `REGISTRY_ADDRESS`=
- `CREATE2_DEPLOYER`=
- `POOL_MANAGER`=
- `HOOK_ADDRESS`=
- `SWAP_ROUTER`=
- `UNIVERSAL_ROUTER`=
- `LIQUIDITY_ROUTER`=
- `POSITION_MANAGER`=
- `ORIGIN_CHAIN_ID`=
- `DESTINATION_CHAIN_ID`=
- `REACTIVE_RPC`=
- `REACTIVE_PRIVATE_KEY`=
- `SYSTEM_CONTRACT_ADDR`=
- `DESTINATION_RPC`=
- `DESTINATION_PRIVATE_KEY`=
- `DESTINATION_CALLBACK_PROXY_ADDR`=
- `CALLBACK_ADDR`=

### Deploy Security Registry

```shell
$ forge script script/SecurityRegistry.s.sol \
--rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--broadcast \
--verify
```

### Deploy Hook

Anvil

```shell
$ anvil
```

```shell
$ forge script script/reCEPTIONHook.s.sol \
--rpc-url http://127.0.0.1:8545  \
--private-key $PRIVATE_KEY \
--broadcast \
--verify
```

RPC

```shell
$ forge script script/reCEPTIONHook.s.sol \
--rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--broadcast \
--verify
```

Verify Hook Deployment

```shell
$ cast code $HOOK_ADDRESS --rpc-url $RPC_URL
```

### Connect the hook to the registry (Important)

```shell
registry.setHook(hookAddress);
```

```shell
$ cast send $REGISTRY_ADDRESS \
"setHook(address)" $HOOK_ADDRESS \
--private-key $PRIVATE_KEY \
--rpc-url $RPC_URL
```

#### Quick verification

```shell
$ cast call $REGISTRY_ADDRESS "hook()(address)" --rpc-url $RPC_URL
```

#### Reactive Destination Contract

```bash
$ forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/reactive/reCEPTIONHookCallback.sol:reCEPTIONHookCallback --value 0.001ether --constructor-args $DESTINATION_CALLBACK_PROXY_ADDR $REGISTRY_ADDRESS
```

### Reactive Contract

```bash
$ forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/reactive/reCEPTIONReactive.sol:reCEPTIONReactive --value 0.001ether --constructor-args $SYSTEM_CONTRACT_ADDR $ORIGIN_CHAIN_ID $DESTINATION_CHAIN_ID $HOOK_ADDRESS 0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb $CALLBACK_ADDR
```

#### Deployed Hook Test

```shell
$ forge script script/TestHookFlow.s.sol \
--rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--broadcast \
--verify \
--etherscan-api-key $ETHERSCAN_API_KEY \
--slow \
-vvvv
```

#### Check status of any token address:

```shell
$ cast call $REGISTRY_ADDRESS \
"getStatus(address)" 0xTokenAddress \
--rpc-url $RPC_URL
```
