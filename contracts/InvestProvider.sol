// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestInternal.sol";
import "@poolzfinance/poolz-helper-v2/contracts/CalcUtils.sol";

/// @title InvestProvider
/// @notice This contract provides functionality for creating investment pools, managing investments.
/// @dev Inherits from `InvestInternal` and includes logic to create, invest, and split pools, as well as withdraw funds. It uses `SafeERC20` for token transfers and `CalcUtils` for mathematical operations.
contract InvestProvider is InvestInternal {
    using CalcUtils for uint256;

    /// @dev Constructor to initialize the contract with a `lockDealNFT`.
    /// @param _lockDealNFT The address of the `ILockDealNFT` contract.
    /// @param _dispenserProvider The address of the `IProvider` contract for dispensers.
    constructor(ILockDealNFT _lockDealNFT, IProvider _dispenserProvider) {
        if (address(_lockDealNFT) == address(0)) revert NoZeroAddress();
        if (address(_dispenserProvider) == address(0)) revert NoZeroAddress();
        lockDealNFT = _lockDealNFT;
        dispenserProvider = _dispenserProvider;
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
        override
        firewallProtected
        notZeroAddress(investSigner)
        notZeroAddress(dispenserSigner)
        notZeroAmount(poolAmount)
        returns (uint256 poolId)
    {
        uint256 investPoolId = _createPool(
            investSigner,
            dispenserSigner,
            sourcePoolId
        );
        poolIdToPool[investPoolId].maxAmount = poolAmount;
        poolIdToPool[investPoolId].leftAmount = poolAmount;
        emit NewPoolCreated(poolId, poolIdToPool[poolId]);
    }

    function createNewPool(
        uint256 poolAmount,
        uint256 sourcePoolId
    )
        external
        override
        firewallProtected
        notZeroAmount(poolAmount)
        returns (uint256 poolId)
    {
        uint256 investPoolId = _createPool(
            msg.sender,
            msg.sender,
            sourcePoolId
        );
        poolIdToPool[investPoolId].maxAmount = poolAmount;
        poolIdToPool[investPoolId].leftAmount = poolAmount;
        emit NewPoolCreated(poolId, poolIdToPool[poolId]);
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
        override
        firewallProtected
        notZeroAmount(amount)
        invalidProvider(poolId, this)
        isValidSignature(poolId, validUntil, amount, signature)
    {
        IDO storage poolData = poolIdToPool[poolId];
        if (poolData.leftAmount < amount) revert ExceededLeftAmount();

        _invest(poolId, amount, poolData);
        emit Invested(poolId, msg.sender, amount);
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
     * @notice Retrieves the current parameters for a pool.
     * @param poolId The ID of the pool to fetch parameters for.
     * @return params The parameters for the pool, including `maxAmount`, `leftAmount``.
     */
    function getParams(
        uint256 poolId
    ) external view override returns (uint256[] memory params) {
        IDO storage poolData = poolIdToPool[poolId];
        params = new uint256[](2);
        params[0] = poolData.maxAmount;
        params[1] = poolData.leftAmount;
    }

    /**
     * @notice Withdraws funds from the contract (currently not implemented).
     * @return The withdrawable amount and a flag indicating whether withdrawal was successful.
     * @dev Always reverts as the function is not implemented.
     */
    function withdraw(
        uint256
    ) external firewallProtected onlyNFT returns (uint256, bool) {
        revert();
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
    }

    /**
     * @notice Returns the withdrawable amount (always 0 in this contract).
     * @return The withdrawable amount (0).
     */
    function getWithdrawableAmount(
        uint256
    ) public view virtual override returns (uint256) {
        return 0;
    }

    /**
     * @notice Retrieves the pool IDs associated with a sub-provider.
     * @param poolID The ID of the pool to retrieve sub-provider pool IDs for.
     * @return poolIds An array containing the sub-provider pool IDs.
     */
    function getSubProvidersPoolIds(
        uint256 poolID
    )
        public
        pure
        override(IProvider, ProviderState)
        returns (uint256[] memory poolIds)
    {
        poolIds = new uint256[](1);
        poolIds[0] = poolID;
    }
}
