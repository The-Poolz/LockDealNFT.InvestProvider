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
        IDO calldata pool,
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
        poolIdToPool[poolId] = pool;
        pool.investedProvider.onCreation(poolId, data);
        emit NewPoolCreated(poolId, pool);
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
        IDO storage pool = poolIdToPool[poolId];
        if (block.timestamp < pool.startTime) revert NotStarted();
        if (block.timestamp > pool.endTime) revert Ended();
        if (pool.collectedAmount + amount > pool.maxAmount)
            revert ExceededMaxAmount();
        if (pool.FCFSTime == pool.endTime || pool.FCFSTime == 0) {
            whiteList.Register(msg.sender, pool.whiteListId, amount);
        }
        _invest(poolId, amount, pool);
        pool.investedProvider.onInvest(poolId, amount, data);
        emit Invested(poolId, msg.sender, amount);
    }

    function _invest(
        uint256 poolId,
        uint256 amount,
        IDO storage pool
    ) internal {
        IInvestedProvider investedProvider = pool.investedProvider;
        uint256 userPoolId = lockDealNFT.mintAndTransfer(
            msg.sender,
            lockDealNFT.tokenOf(poolId),
            amount,
            pool.investedProvider
        );
        uint256[] memory params = new uint256[](1);
        params[0] = amount;
        investedProvider.registerPool(userPoolId, params);
        pool.collectedAmount += amount;
        assert(pool.collectedAmount <= pool.maxAmount);
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
        IDO storage pool = poolIdToPool[poolId];
        params = new uint256[](6);
        params[0] = pool.maxAmount;
        params[1] = pool.collectedAmount;
        params[2] = pool.startTime;
        params[3] = pool.endTime;
        params[4] = pool.FCFSTime;
        params[5] = pool.whiteListId;
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
