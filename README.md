# LockDealNFT.InvestProvider

[![Build and Test](https://github.com/The-Poolz/LockDealNFT.InvestProvider/actions/workflows/node.js.yml/badge.svg)](https://github.com/The-Poolz/LockDealNFT.InvestProvider/actions/workflows/node.js.yml)
[![codecov](https://codecov.io/gh/The-Poolz/LockDealNFT.InvestProvider/graph/badge.svg?token=LTNmiM9c1L)](https://codecov.io/gh/The-Poolz/LockDealNFT.InvestProvider)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/The-Poolz/LockDealNFT.InvestProvider/blob/master/LICENSE)

**InvestProvider** contract is part of a system designed to facilitate the creation and management of investment pools. Contract allows users to invest in token pools and track investments securely. It integrates with other protocols, such as [LockDealNFT](https://github.com/The-Poolz/LockDealNFT), to mint and manage tokens.

### Navigation

-   [Installation](#installation)
-   [Overview](#overview)
-   [UML](#contracts-diagram)
-   [Create New Invest pool](#create-invest-pool)
-   [Join the Pool](#join-pool)
-   [License](#license)

## Installation

**Install the packages:**

```console
npm i
```

**Compile contracts:**

```console
npx hardhat compile
```

**Run tests:**

```console
npx hardhat test
```

**Run coverage:**

```console
npx hardhat coverage
```

**Deploy:**

```console
npx truffle dashboard
```

```console
npx hardhat run ./scripts/deploy.ts --network truffleDashboard
```

## Overview

**InvestProvider** enables the creation and management of investment pools, where users can join and make investments in various token pools. It supports interaction with the **LockDealNFT** contract to mint and transfer tokens based on the investments made.

**Key Features**

-   **Create Investment Pools:** Allows users to create pools with configurable parameters, such as maximum investment and participation rules.
-   **Join Investment Pools:** Users can invest in the pools with specific amounts and terms.
-   **Integration with LockDealNFT:** Supports NFT tokenization of investments, leveraging LockDealNFT for minting and handling tokens.
-   **Security:** Implements access control and signature-based authorization for pool creation and investment

## Contracts Diagram

## Create Invest Pool

`createNewPool` function allows the creation of a new investment pool and registers it with the system. This function takes a pool configuration, including the maximum investment amount and the provider responsible for managing the pool's investments. It also allows cloning an existing pool's settings from a source pool, ensuring that the new pool can inherit specific configurations from another.

```solidity
    /**
     * @notice Creates a new investment pool and registers it.
     * @param pool The pool configuration, including `maxAmount`, `whiteListId`, and `investedProvider`.
     * @param data Additional data for the pool creation.
     * @param sourcePoolId The ID of the source pool to token clone.
     * @return poolId The ID of the newly created pool.
     * @dev Emits the `NewPoolCreated` event upon successful creation.
     */
function createNewPool(
        Pool calldata pool,
        bytes calldata data,
        uint256 sourcePoolId
    )
```

```solidity
    struct Pool {
        uint256 maxAmount; // The maximum amount of tokens that can be invested in the pool
        uint256 poolId;
        IInvestedProvider investedProvider; // The provider that manages the invested funds for this pool
    }
```

## Join Pool

```solidity
function invest(
        uint256 poolId,
        uint256 amount,
        bytes calldata data
    )
```

## License

[The-Poolz](https://poolz.finance/) Contracts is released under the [MIT License](https://github.com/The-Poolz/LockDealNFT.InvestProvider/blob/master/LICENSE).
