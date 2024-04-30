// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IInvestedProvider.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
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

    function callRegister(
        IProvider provider,
        uint256 poolId,
        uint256[] memory params
    ) external {
        provider.registerPool(poolId, params);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IInvestedProvider).interfaceId;
    }
}
