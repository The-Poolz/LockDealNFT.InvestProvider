// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestInternal.sol";

contract InvestProvider is InvestInternal {
    constructor(ILockDealNFT _lockDealNFT, IWhiteList _whiteList) {
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
        notZeroAmount(pool.startTime)
        notZeroAmount(pool.endTime)
        returns (uint256 poolId)
    {
        if (pool.startTime > pool.endTime) revert InvalidTime();
        if (pool.FCFSTime > pool.endTime) revert InvalidTime();
        if (pool.FCFSTime < pool.startTime && pool.FCFSTime != 0)
            revert InvalidTime();
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
        if (block.timestamp < poolData.pool.startTime) revert NotStarted();
        if (block.timestamp > poolData.pool.endTime) revert Ended();
        if (poolData.leftAmount - amount > 0) revert ExceededMaxAmount();
        poolData.pool.investedProvider.onInvest(poolId, amount, data);
        if (poolData.pool.FCFSTime == poolData.pool.endTime || poolData.pool.FCFSTime == 0) {
            whiteList.Register(msg.sender, poolData.pool.whiteListId, amount);
        }
        _invest(amount, poolData);
        emit Invested(poolId, msg.sender, amount);
    }

    function _invest(uint256 amount, IDO storage pool) internal {
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
        IDO storage data = poolIdToPool[poolId];
        params = new uint256[](6);
        params[0] = data.pool.maxAmount;
        params[1] = data.leftAmount;
        params[2] = data.pool.startTime;
        params[3] = data.pool.endTime;
        params[4] = data.pool.FCFSTime;
        params[5] = data.pool.whiteListId;
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
        view
        override(IProvider, ProviderState)
        returns (uint256[] memory poolIds)
    {
        poolIds = new uint256[](1);
        poolIds[0] = poolID;
    }
}
