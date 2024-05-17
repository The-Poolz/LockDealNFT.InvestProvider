// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestInternal.sol";
import "@poolzfinance/poolz-helper-v2/contracts/CalcUtils.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract InvestProvider is InvestInternal {
    using CalcUtils for uint256;
    using SafeERC20 for IERC20;

    constructor(ILockDealNFT _lockDealNFT, IWhiteListRouter _router) {
        if (address(_lockDealNFT) == address(0)) revert NoZeroAddress();
        if (address(_router) == address(0)) revert NoZeroAddress();
        lockDealNFT = _lockDealNFT;
        whiteListRouter = _router;
        name = "InvestProvider";
    }

    function createNewPool(
        Pool calldata pool,
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
        pool.investedProvider.onCreation(poolId, data);
        emit NewPoolCreated(poolId, poolIdToPool[poolId]);
    }

    function invest(
        uint256 poolId,
        uint256 amount,
        bytes calldata data
    )
        external
        override
        firewallProtected
        notZeroAmount(amount)
        invalidProvider(poolId, this)
    {
        IDO storage poolData = poolIdToPool[poolId];
        if (poolData.leftAmount < amount) revert ExceededLeftAmount();

        whiteListRouter.handleInvestment(
            msg.sender,
            poolData.pool.whiteListId,
            amount
        );
        _invest(poolId, amount, poolData, data);
        emit Invested(poolId, msg.sender, amount);
    }

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

    function getParams(
        uint256 poolId
    ) external view returns (uint256[] memory params) {
        IDO storage poolData = poolIdToPool[poolId];
        params = new uint256[](3);
        params[0] = poolData.pool.maxAmount;
        params[1] = poolData.leftAmount;
        params[2] = poolData.pool.whiteListId;
    }

    function withdraw(
        uint256
    ) external firewallProtected onlyNFT returns (uint256, bool) {
        revert();
    }

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
        poolIdToPool[newPoolId].pool.whiteListId = poolIdToPool[oldPoolId].pool.whiteListId;
        poolIdToPool[newPoolId].pool.investedProvider = poolIdToPool[oldPoolId].pool.investedProvider;
    }

    function getWithdrawableAmount(
        uint256
    ) public view virtual override returns (uint256) {
        return 0;
    }

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
