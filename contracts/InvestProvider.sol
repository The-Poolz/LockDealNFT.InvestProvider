// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestModifiers.sol";

/// @title InvestProvider
/// @notice This contract provides functionality for creating investment pools, managing investments.
/// @dev Inherits from `InvestModifiers` and includes logic to create, invest, and split pools, as well as withdraw funds. It uses `SafeERC20` for token transfers and `CalcUtils` for mathematical operations.
abstract contract InvestProvider is InvestModifiers {
    using CalcUtils for uint256;

    /// @dev Constructor to initialize the contract with a `lockDealNFT`.
    /// @param _lockDealNFT The address of the `ILockDealNFT` contract.
    /// @param _dispenserProvider The address of the `IProvider` contract for dispensers.
    /// @param _investedProvider The address of the `IProvider` contract for invested providers.
    constructor(
        ILockDealNFT _lockDealNFT,
        IProvider _dispenserProvider,
        IProvider _investedProvider
    ) EIP712("InvestProvider", "1") {
        if (address(_lockDealNFT) == address(0)) revert NoZeroAddress();
        if (address(_dispenserProvider) == address(0)) revert NoZeroAddress();
        if (address(_investedProvider) == address(0)) revert NoZeroAddress();
        lockDealNFT = _lockDealNFT;
        dispenserProvider = _dispenserProvider;
        investedProvider = _investedProvider;
        name = "InvestProvider";
    }

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
        poolId = _initializePool(
            investSigner,
            dispenserSigner,
            sourcePoolId
        );
        _storeInvestData(poolId, poolAmount);
        emit NewPoolCreated(poolId, investSigner, poolAmount);
    }

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
        poolId = _initializePool(
            msg.sender,
            msg.sender,
            sourcePoolId
        );
        _storeInvestData(poolId, poolAmount);
        emit NewPoolCreated(poolId, msg.sender, poolAmount);
    }

    /**
     * @notice Allows an address to invest a specified amount into a pool.
     * @param poolId The ID of the pool to invest in.
     * @param amount The amount to invest.
     * @param signature The signature to validate the investment.
     * @param validUntil The expiration time for the signature.
     * @dev Emits the `Invested` event after a successful investment.
     */
    function invest(
        uint256 poolId,
        uint256 amount,
        uint256 validUntil,
        bytes calldata signature
    )
        external
        firewallProtected
        notZeroAmount(amount)
        isValidInvestProvider(poolId)
        isPoolActive(poolId)
        isValidTime(validUntil)
        isValidSignature(poolId, validUntil, amount, signature)
    {
        uint256 nonce = _handleInvest(poolId, amount);
        emit Invested(poolId, msg.sender, amount, nonce);
    }

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
    ) external firewallProtected onlyNFT returns (uint256 withdrawnAmount, bool isFinal) {
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
}
