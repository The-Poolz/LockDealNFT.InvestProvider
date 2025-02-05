// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestModifiers.sol";
import "@poolzfinance/poolz-helper-v2/contracts/CalcUtils.sol";

abstract contract InvestManagement is InvestModifiers {
    using CalcUtils for uint256;

    /**
     * @notice Registers a new pool with the specified parameters.
     * @param poolId The ID of the pool to register.
     * @param params The parameters for the pool, including `maxAmount`, `leftAmount`
     * @dev Ensures that the parameters match the expected length and are valid.
     */
    function registerPool(
        uint256 poolId,
        uint256[] calldata params
    )
        external
        override
        firewallProtected
        onlyProvider
        validParamsLength(params.length, currentParamsTargetLength())
    {
        _registerPool(poolId, params);
    }

    /**
     * @notice When called, the pool is marked as inactive.
     * @return withdrawnAmount Returns the withdrawable amount (always 0 in this contract).
     * @return isFinal Returns `true` to indicate that the pool is inactive.
     */
    function withdraw(
        uint256
    )
        external
        firewallProtected
        onlyNFT
        returns (uint256 withdrawnAmount, bool isFinal)
    {
        withdrawnAmount = 0;
        isFinal = true;
    }

    /**
     * @notice Splits an old pool into a new pool with a specified ratio.
     * @param oldPoolId The ID of the old pool to split.
     * @param newPoolId The ID of the new pool to create.
     * @param ratio The ratio to split the amounts between the old and new pools.
     * @dev Reduces the amounts of the old pool and creates the new pool with the calculated amounts.
     */
    function split(
        uint256 oldPoolId,
        uint256 newPoolId,
        uint256 ratio
    ) external firewallProtected onlyNFT {
        uint256 newPoolMaxAmount = poolIdToPool[oldPoolId].maxAmount.calcAmount(ratio);
        uint256 newPoolLeftAmount = poolIdToPool[oldPoolId].leftAmount.calcAmount(ratio);
        // reduce the max amount and leftAmount of the old pool
        poolIdToPool[oldPoolId].maxAmount -= newPoolMaxAmount;
        poolIdToPool[oldPoolId].leftAmount -= newPoolLeftAmount;
        // create a new pool with the new settings
        poolIdToPool[newPoolId].maxAmount = newPoolMaxAmount;
        poolIdToPool[newPoolId].leftAmount = newPoolLeftAmount;
        // create dispenser
        _createDispenser(oldPoolId + 1);
    }

    /**
     * @notice Returns the withdrawable amount (always 0 in this contract).
     * @return The withdrawable amount (0).
     */
    function getWithdrawableAmount(uint256) external pure returns (uint256) {
        return 0;
    }

    /**
     * @notice Registers or updates the parameters for a specific investment pool.
     * @param poolId The ID of the pool to register or update.
     * @param params An array of parameters to set for the pool. The expected order is:
     *  - `params[0]` - The maximum amount for the pool (`maxAmount`).
     *  - `params[1]` - The amount left for the pool (`leftAmount`).
     * @dev Emits the `UpdateParams` event after updating the pool data.
     * 0xdf3aac25 - represent the bytes4(keccak256("_registerPool(uint256,uint256[])"))
     */
    function _registerPool(uint256 poolId, uint256[] calldata params) internal firewallProtectedSig(0xdf3aac25) {
        if (params[0] < params[1]) revert InvalidParams();
        Pool storage data = poolIdToPool[poolId];
        data.maxAmount = params[0];
        data.leftAmount = params[1];
        emit UpdateParams(poolId, params);
    }
    
    /// @notice for dispenser split
    /// 0xd5916799 - represent the bytes4(keccak256("_createDispenser(uint256)"))
    function _createDispenser(uint256 dispenserPoolId) internal firewallProtectedSig(0xd5916799) {
        // Retrieve the signer of the specified dispenser
        address dispenserSigner = lockDealNFT.ownerOf(dispenserPoolId);
        // Create a new dispenser linked to the same signer
        _createDispenser(dispenserPoolId, dispenserSigner);
    }
}
