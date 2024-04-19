// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@poolzfinance/lockdeal-nft/contracts/SimpleProviders/Provider/ProviderState.sol";
import "@ironblocks/firewall-consumer/contracts/FirewallConsumer.sol";
import "@poolzfinance/poolz-helper-v2/contracts/interfaces/IWhiteList.sol";
import "./interfaces/IInvestProvider.sol";
import "./interfaces/IDispenserProvider.sol";

abstract contract InvestState is
    IInvestProvider,
    FirewallConsumer,
    ProviderState
{
    IProvider investedProvider;
    IDispenserProvider dispenserProvider;
    IWhiteList whiteList;

    mapping(uint256 => IDO) poolIdToPool;

    function currentParamsTargetLength()
        public
        pure
        override(IProvider, ProviderState)
        returns (uint256)
    {
        return 7;
    }
}
