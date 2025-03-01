## Vordex WIP

Options exchange

Setup
```shell
# Need to install foundry / forge
forge install --no-git OpenZeppelin/openzeppelin-contracts --no-commit
forge install Uniswap/v3-periphery --no-git --no-commit               
forge install Uniswap/v3-core --no-git --no-commit
```

```shell
source .env
forge test --fork-url $INFURA_RPC -vvvv
```

Successful test run example
```shell

Ran 4 tests for test/CoveredCallEscrow.t.sol:CoveredCallEscrowTest
[PASS] test_cannotExerciseIfNotITM() (gas: 303063)
Logs:
  Creating call - Seller: 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf
  Strike Price: 3500000000 Expiration: 1740903623
  Escrowing WETH: 1000000000000000000
  Locking call - Buyer: 0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF
  Premium Paid: 100000000
  Mocked ETH Price: 3400 USDC, should be below strike price
  Exercising call - Buyer: 0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF
  Current Price (scaled to 6 decimals): 3400000000 Strike Price: 3500000000

[PASS] test_cannotExpireBeforeExpiration() (gas: 297065)
Logs:
  Creating call - Seller: 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf
  Strike Price: 3200000000 Expiration: 1740903623
  Escrowing WETH: 1000000000000000000
  Locking call - Buyer: 0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF
  Premium Paid: 100000000

[PASS] test_exerciseCoveredCall() (gas: 375306)
Logs:
  Creating call - Seller: 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf
  Strike Price: 3000000000 Expiration: 1740903623
  Escrowing WETH: 1000000000000000000
  Covered Call Created: ID 0
  Locking call - Buyer: 0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF
  Premium Paid: 100000000
  Buyer Locked Call: ID 0
  Mocked ETH Price: 3100 USDC
  Buyer USDC Before Exercise: 4900000000
  Exercising call - Buyer: 0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF
  Current Price (scaled to 6 decimals): 3100000000 Strike Price: 3000000000
  Buyer USDC After Exercise: 7123331195

[PASS] test_expireCoveredCall() (gas: 302464)
Logs:
  Creating call - Seller: 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf
  Strike Price: 3500000000 Expiration: 1740903623
  Escrowing WETH: 1000000000000000000
  Locking call - Buyer: 0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF
  Premium Paid: 100000000
  Seller WETH Before Expiration: 9000000000000000000
  Seller USDC Before Expiration: 0
  Expiring call - Seller: 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf
  Seller WETH After Expiration: 10000000000000000000
  Seller USDC After Expiration: 100000000

```

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
