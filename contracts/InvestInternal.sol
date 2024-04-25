// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestModifiers.sol";

abstract contract InvestInternal is InvestModifiers {
    function _registerPool(uint256 poolId, uint256[] calldata params) internal {
        IDO storage data = poolIdToPool[poolId];
        data.pool.maxAmount = params[0];
        data.leftAmount = params[1];
        data.pool.startTime = params[2];
        data.pool.endTime = params[3];
        data.pool.FCFSTime = params[4];
        data.pool.whiteListId = params[5];
        emit UpdateParams(poolId, params);
    }
}
