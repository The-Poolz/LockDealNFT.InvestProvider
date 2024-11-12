# LockDealNFT.InvestProvider

[![Build and Test](https://github.com/The-Poolz/LockDealNFT.InvestProvider/actions/workflows/node.js.yml/badge.svg)](https://github.com/The-Poolz/LockDealNFT.InvestProvider/actions/workflows/node.js.yml)
[![codecov](https://codecov.io/gh/The-Poolz/LockDealNFT.InvestProvider/graph/badge.svg?token=LTNmiM9c1L)](https://codecov.io/gh/The-Poolz/LockDealNFT.InvestProvider)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/The-Poolz/LockDealNFT.InvestProvider/blob/master/LICENSE)

**InvestProvider** is a contract that enables the creation and management of **Investment Pools (IDO Pools)**, allowing users to join pools by contributing funds (typically in stablecoins or other assets) in exchange for tokens issued by the **IDO project**. The contract handles pool creation, contributions, while ensuring compliance with investment limits and tracking remaining available tokens.

### Navigation

-   [Installation](#installation)
-   [Overview](#overview)
-   [UML](#contracts-diagram)
-   [Create New IDO pool](#create-ido-pool)
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

**InvestProvider** facilitates the creation and management of investment pools, enabling users to join various token pools. It integrates with the [LockDealNFT](https://github.com/The-Poolz/LockDealNFT) contract to mint and transfer tokens based on users' investments.

**Key Features**

-   **Create Investment Pools:** Allows users to create pools with configurable parameters, such as maximum investment and participation rules.
-   **Join Investment Pools:** Users can invest in the pools with specific amounts and terms.
-   **Integration with LockDealNFT:** Supports NFT tokenization of investments, leveraging LockDealNFT for minting and handling tokens.
-   **Security:** Implements access control and signature-based authorization for pool creation and investment

## Contracts Diagram

## Create IDO Pool

`createNewPool` function enables the creation of a new **IDO pool**, which is registered with the system. This function accepts a pool configuration, including the maximum investment amount, the provider managing the pool, and optionally cloning an existing pool's settings. This is ideal for creating **IDO pools** where the pool owner can manage the pool's parameters.

```solidity
    /**
    * @notice Creates a new IDO investment pool and registers it.
    * @param pool The pool configuration, including `maxAmount`, `whiteListId`, and `investedProvider`.
    * @param data Additional data for the pool creation.
    * @param sourcePoolId The ID of the source pool to clone settings from.
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
        uint256 maxAmount; // Maximum amount of tokens that can be invested in the pool
        uint256 poolId;    // Unique identifier for the pool
        IInvestedProvider investedProvider; // Provider that manages the invested funds
    }
```

This function allows you to set parameters like the maximum investment and the provider responsible for managing investments. It also supports cloning an existing pool's settings by referencing a `sourcePoolId`.

## Join Pool

`invest` function allows users to join an **IDO pool** by contributing a specified amount. It processes the user's contribution and updates the pool’s data accordingly. This function requires the user to specify the pool ID, the amount to contribute, and additional data necessary for the transaction.

```solidity
    /**
     * @notice function allows users to invest in an IDO pool by specifying.
     * @param poolId The ID of the pool to invest in.
     * @param amount The amount to invest.
     * @param data Additional data for the investment.
     * @dev Emits the `Invested` event after a successful investment.
     */
function invest(
        uint256 poolId,
        uint256 amount,
        bytes calldata data
    )
```

## License

[The-Poolz](https://poolz.finance/) Contracts is released under the [MIT License](https://github.com/The-Poolz/LockDealNFT.InvestProvider/blob/master/LICENSE).
