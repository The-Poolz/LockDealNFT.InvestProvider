// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestState.sol";
import "./InvestNonce.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "./interfaces/IVaultViews.sol";

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
     * 0x4a345075 - represent the bytes4(keccak256("_invest(uint256,uint256)"))
     */
    function _invest(
        uint256 poolId,
        uint256 amount
    ) internal firewallProtectedSig(0x4a345075) {
        _transferERC20Tokens(poolId, amount);
        _registerDispenser(poolId + 1, amount);
    }

    /// @notice Internal function to register the dispenser pool with the updated amount.
    /// 0xfa2d0f1e - represent the bytes4(keccak256("_registerDispenser(uint256,uint256)"))
    function _registerDispenser(
        uint256 dispenserPoolId,
        uint256 amount
    ) internal firewallProtectedSig(0xfa2d0f1e) {
        uint256[] memory dispenserParams = dispenserProvider.getParams(
            dispenserPoolId
        );
        dispenserParams[0] += amount;
        dispenserProvider.registerPool(dispenserPoolId, dispenserParams);
    }

    /// @notice Internal fucntion to mint a new dispenser pool.
    /// 0x899589df - represent the bytes4(keccak256("_createDispenser(address,uint256)"))
    function _createDispenser(
        address dispenserSigner,
        uint256 sourcePoolId
    ) internal firewallProtectedSig(0x899589df) {
        uint256 dispenserPoolId = lockDealNFT.mintForProvider(
            dispenserSigner,
            dispenserProvider
        );
        lockDealNFT.cloneVaultId(dispenserPoolId, sourcePoolId);
    }

    /// @notice Internal function to create a new investment pool.
    /// 0xdafc8a47 - represent the bytes4(keccak256("_createInvest(address,uint256)"))
    function _createInvest(
        address investSigner,
        uint256 sourcePoolId
    ) internal firewallProtectedSig(0xdafc8a47) returns (uint256 poolId) {
        poolId = lockDealNFT.mintForProvider(investSigner, this);
        lockDealNFT.cloneVaultId(poolId, sourcePoolId);
    }

    /// @notice Internal function to handle the investment process.
    /// @param poolId The ID of the pool to invest in.
    /// @param amount The amount to invest in the pool.
    /// 0x6767b0d5 - represent the bytes4(keccak256("_handleInvest(uint256,uint256)"))
    function _handleInvest(
        uint256 poolId,
        uint256 amount
    ) internal firewallProtectedSig(0x6767b0d5) returns (uint256 nonce) {
        nonce = _addInvestTrack(poolId, amount);
        _reduceAmount(poolId, amount);
        _invest(poolId, amount);
    }

    /// @notice Internal function to reduce the left amount of a pool.
    /// 0x352e82f5 - represent the bytes4(keccak256("_reduceAmount(uint256,uint256)"))
    function _reduceAmount(
        uint256 poolId,
        uint256 amount
    ) internal firewallProtectedSig(0x352e82f5) {
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
     * 0xf95354e5 - represent the bytes4(keccak256("_initializePool(address,address,uint256)"))
     */
    function _initializePool(
        address investSigner,
        address dispenserSigner,
        uint256 sourcePoolId
    ) internal firewallProtectedSig(0xf95354e5) returns (uint256 poolId) {
        poolId = _createInvest(investSigner, sourcePoolId);
        _createDispenser(dispenserSigner, sourcePoolId);
    }

    ///@notice Internal function to store the investment data.
    /// 0x71f83055 - represent the bytes4(keccak256("_storeInvestData(uint256,uint256)"))
    function _storeInvestData(
        uint256 poolId,
        uint256 amount
    ) internal firewallProtectedSig(0x71f83055) {
        poolIdToPool[poolId].maxAmount = amount;
        poolIdToPool[poolId].leftAmount = amount;
    }

    /// @notice Internal function to transfer ERC20 tokens to the vault.
    /// @param poolId The unique identifier for the pool.
    /// @param amount The amount of tokens to transfer.
    /// 0xb12177bc - represent the bytes4(keccak256("_transferERC20Tokens(uint256,uint256)"))
    function _transferERC20Tokens(
        uint256 poolId,
        uint256 amount
    ) internal firewallProtectedSig(0xb12177bc) {
        address token = lockDealNFT.tokenOf(poolId);
        IVaultViews vaultManager = IVaultViews(address(lockDealNFT.vaultManager()));
        uint256 vaultId = vaultManager.getCurrentVaultIdByToken(token);
        address vault = vaultManager.vaultIdToVault(vaultId);
        IERC20(token).safeTransferFrom(msg.sender, vault, amount);
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
