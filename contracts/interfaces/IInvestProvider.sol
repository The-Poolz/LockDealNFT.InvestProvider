// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IInvestedProvider.sol";
import "@poolzfinance/poolz-helper-v2/contracts/interfaces/IProvider.sol";

/**
 * @title IInvestProvider
 * @dev Interface for managing investment pools, including investment actions and pool creation.
 * It extends the IProvider interface and defines additional functionality specific to investment pools.
 */
interface IInvestProvider is IProvider {
    /**
     * @notice Allows an address to invest in a specific IDO (Initial DEX Offering) pool.
     * @dev The function is used to transfer a specified amount of tokens into the pool.
     * It will trigger an investment in the associated provider, which implements the IInvestedProvider interface.
     * @param poolId The ID of the pool where the investment will occur.
     * @param amount The amount of tokens to be invested in the pool.
     * @param data Additional data associated with the investment process.
     */
    function invest(
        uint256 poolId,
        uint256 amount,
        uint256 validUntil,
        bytes calldata signature,
        bytes calldata data
    ) external;

    /**
     * @notice Creates a new investment pool.
     * @dev This function is used to create a new pool with the specified parameters, copying the settings of an existing source pool.
     * It will initialize the new pool with the given details and return its poolId.
     * @param pool The pool details to create the new pool.
     * @param data Additional data associated with the pool creation.
     * @param sourcePoolId The ID of the source pool to copy settings from.
     * @return poolId The ID of the newly created pool.
     */
    function createNewPool(
        Pool calldata pool,
        address signer,
        bytes calldata data,
        uint256 sourcePoolId
    ) external returns (uint256 poolId);

    /**
     * @dev Struct that represents an IDO pool, which contains the pool's configuration and the remaining investment amount.
     */
    struct IDO {
        Pool pool; // The pool configuration (maxAmount, whitelistId, investedProvider)
        uint256 leftAmount; // The amount of tokens left to invest in the pool
    }

    /**
     * @dev Struct that defines the pool configuration, including max investment amount, whitelist ID, and invested provider.
     */
    struct Pool {
        uint256 maxAmount; // The maximum amount of tokens that can be invested in the pool
        IInvestedProvider investedProvider; // The provider that manages the invested funds for this pool
    }

    /**
     * @notice Emitted when a user successfully invests in a pool.
     * @param poolId The ID of the pool where the investment was made.
     * @param user The address of the user who made the investment.
     * @param amount The amount of tokens that were invested.
     */
    event Invested(
        uint256 indexed poolId,
        address indexed user,
        uint256 amount
    );

    /**
     * @notice Emitted when a new pool is successfully created.
     * @param poolId The ID of the newly created pool.
     * @param pool The details of the new pool.
     */
    event NewPoolCreated(uint256 indexed poolId, IDO pool);

    error InvalidLockDealNFT();
    error InvalidInvestedProvider();
    error InvalidProvider();
    error InvalidPoolId();
    error OnlyLockDealNFT();
    error NoZeroAddress();
    error NoZeroAmount();
    error ExceededLeftAmount();
    error InvalidParamsLength(uint256 paramsLength, uint256 minLength);
    error InvalidSignature(uint256 poolId, address owner);
}
