// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestModifiers.sol";

/// @title InvestInternal
/// @notice Provides internal functions for managing investment pools and parameters.
/// @dev Extends `InvestModifiers` and includes functionality to register and update pool data.
abstract contract InvestInternal is InvestModifiers {
    /**
     * @notice Registers or updates the parameters for a specific investment pool.
     * @param poolId The ID of the pool to register or update.
     * @param params An array of parameters to set for the pool. The expected order is:
     *  - `params[0]` - The maximum amount for the pool (`maxAmount`).
     *  - `params[1]` - The amount left for the pool (`leftAmount`).
     *  - `params[2]` - The whitelist ID associated with the pool (`whiteListId`).
     * @dev Emits the `UpdateParams` event after updating the pool data.
     */
    function _registerPool(uint256 poolId, uint256[] calldata params) internal {
        IDO storage data = poolIdToPool[poolId];
        data.pool.maxAmount = params[0];
        data.leftAmount = params[1];
        emit UpdateParams(poolId, params);
    }
}
