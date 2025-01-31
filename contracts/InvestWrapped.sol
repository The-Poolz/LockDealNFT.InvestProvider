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
        IProvider _investedProvider
    ) InvestProvider(_lockDealNFT, _dispenserProvider, _investedProvider) {}

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
        address receiver = sigData.receiver;
        uint256 balanceOf = lockDealNFT.balanceOf(receiver);
        // Dispense the lock
        dispenserProvider.dispenseLock(sigData, signature);
        uint256 amount = _processWithdrawals(receiver, balanceOf);
        // Retrieve the main coins by unwrapping tokens
        IWBNB wToken = IWBNB(lockDealNFT.tokenOf(investPoolId));
        // Update pool state
        poolIdToPool[investPoolId].leftAmount += amount;
        // Withdraw the unwrapped tokens
        wToken.withdrawFrom(receiver, payable(receiver), amount);
        emit Refunded(investPoolId, msg.sender, amount);
    }

    function _processWithdrawals(
        address receiver,
        uint256 balanceBefore
    ) internal returns (uint256 amount) {
        uint256 range = lockDealNFT.balanceOf(receiver) - balanceBefore;
        for (uint256 i = 0; i < range; ++i) {
            uint256 poolId = lockDealNFT.tokenOfOwnerByIndex(
                receiver,
                balanceBefore + i
            );
            amount += _withdrawIfAvailiable(poolId, receiver);
        }
    }

    function _withdrawIfAvailiable(
        uint256 poolId,
        address receiver
    ) internal returns (uint256 withdrawAmount) {
        withdrawAmount = lockDealNFT.getWithdrawableAmount(poolId);
        if (withdrawAmount > 0) {
            lockDealNFT.safeTransferFrom(
                receiver,
                address(lockDealNFT),
                poolId
            );
        }
    }
}
