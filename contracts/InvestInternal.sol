// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestState.sol";
import "./InvestNonce.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title InvestInternal
/// @notice Provides internal functions for managing investment pools and parameters.
/// @dev Extends `InvestState` and includes functionality to register and update pool data.
abstract contract InvestInternal is InvestState, InvestNonce, EIP712 {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /**
     * @notice Internal function to process the investment by transferring tokens to the invested provider.
     * @param poolId The ID of the pool being invested in.
     * @param amount The amount being invested.
     * @dev Reduces the left amount of the pool and calls the `onInvest` method of the invested provider.
     */
    function _invest(uint256 poolId, uint256 amount) internal {
        _invested(poolId, amount);
        _registerDispenser(poolId + 1, amount);
    }

    /// @notice Internal function to register the dispenser pool with the updated amount.
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

    function _createDispenser(uint256 sourceId, address signer) internal {
        uint256 dispenserPoolId = lockDealNFT.mintForProvider(signer, dispenserProvider);
        lockDealNFT.cloneVaultId(dispenserPoolId, sourceId);
    }

    function _createInvest(address investSigner, uint256 sourcePoolId) internal returns (uint256 poolId) {
        poolId = lockDealNFT.mintForProvider(investSigner, this);
        lockDealNFT.cloneVaultId(poolId, sourcePoolId);
    }

    /// @notice Internal function to handle the investment process.
    /// @param poolId The ID of the pool to invest in.
    /// @param amount The amount to invest in the pool.
    function _handleInvest(
        uint256 poolId,
        uint256 amount
    ) internal returns (uint256 nonce) {
        nonce = _addInvestTrack(poolId, amount);
        _reduceAmount(poolId, amount);
        _invest(poolId, amount);
    }

    /// @notice Internal function to reduce the left amount of a pool.
    function _reduceAmount(uint256 poolId, uint256 amount) internal {
        Pool storage poolData = poolIdToPool[poolId];
        if (poolData.leftAmount < amount) revert ExceededLeftAmount();
        poolData.leftAmount -= amount;
    }

    /**
     * @dev Internal function to initialize a pool.
     * @param investSigner The address of the signer for investments.
     * @param dispenserSigner The address of the signer for dispenses.
     * @param sourcePoolId The ID of the source pool to token clone.
     * @return poolId The ID of the newly created pool.
     */
    function _initializePool(
        address investSigner,
        address dispenserSigner,
        uint256 sourcePoolId
    ) internal returns (uint256 poolId) {
        poolId = _createInvest(investSigner, sourcePoolId);
        _createDispenser(sourcePoolId, dispenserSigner);
    }

    ///@notice Internal function to store the investment data.
    function _storeInvestData(uint256 poolId, uint256 amount) internal {
        poolIdToPool[poolId].maxAmount = amount;
        poolIdToPool[poolId].leftAmount = amount;
    }
    
    /// @notice Internal function to process the investment by transferring tokens.
    /// @param investPoolId The ID of the pool being invested in.
    /// @param amount The amount being invested.
    function _invested(uint256 investPoolId, uint256 amount) internal {
        address token = lockDealNFT.tokenOf(investPoolId);
        IERC20(token).safeTransferFrom(msg.sender, address(lockDealNFT), amount);
        lockDealNFT.mintAndTransfer(msg.sender, token, amount, investedProvider);
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
