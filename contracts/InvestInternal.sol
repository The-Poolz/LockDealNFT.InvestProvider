// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestState.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@poolzfinance/poolz-helper-v2/contracts/CalcUtils.sol";
import "./interfaces/IVaultViews.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title InvestInternal
/// @notice Provides internal functions for managing investment pools and parameters.
/// @dev Extends `InvestState` and includes functionality to register and update pool data.
abstract contract InvestInternal is InvestState, EIP712 {
    using SafeERC20 for IERC20;
    using CalcUtils for uint256;
    using ECDSA for bytes32;

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
        Pool storage data = poolIdToPool[poolId];
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

        _createDispenser(sourcePoolId, dispenserSigner);
    }

    /**
     * @notice Internal function to process the investment by transferring tokens to the invested provider.
     * @param poolId The ID of the pool being invested in.
     * @param amount The amount being invested.
     * @dev Reduces the left amount of the pool and calls the `onInvest` method of the invested provider.
     */
    function _invest(uint256 poolId, uint256 amount) internal {
        _invested(amount, poolId);
        _registerDispenser(poolId + 1, amount);
    }

    function _registerDispenser(
        uint256 dispenserPoolId,
        uint256 amount
    ) internal {
        uint256[] memory dispenserParams = dispenserProvider.getParams(
            dispenserPoolId
        );
        dispenserParams[0] += amount;
        dispenserProvider.registerPool(dispenserPoolId, dispenserParams);
    }

    function _createDispenser(uint256 dispenserPoolId) internal {
        // Retrieve the signer of the specified dispenser
        address dispenserSigner = lockDealNFT.ownerOf(dispenserPoolId);
        // Create a new dispenser linked to the same signer
        _createDispenser(dispenserPoolId, dispenserSigner);
    }

    function _createDispenser(uint256 sourceId, address signer) internal {
        uint256 dispenserPoolId = lockDealNFT.mintForProvider(signer, dispenserProvider);
        lockDealNFT.cloneVaultId(dispenserPoolId, sourceId);
    }

    function _invested(uint256 amount, uint256 sourceId) internal {
        address token = lockDealNFT.tokenOf(sourceId);
        IERC20(token).safeTransferFrom(msg.sender, address(lockDealNFT), amount);
        uint256 poolId = lockDealNFT.mintAndTransfer(msg.sender, token, amount, investedProvider);
        // register the amount in the invested provider
        uint256[] memory params = new uint256[](2);
        params[0] = amount;
        params[1] = sourceId;
        investedProvider.registerPool(poolId, params);
    }
    
    /// @notice Verifies the cryptographic signature for a given pool and data.
    /// @param poolId The unique identifier for the pool.
    /// @param data The data associated with the transaction.
    /// @param signature The cryptographic signature verifying the transaction.
    /// @return bool True if the signature is valid for the given data, otherwise false.
    function _verify(
        uint256 poolId,
        bytes memory data,
        bytes calldata signature
    ) internal view returns (bool) {
        bytes32 hash = _hashTypedDataV4(keccak256(data));
        address signer = ECDSA.recover(hash, signature);
        return signer == lockDealNFT.getData(poolId).owner;
    }
}
