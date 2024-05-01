// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@poolzfinance/lockdeal-nft/contracts/SimpleProviders/Provider/ProviderState.sol";
import "@ironblocks/firewall-consumer/contracts/FirewallConsumer.sol";
import "./interfaces/IWhiteListV2.sol";
import "./interfaces/IInvestProvider.sol";

abstract contract InvestState is IInvestProvider, FirewallConsumer, ProviderState {
    IWhiteListV2 public immutable whiteList;
    mapping(uint256 => IDO) public poolIdToPool;

    function currentParamsTargetLength()
        public
        pure
        override(IProvider, ProviderState)
        returns (uint256)
    {
        return 3;
    }
}
