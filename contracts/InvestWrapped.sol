// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestProvider.sol";
import "./interfaces/IWBNB.sol";

/// @title InvestWrapped
/// @notice Contract for adding wrapped tokens to the investment pool
contract InvestWrapped is InvestProvider {
    /// @dev Constructor to initialize the contract with a `lockDealNFT`.
    /// @param _lockDealNFT The address of the `ILockDealNFT` contract.
    /// @param _dispenserProvider The address of the `IProvider` contract for dispensers.
    constructor(
        ILockDealNFT _lockDealNFT,
        IProvider _dispenserProvider
    ) InvestProvider(_lockDealNFT, _dispenserProvider) {}

    /** @notice Invests in a pool with a wrapped token.
     *  @param poolId The ID of the pool to invest in.
     *  @param signature The signature to validate the investment.
     *  @param validUntil The expiration time for the signature.
     *  @dev Emits the `Invested` event after a successful investment.
     */
    function investETH(
        uint256 poolId,
        uint256 validUntil,
        bytes calldata signature
    )
        external
        payable
        firewallProtected
        notZeroValue
        isValidInvestProvider(poolId)
        isPoolActive(poolId)
        isWrappedToken(poolId)
        isValidTime(validUntil)
        isValidSignature(poolId, validUntil, msg.value, signature)
    {
        IWBNB wToken = IWBNB(lockDealNFT.tokenOf(poolId));
        wToken.deposit{value: msg.value}();
        _handleInvest(poolId, address(this), msg.value);
    }
}
