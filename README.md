# Vaults • [![Tests](https://github.com/Rari-Capital/vaults/actions/workflows/tests.yml/badge.svg)](https://github.com/Rari-Capital/vaults/actions/workflows/tests.yml) [![License](https://img.shields.io/badge/License-AGPL--3.0-blue)](LICENSE.md)

Flexible, simple, and **gas-optimized trading protocol** for earning returns from automated trading strategies.

- [Documentation](https://docs.rari.capital/vaults)
- [Deployments](https://github.com/Rari-Capital/vaults/releases)
- [Whitepaper](whitepaper/Whitepaper.pdf)
- [Audits](audits)

## Architecture

- [`Vault.sol`](src/Vault.sol): Vault contract which keeps track of PnL and ensures secure and non-custodial deposit/withdrawal of funds during trading. There are 2 ways to do this:
  - `Keep a balance sheet`: Every deposit is recorded. During withdrawal, the deposit is returned +/- the PnL of the vault.
  - `Vault tokens`: Mint vault tokens and give them to user on deposit. During withdrawal, burn these tokens and return the invested funds (with PnL added).
- [`VaultFactory.sol`](src/VaultFactory.sol): Factory which enables deploying a Vault contract for any strategy.
- [`modules/`](src/modules): Contracts used for managing and/or simplifying interaction with Vaults and the Vault Factory.
  - [`VaultRouterModule.sol`](src/modules/VaultRouterModule.sol): Module that enables depositing ETH and approval-free deposits via permit.
  - [`VaultConfigurationModule.sol`](src/modules/VaultConfigurationModule.sol): Module for configuring Vault parameters.
  - [`VaultInitializationModule.sol`](src/modules/VaultInitializationModule.sol): Module for initializing newly created Vaults.
- [`interfaces/`](src/interfaces): Interfaces of external contracts Vaults and modules interact with.
  - [`Strategy.sol`](src/interfaces/Strategy.sol): Minimal interfaces for ERC20 and ETH compatible strategies.

![Diagram](assets/Vault%20architecture.drawio.png)

## Contributing

You will need a copy of [DappTools](https://dapp.tools) installed before proceeding. See the [installation guide](https://github.com/dapphub/dapptools#installation) for details.

### Setup

```sh
git clone https://github.com/Rari-Capital/vaults.git
cd vaults
make
```

### Run Tests

```sh
dapp test
```

### Measure Coverage

```sh
dapp test --coverage
```

### Update Gas Snapshots

```sh
dapp snapshot
```
