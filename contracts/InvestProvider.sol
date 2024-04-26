// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestInternal.sol";

contract InvestProvider is InvestInternal {
    constructor(ILockDealNFT _lockDealNFT, IWhiteListV2 _whiteList) {
        if (address(_lockDealNFT) == address(0)) revert NoZeroAddress();
        if (address(_whiteList) == address(0)) revert NoZeroAddress();
        lockDealNFT = _lockDealNFT;
        whiteList = _whiteList;
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
        returns (uint256 poolId)
    {
        poolId = lockDealNFT.mintForProvider(msg.sender, this);
        lockDealNFT.cloneVaultId(sourcePoolId, poolId);
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
        poolData.pool.investedProvider.onInvest(poolId, amount, data);
        whiteList.handleInvestment(msg.sender, poolData.pool.whiteListId, amount);
        _invest(amount, poolData);
        emit Invested(poolId, msg.sender, amount);
    }

    function _invest(uint256 amount,IDO storage pool) internal {
        pool.leftAmount -= amount;
        assert(pool.leftAmount >= 0);
    }

    function registerPool(
        uint256 poolId,
        uint256[] calldata params
    )
        external
        override
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

    function withdraw(uint256) external pure returns (uint256, bool) {
        revert();
    }

    function split(uint256, uint256, uint256) external pure {
        revert();
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
