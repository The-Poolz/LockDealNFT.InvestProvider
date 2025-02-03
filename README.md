# LockDealNFT.InvestProvider

[![Build and Test](https://github.com/The-Poolz/LockDealNFT.InvestProvider/actions/workflows/node.js.yml/badge.svg)](https://github.com/The-Poolz/LockDealNFT.InvestProvider/actions/workflows/node.js.yml)
[![codecov](https://codecov.io/gh/The-Poolz/LockDealNFT.InvestProvider/graph/badge.svg?token=LTNmiM9c1L)](https://codecov.io/gh/The-Poolz/LockDealNFT.InvestProvider)
[![CodeFactor](https://www.codefactor.io/repository/github/the-poolz/LockDealNFT.InvestProvider/badge)](https://www.codefactor.io/repository/github/the-poolz/LockDealNFT.InvestProvider)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/The-Poolz/LockDealNFT.InvestProvider/blob/master/LICENSE)

**InvestProvider** is a contract enabling the creation and management of **Investment Pools (IDO Pools)**. It allows users to invest in pools by contributing tokens, such as stablecoins, in exchange for tokens issued by the **IDO project**. The contract manages pool creation, investments, and enforces compliance with defined limits while tracking available tokens.

### Navigation

-   [Installation](#installation)
-   [Overview](#overview)
-   [UML](#investprovider-diagram)
-   [Create New IDO pool](#create-ido-pool)
-   [Join the Pool](#join-pool)
-   [Investment Pool data](#pool-data)
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

-   **Create Investment Pools:** Configure pools with parameters such as maximum investment limits, pool owners, and investment signers.
-   **Join Investment Pools:** Users can invest in the pools with specific amounts and terms.
-   **Advanced Authorization:** Uses signature-based authorization to ensure secure and valid investment operations.
-   **Integration with LockDealNFT:** Leverages NFT tokenization for flexible and transparent investment management.

## InvestProvider Diagram

![classDiagram](https://github.com/user-attachments/assets/a8c51951-e14d-4a87-b8c9-37170208d3fc)

## Create IDO Pool

There are two functions available for creating **Investment Pools (IDO Pools)** in the **InvestProvider** contract. Both functions allow the creation of a new pool with a configurable amount, but they differ in how they handle the investment and dispenser signers.

### 1. createNewPool (with signers)

This function creates a new pool and requires specifying both the investment signer and dispenser signer addresses. These signers are responsible for verifying investments and handling token dispensations.

```solidity
/**
 * @notice Creates a new investment pool and registers it.
 * @param poolAmount The amount to allocate to the pool.
 * @param investSigner The address of the signer for investments.
 * @param dispenserSigner The address of the signer for dispenses.
 * @param sourcePoolId The ID of the source pool to clone settings from.
 * @return poolId The ID of the newly created pool.
 * @dev Emits the `NewPoolCreated` event upon successful creation.
 */
function createNewPool(
    uint256 poolAmount,
    address investSigner,
    address dispenserSigner,
    uint256 sourcePoolId
) external;
```

This function is suitable for scenarios where specific signers for investments and dispensing are required.

### 2. createNewPool (without explicit signers)

This variant creates a new pool, but the investment signer and dispenser signer default to the sender's address (i.e., the account calling the function). It also allows cloning settings from an existing pool.

```solidity
/**
 * @notice Creates a new investment pool and registers it.
 * @param poolAmount The amount to allocate to the pool.
 * @param sourcePoolId The ID of the source pool to clone settings from.
 * @return poolId The ID of the newly created pool.
 * @dev Emits the `NewPoolCreated` event upon successful creation.
 */
function createNewPool(
    uint256 poolAmount,
    uint256 sourcePoolId
) external;
```

In this case, both the investment signer and dispenser signer default to the caller’s address **(msg.sender)**. This is useful for simpler cases where the same address is responsible for managing both investments and token dispensations.

### Summary of Differences

| Function                                                  | Signer Parameters                                           | Purpose                                                     |
| --------------------------------------------------------- | ----------------------------------------------------------- | ----------------------------------------------------------- |
| `createNewPool(uint256, address, address, uint256)` | Requires explicit signers for investments and dispensations | Full control over signers for customized pool management    |
| `createNewPool(uint256, uint256)`                   | Uses `msg.sender` for both signers                          | Simpler pool creation where the caller manages both actions |

## Join Pool

The investment functions allow users to participate in investment pools by contributing tokens. These functions process contributions and update the pool’s state accordingly.

To ensure **secure and verifiable investments**, the protocol employs **EIP-712** structured data signing. Investors must send an **InvestMessage** containing their investment details before submitting a transaction.

📌 **Reference JSON Message Format:** [**View message**](https://github.com/The-Poolz/LockDealNFT.InvestProvider/issues/63#issuecomment-2597295898)

```solidity
/**
 * @dev Struct that represents a message to be signed by the user for investing in a pool.
 */
struct InvestMessage {
    uint256 poolId;
    address user;
    uint256 amount;
    uint256 validUntil;
    uint256 nonce;
}
```

### Investing with ERC20 Tokens

Before participating in an investment pool, users must approve the **InvestProvider** address to spend the required amount of the **ERC20** token they intend to invest.

```solidity
/**
 * @notice Allows a user to invest in an IDO pool.
 * @param poolId The ID of the pool.
 * @param amount The amount to invest.
 * @param validUntil The timestamp until the signature is valid.
 * @param signature The cryptographic signature validating the investment.
 * @dev Emits the `Invested` event upon success.
 */
function invest(
    uint256 poolId,
    uint256 amount,
    uint256 validUntil,
    bytes calldata signature
) external;
```

### Event: Invested

```solidity
event Invested(
    uint256 indexed poolId,
    address indexed user,
    uint256 amount,
    uint256 newNonce
);
```

Emitted when a user successfully invests in a pool.

-   **poolId →** The pool's ID.
-   **user →** Address of the investor.
-   **amount →** Tokens invested
-   **newNonce →** Updated nonce after the investment

### InvestedProvider NFT

Upon completing an investment, the investor receives an **InvestedProvider NFT**, serving as proof of participation in the pool.

#### Key Properties of InvestedProvider NFT

-   It represents the investor's participation in the pool.
-   It may provide additional benefits or governance rights, depending on the pool rules.
-   It cannot be split into smaller parts, unlike other provider **NFTs**.
-   It cannot be withdrawn to redeem tokens.

For more details, check out the **InvestedProvider** repository:
[GitHub: LockDealNFT.InvestedProvider](https://github.com/The-Poolz/LockDealNFT.InvestedProvider)

## Pool data

**InvestProvider** contract provides a convenient way to monitor the details of investment pools, including the maximum amount of tokens that can be invested and the remaining tokens available for investment. This is achieved using the `poolIdToPool` view function.

```solidity
function poolIdToPool(uint256 investPoolId) external view returns (Pool data);
```

```solidity
    struct Pool {
        uint256 maxAmount; // The maximum amount of tokens that can be invested in the pool
        uint256 leftAmount; // The amount of tokens left to invest in the pool
    }
```

This function allows users to retrieve information about a specific pool by its poolId.

## License

[The-Poolz](https://poolz.finance/) Contracts is released under the [MIT License](https://github.com/The-Poolz/LockDealNFT.InvestProvider/blob/master/LICENSE).
