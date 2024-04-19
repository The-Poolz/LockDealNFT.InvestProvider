// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@poolzfinance/lockdeal-nft/contracts/SimpleProviders/Provider/ProviderModifiers.sol";
import "@poolzfinance/lockdeal-nft/contracts/SimpleProviders/DealProvider/DealProviderState.sol";

contract InvestedProvider is ProviderModifiers, DealProviderState {
    error InvalidLockDealNFT();

    constructor(ILockDealNFT _lockDealNFT) {
        if (address(_lockDealNFT) == address(0)) revert InvalidLockDealNFT();
        lockDealNFT = _lockDealNFT;
        name = "InvestedProvider";
    }

    function registerPool(
        uint256 poolId,
        uint256[] calldata params
    )
        external
        virtual
        onlyProvider
        validParamsLength(params.length, currentParamsTargetLength())
    {
        _registerPool(poolId, params);
    }

    function _registerPool(uint256 poolId, uint256[] calldata params) internal {
        poolIdToAmount[poolId] = params[0];
        emit UpdateParams(poolId, params);
    }

    function getParams(
        uint256 poolId
    ) external view returns (uint256[] memory params) {
        params = new uint256[](1);
        params[0] = poolIdToAmount[poolId];
    }

    function getWithdrawableAmount(
        uint256
    ) external pure returns (uint256 withdrawalAmount) {
        withdrawalAmount = 0;
    }

    function withdraw(uint256) external pure returns (uint256, bool) {
        revert("");
    }

    function split(uint256, uint256, uint256) external pure {
        revert("");
    }
}
