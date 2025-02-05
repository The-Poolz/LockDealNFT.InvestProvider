// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestManagement.sol";

abstract contract InvestCreation is InvestManagement {
    /**
     * @notice Creates a new investment pool and registers it.
     * @param poolAmount The amount to allocate to the pool.
     * @param investSigner The address of the signer for investments.
     * @param dispenserSigner The address of the signer for dispenses.
     * @param sourcePoolId The ID of the source pool to token clone.
     * @return poolId The ID of the newly created pool.
     * @dev Emits the `NewPoolCreated` event upon successful creation.
     */
    function createNewPool(
        uint256 poolAmount,
        address investSigner,
        address dispenserSigner,
        uint256 sourcePoolId
    )
        external
        firewallProtected
        notZeroAddress(investSigner)
        notZeroAddress(dispenserSigner)
        notZeroAmount(poolAmount)
        isValidSourcePoolId(sourcePoolId)
        returns (uint256 poolId)
    {
        poolId = _createNewPool(
            poolAmount,
            investSigner,
            dispenserSigner,
            sourcePoolId
        );
    }

    /**
     * @notice Creates a new investment pool and registers it.
     * @param poolAmount The amount to allocate to the pool.
     * @param sourcePoolId The ID of the source pool to token clone.
     * @return poolId The ID of the newly created pool.
     * @dev Emits the `NewPoolCreated` event upon successful creation.
     */
    function createNewPool(
        uint256 poolAmount,
        uint256 sourcePoolId
    )
        external
        firewallProtected
        notZeroAmount(poolAmount)
        isValidSourcePoolId(sourcePoolId)
        returns (uint256 poolId)
    {
        poolId = _createNewPool(
            poolAmount,
            msg.sender,
            msg.sender,
            sourcePoolId
        );
    }

    /// @dev Internal function to create a new pool.
    /// @param poolAmount The amount to allocate to the pool.
    /// @param investSigner The address of the signer for investments.
    /// @param dispenserSigner The address of the signer for dispenses.
    /// @param sourcePoolId The ID of the source pool to token clone.
    /// @return poolId The ID of the newly created pool.
    /// 0xa328ce07 - represent the bytes4(keccak256("_createNewPool(uint256,address,address,uint256)"))
    function _createNewPool(
        uint256 poolAmount,
        address investSigner,
        address dispenserSigner,
        uint256 sourcePoolId
    ) internal firewallProtectedSig(0xa328ce07) returns (uint256 poolId) {
        poolId = _initializePool(investSigner, dispenserSigner, sourcePoolId);
        _storeInvestData(poolId, poolAmount);
        emit NewPoolCreated(poolId, investSigner, poolAmount);
    }
}
