// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestInternal.sol";

contract InvestProvider is InvestInternal {
    constructor(
        ILockDealNFT _lockDealNFT,
        IProvider _investedProvider,
        IDispenserProvider _dispenserProvider,
        IWhiteList _whiteList
    ) {
        if (address(_lockDealNFT) == address(0)) revert NoZeroAddress();
        if (address(_investedProvider) == address(0)) revert NoZeroAddress();
        if (address(_dispenserProvider) == address(0)) revert NoZeroAddress();
        if (address(_whiteList) == address(0)) revert NoZeroAddress();
        if (
            keccak256(abi.encodePacked(_investedProvider.name())) !=
            keccak256(abi.encodePacked(("InvestedProvider")))
        ) revert InvalidInvestedProvider();
        lockDealNFT = _lockDealNFT;
        investedProvider = _investedProvider;
        dispenserProvider = _dispenserProvider;
        whiteList = _whiteList;
        name = "InvestProvider";
    }

    /// @notice ERC721 receiver function
    /// @dev This function is called when an NFT is transferred to this contract
    /// @param operator - the address that called the `safeTransferFrom` function
    /// @param user - the address that owns the NFT
    /// @param investedPoolId - the ID of the Invested Provider
    /// @param data - additional data with the NFT
    function onERC721Received(
        address operator,
        address user,
        uint256 investedPoolId,
        bytes calldata data
    ) external virtual override firewallProtected returns (bytes4) {
        if (msg.sender != address(lockDealNFT)) revert InvalidLockDealNFT();
        if (operator != address(this)) {
            // To prevent address(this) mint call
            if (
                lockDealNFT.poolIdToProvider(investedPoolId) != investedProvider
            ) revert InvalidInvestedProvider();
        }
        return this.onERC721Received.selector;
    }

    function createNewPool(
        IDO calldata pool
    )
        external
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
        poolIdToPool[poolId] = pool;
        emit NewPoolCreated(poolId, pool);
    }

    function invest(
        uint256 poolId,
        uint256 amount
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
            whiteList.Register(
                msg.sender,
                pool.whiteListId,
                amount
            );
        }
        _invest(amount, pool);
        emit Invested(poolId, msg.sender, amount);
    }

    function _invest(uint256 amount, IDO storage pool) internal {
        if (
            lockDealNFT.poolIdToProvider(pool.dispenserPoolId) ==
            dispenserProvider
        ) {
            uint256[] memory params = new uint256[](1);
            params[0] =
                dispenserProvider.getParams(pool.dispenserPoolId)[0] +
                amount;
            dispenserProvider.registerPool(pool.dispenserPoolId, params);
            pool.collectedAmount += amount;
        } else {
            uint256 userPoolId = lockDealNFT.mintAndTransfer(
                msg.sender,
                address(pool.token),
                amount,
                investedProvider
            );
            uint256[] memory params = new uint256[](1);
            params[0] = amount;
            investedProvider.registerPool(userPoolId, params);
            pool.collectedAmount += amount;
        }
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
        params = new uint256[](5);
        params[0] = pool.maxAmount;
        params[1] = pool.collectedAmount;
        params[2] = pool.startTime;
        params[3] = pool.endTime;
        params[4] = pool.FCFSTime;
        params[5] = pool.whiteListId;
        params[6] = pool.dispenserPoolId;
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
        poolIds[0] = poolIdToPool[poolID].dispenserPoolId;
    }
}
