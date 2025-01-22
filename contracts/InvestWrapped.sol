// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestProvider.sol";
import "./interfaces/IWBNB.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/// @title InvestWrapped
/// @notice Contract for adding wrapped tokens to the investment pool
contract InvestWrapped is InvestProvider, ERC721Holder {
    receive() external payable {}

    /// @dev Constructor to initialize the contract with a `lockDealNFT`.
    /// @param _lockDealNFT The address of the `ILockDealNFT` contract.
    /// @param _dispenserProvider The address of the `IProvider` contract for dispensers.
    constructor(
        ILockDealNFT _lockDealNFT,
        IProvider _dispenserProvider,
        IProvider _investProvider
    ) InvestProvider(_lockDealNFT, _dispenserProvider, _investProvider) {}

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
        uint256 nonce = _handleInvest(poolId, msg.value);
        emit Invested(poolId, msg.sender, msg.value, nonce);
    }

    /**
     * @notice Refunds the investment from a pool using main coins.
     * @param poolId The ID of the pool to refund from.
     * @param amount The amount to refund.
     * @param validUntil The expiration time for the signature.
     * @param signature The signature used to validate the refund.
     * @dev Emits the `Refunded` event after a successful refund.
     */
    function refundETH(
        uint256 poolId,
        uint256 amount,
        uint256 validUntil,
        bytes calldata signature
    )
        external
        firewallProtected
        isValidInvestProvider(poolId)
        isWrappedToken(poolId)
        isValidTime(validUntil)
        notZeroAmount(amount)
        //isValidSignature(poolId, validUntil, amount, signature)
    {
        // update states
        poolIdToPool[poolId].leftAmount += amount;
        // mint withdraw NFT
        uint256 withdrawPoolID = _mintWithdrawNFT(poolId, amount);
        // withdraw wrapped tokens from vault
        lockDealNFT.safeTransferFrom(address(this), address(lockDealNFT), withdrawPoolID);
        // Unwrap tokens to retrieve main coins
        IWBNB wToken = IWBNB(lockDealNFT.tokenOf(poolId));
        wToken.withdraw(amount);
        // Transfer the unwrapped main coins to the user
        payable(msg.sender).transfer(amount);
        emit Refunded(poolId, msg.sender, amount);
    }
}
