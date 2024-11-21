// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestModifiers.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title InvestInternal
/// @notice Provides internal functions for managing investment pools and parameters.
/// @dev Extends `InvestModifiers` and includes functionality to register and update pool data.
abstract contract InvestInternal is InvestModifiers {
    using SafeERC20 for IERC20;

    /**
     * @notice Registers or updates the parameters for a specific investment pool.
     * @param poolId The ID of the pool to register or update.
     * @param params An array of parameters to set for the pool. The expected order is:
     *  - `params[0]` - The maximum amount for the pool (`maxAmount`).
     *  - `params[1]` - The amount left for the pool (`leftAmount`).
     * @dev Emits the `UpdateParams` event after updating the pool data.
     */
    function _registerPool(uint256 poolId, uint256[] calldata params) internal {
        if (params[0] < params[1]) revert InvalidParams();
        IDO storage data = poolIdToPool[poolId];
        data.maxAmount = params[0];
        data.leftAmount = params[1];
        emit UpdateParams(poolId, params);
    }

    /**
     * @dev Internal function to handle pool creation logic.
     * @param investSigner The address of the signer for investments.
     * @param dispenserSigner The address of the signer for dispenses.
     * @param sourcePoolId The ID of the source pool to token clone.
     * @return poolId The ID of the newly created pool.
     */
    function _createPool(
        address investSigner,
        address dispenserSigner,
        uint256 sourcePoolId
    ) internal returns (uint256 poolId) {
        poolId = lockDealNFT.mintForProvider(investSigner, this);
        lockDealNFT.cloneVaultId(poolId, sourcePoolId);

        uint256 dispenserPoolId = lockDealNFT.mintForProvider(
            dispenserSigner,
            dispenserProvider
        );
        lockDealNFT.cloneVaultId(dispenserPoolId, sourcePoolId);
    }

    /**
     * @notice Internal function to process the investment by transferring tokens to the invested provider.
     * @param poolId The ID of the pool being invested in.
     * @param amount The amount being invested.
     * @param pool The pool data associated with the investment.
     * @dev Reduces the left amount of the pool and calls the `onInvest` method of the invested provider.
     */
    function _invest(
        uint256 poolId,
        uint256 amount,
        IDO storage pool
    ) internal {
        IERC20 token = IERC20(lockDealNFT.tokenOf(poolId));
        // address vaultManager = lockDealNFT.vaultManager();
        // uint256 vaultId = vaultManager.getCurrentVaultIdByToken();
        // adddress vault = vaultManager.vaultIdToVault(vaultId);
        // token.safeTransferFrom(
        //     msg.sender,
        //     vault,
        //     amount
        // );
        pool.leftAmount -= amount;
        uint256[] memory dispenserParams = dispenserProvider.getParams(
            poolId + 1
        );
        dispenserParams[0] += amount;
        dispenserProvider.registerPool(poolId + 1, dispenserParams);
    }
}
