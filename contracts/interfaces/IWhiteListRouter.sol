// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IWhiteListRouter
 * @dev Interface for handling investment-related logic in the context of a whitelist.
 * The interface provides a method to handle investments based on a whitelist ID.
 */
interface IWhiteListRouter {
    /**
     * @notice Handles an investment made by a user in a whitelisted pool.
     * @dev This function verifies the user's investment against the whitelist ID and amount.
     * The actual logic of handling the investment is implemented in the contract that adopts this interface.
     * @param user The address of the user making the investment.
     * @param whiteListId The ID of the whitelist that governs the pool the user is investing in.
     * @param amount The amount of tokens the user is investing in the pool.
     */
    function handleInvestment(
        address user,
        uint256 whiteListId,
        uint256 amount
    ) external;
}
