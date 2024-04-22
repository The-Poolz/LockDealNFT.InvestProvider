// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestModifiers.sol";

abstract contract InvestInternal is InvestModifiers {
    function _registerPool(uint256 poolId, uint256[] calldata params) internal {
        IDO storage pool = poolIdToPool[poolId];
        pool.maxAmount = params[0];
        pool.collectedAmount = params[1];
        pool.startTime = params[2];
        pool.endTime = params[3];
        pool.FCFSTime = params[4];
        pool.whiteListId = params[5];
        emit UpdateParams(poolId, params);
    }
}
