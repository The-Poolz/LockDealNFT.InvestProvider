// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@poolzfinance/lockdeal-nft/contracts/SimpleProviders/DealProvider/DealProvider.sol";

contract ProviderMock is DealProvider {
    constructor(ILockDealNFT _nftContract) DealProvider(_nftContract) {
        name = "ProviderMock";
    }

    function callRegister(
        IProvider provider,
        uint256 poolId,
        uint256[] memory params
    ) external {
        provider.registerPool(poolId, params);
    }
}
