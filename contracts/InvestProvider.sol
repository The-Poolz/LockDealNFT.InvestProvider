// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestInternal.sol";
import "@poolzfinance/poolz-helper-v2/contracts/CalcUtils.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title InvestProvider
/// @notice This contract provides functionality for creating investment pools, managing investments, and interacting with whitelisted users.
/// @dev Inherits from `InvestInternal` and includes logic to create, invest, and split pools, as well as withdraw funds. It uses `SafeERC20` for token transfers and `CalcUtils` for mathematical operations.
contract InvestProvider is InvestInternal {
    using CalcUtils for uint256;
    using SafeERC20 for IERC20;

    /// @dev Constructor to initialize the contract with a `lockDealNFT`.
    /// @param _lockDealNFT The address of the `ILockDealNFT` contract.
    constructor(ILockDealNFT _lockDealNFT) {
        if (address(_lockDealNFT) == address(0)) revert NoZeroAddress();
        lockDealNFT = _lockDealNFT;
        name = "InvestProvider";
    }

    /**
     * @notice Creates a new investment pool and registers it.
     * @param pool The pool configuration, including `maxAmount`, `whiteListId`, and `investedProvider`.
     * @param signer The address of the signer for the pool creation.
     * @param data Additional data for the pool creation.
     * @param sourcePoolId The ID of the source pool to token clone.
     * @return poolId The ID of the newly created pool.
     * @dev Emits the `NewPoolCreated` event upon successful creation.
     */
    function createNewPool(
        Pool calldata pool,
        address signer,
        bytes calldata data,
        uint256 sourcePoolId
    )
        external
        override
        firewallProtected
        notZeroAmount(pool.maxAmount)
        notZeroAddress(address(pool.investedProvider))
        validInvestedProvider(pool.investedProvider)
        returns (uint256 poolId)
    {
        poolId = lockDealNFT.mintForProvider(msg.sender, this);
        lockDealNFT.cloneVaultId(poolId, sourcePoolId);
        poolIdToPool[poolId].pool = pool;
        poolIdToPool[poolId].leftAmount = pool.maxAmount;
        pool.investedProvider.onCreation(poolId, signer, data);
        emit NewPoolCreated(poolId, poolIdToPool[poolId]);
    }

    /**
     * @notice Allows an address to invest a specified amount into a pool.
     * @param poolId The ID of the pool to invest in.
     * @param amount The amount to invest.
     * @param signature The signature to validate the investment.
     * @param validUntil The expiration time for the signature.
     * @param data Additional data for the investment.
     * @dev Emits the `Invested` event after a successful investment.
     */
    function invest(
        uint256 poolId,
        uint256 amount,
        uint256 validUntil,
        bytes calldata signature,
        bytes calldata data
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

        _invest(poolId, amount, poolData, data);
        emit Invested(poolId, msg.sender, amount);
    }

    /**
     * @notice Internal function to process the investment by transferring tokens to the invested provider.
     * @param poolId The ID of the pool being invested in.
     * @param amount The amount being invested.
     * @param pool The pool data associated with the investment.
     * @param data Additional data for the investment.
     * @dev Reduces the left amount of the pool and calls the `onInvest` method of the invested provider.
     */
    function _invest(
        uint256 poolId,
        uint256 amount,
        IDO storage pool,
        bytes calldata data
    ) internal {
        IERC20 token = IERC20(lockDealNFT.tokenOf(poolId));
        token.safeTransferFrom(
            msg.sender,
            address(pool.pool.investedProvider),
            amount
        );
        pool.pool.investedProvider.onInvest(poolId, amount, data);
        pool.leftAmount -= amount;
    }

    /**
     * @notice Registers a new pool with the specified parameters.
     * @param poolId The ID of the pool to register.
     * @param params The parameters for the pool, including `maxAmount`, `leftAmount`, and `whiteListId`.
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
     * @return params The parameters for the pool, including `maxAmount`, `leftAmount`, and `whiteListId`.
     */
    function getParams(
        uint256 poolId
    ) external view returns (uint256[] memory params) {
        IDO storage poolData = poolIdToPool[poolId];
        params = new uint256[](2);
        params[0] = poolData.pool.maxAmount;
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
        uint256 newPoolMaxAmount = poolIdToPool[oldPoolId].pool.maxAmount.calcAmount(ratio);
        uint256 newPoolLeftAmount = poolIdToPool[oldPoolId].leftAmount.calcAmount(ratio);
        // reduce the max amount and leftAmount of the old pool
        poolIdToPool[oldPoolId].pool.maxAmount -= newPoolMaxAmount;
        poolIdToPool[oldPoolId].leftAmount -= newPoolLeftAmount;
        // create a new pool with the new settings
        poolIdToPool[newPoolId].pool.maxAmount = newPoolMaxAmount;
        poolIdToPool[newPoolId].leftAmount = newPoolLeftAmount;
        poolIdToPool[newPoolId].pool.investedProvider = poolIdToPool[oldPoolId].pool.investedProvider;
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
