// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@poolzfinance/poolz-helper-v2/contracts/interfaces/IProvider.sol";

/**
 * @title IInvestedProvider
 * @dev Interface for handling the creation and investment processes in an invested pool.
 * It extends the IProvider interface, adding specific methods for pool creation and investment.
 */
interface IInvestedProvider is IProvider {
    /**
     * @notice Called when a new investment pool is created.
     * @dev This function is expected to handle any setup or initialization logic for the new pool.
     * @param poolId The ID of the pool being created.
     * @param data Additional data passed during the creation of the pool.
     */
    function onCreation(uint256 poolId, bytes calldata data) external;

    /**
     * @notice Called when an investment is made in the pool.
     * @dev This function should handle the logic associated with processing the investment,
     * such as updating the pool's state or transferring funds.
     * @param poolId The ID of the pool receiving the investment.
     * @param amount The amount of the investment.
     * @param data Additional data passed during the investment process.
     */
    function onInvest(
        uint256 poolId,
        uint256 amount,
        bytes calldata data
    ) external;
}
