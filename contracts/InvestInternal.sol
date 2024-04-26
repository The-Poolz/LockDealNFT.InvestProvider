// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestModifiers.sol";

abstract contract InvestInternal is InvestModifiers {
    function _registerPool(uint256 poolId, uint256[] calldata params) internal {
        IDO storage data = poolIdToPool[poolId];
        data.pool.maxAmount = params[0];
        data.leftAmount = params[1];
        data.pool.whiteListId = params[2];
        emit UpdateParams(poolId, params);
    }
}
