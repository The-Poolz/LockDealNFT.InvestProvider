// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IInvestedProvider.sol";
import "@poolzfinance/lockdeal-nft/contracts/SimpleProviders/DealProvider/DealProvider.sol";

contract InvestedProviderMock is DealProvider, IInvestedProvider {
    constructor(ILockDealNFT _nftContract) DealProvider(_nftContract) {
        name = "InvestedProviderMock";
    }

    function onCreation(uint256 poolId, bytes calldata data) external override {
        // Do nothing
    }

    function onInvest(
        uint256 poolId,
        uint256 amount,
        bytes calldata data
    ) external override {
        // Do nothing
    }
}
