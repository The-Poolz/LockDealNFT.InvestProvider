// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@poolzfinance/lockdeal-nft/contracts/SimpleProviders/Provider/ProviderState.sol";
import "@ironblocks/firewall-consumer/contracts/FirewallConsumer.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./interfaces/IInvestProvider.sol";
import "@poolzfinance/dispenser-provider/contracts/interfaces/IDispenserProvider.sol";

/// @title InvestState
/// @notice Manages the state of investment pools and provides common functions for interacting with them.
/// @dev Implements IInvestProvider, IERC165, FirewallConsumer, and ProviderState for pool management and security.
abstract contract InvestState is IInvestProvider, IERC165, FirewallConsumer, ProviderState {
    /// @notice Maps pool IDs to their respective investment pool data.
    /// @dev Each pool ID corresponds to an `Pool` struct containing pool details.
    mapping(uint256 => Pool) public poolIdToPool;

    /// @notice The address of the DispenserProvider contract.
    IDispenserProvider public immutable dispenserProvider;

    /// @notice The address of the invested provider.
    IProvider public immutable investedProvider;
    
    /// @notice The EIP-712 domain separator for investment types. Represented as:
    ///     keccak256(
    ///         "InvestMessage(uint256 poolId,address user,uint256 amount,uint256 validUntil,uint256 nonce)"
    ///     );
    bytes32 public constant INVEST_TYPEHASH = 0xf8aa084d6e1010879da870ee8bf4da7d3cd029f3a5dca41618aaead07eff40dd;

    /**
     * @notice Returns the expected length of parameters required for pool functions.
     * @dev This function overrides `currentParamsTargetLength` from both `IProvider` and `ProviderState`.
     * @return The expected length of parameters for pool functions, set to 3.
     */
    function currentParamsTargetLength()
        public
        pure
        override(IProvider, ProviderState)
        returns (uint256)
    {
        return 2;
    }

    /**
     * @notice Checks if the contract supports a given interface.
     * @dev Supports `IERC165` and `IInvestProvider` interfaces.
     * @param interfaceId The ID of the interface to check.
     * @return True if the interface is supported, false otherwise.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IInvestProvider).interfaceId;
    }

    /**
     * @notice Retrieves the pool IDs associated with a sub-provider.
     * @param poolId The ID of the pool to retrieve sub-provider pool IDs for.
     * @return poolIds An array containing the sub-provider pool IDs.
     */
    function getSubProvidersPoolIds(
        uint256 poolId
    )
        public
        view
        override(IProvider, ProviderState)
        returns (uint256[] memory poolIds)
    {
        if (lockDealNFT.poolIdToProvider(poolId) == this) {
            poolIds = new uint256[](1);
            poolIds[0] = poolId + 1; // dispenser
        }
    }

    /**
     * @notice Retrieves the current parameters for a pool.
     * @param poolId The ID of the pool to fetch parameters for.
     * @return params The parameters for the pool, including `maxAmount`, `leftAmount``.
     */
    function getParams(
        uint256 poolId
    ) external view override returns (uint256[] memory params) {
        Pool storage poolData = poolIdToPool[poolId];
        params = new uint256[](2);
        params[0] = poolData.maxAmount;
        params[1] = poolData.leftAmount;
    }
}
