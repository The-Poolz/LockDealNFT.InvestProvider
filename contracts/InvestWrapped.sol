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
        IDispenserProvider _dispenserProvider,
        IProvider _investedProvider,
        IProvider _dealProvider
    ) InvestProvider(_lockDealNFT, _dispenserProvider, _investedProvider, _dealProvider){}

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
     * @param sigData The signature data to validate the refund.
     * @param signature The signature to validate the refund.
     * @dev Emits the `Refunded` event after a successful refund.
     */
    function refundETH(
        uint256 investPoolId,
        IDispenserProvider.MessageStruct calldata sigData,
        bytes calldata signature
    )
        external
        firewallProtected
        isWrappedToken(investPoolId)
        isPoolActive(investPoolId)
        isRefundApproved
    {
        // Dispense NFT to validate the refund
        dispenserProvider.dispenseLock(sigData, signature);
        address receiver = sigData.receiver;
        uint256 balanceOf = lockDealNFT.balanceOf(receiver);
        uint256 poolId = lockDealNFT.tokenOfOwnerByIndex(
            receiver,
            balanceOf - 1
        );
        // Validate pool providers
        if (lockDealNFT.poolIdToProvider(poolId) != dealProvider) {
            revert InvalidProvider();
        }
        // Transfer NFT back to lockDealNFT
        lockDealNFT.safeTransferFrom(receiver, address(lockDealNFT), poolId);
        // Retrieve the main coins by unwrapping tokens
        IWBNB wToken = IWBNB(lockDealNFT.tokenOf(poolId));
        uint256 amount = wToken.balanceOf(receiver);
        // Update pool state
        poolIdToPool[investPoolId].leftAmount += amount;
        // Withdraw the unwrapped tokens
        wToken.withdrawFrom(receiver, payable(receiver), amount);
        emit Refunded(investPoolId, msg.sender, amount);
    }
}
