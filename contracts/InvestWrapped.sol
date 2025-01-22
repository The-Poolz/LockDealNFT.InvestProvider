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
        IDispenserProvider.MessageStruct calldata sigData,
        bytes calldata signature
    ) external firewallProtected {
        // dispense NFT
        dispenserProvider.dispenseLock(sigData, signature);
        // check if the pool is valid
        uint256 balanceOf = lockDealNFT.balanceOf(sigData.receiver);
        uint256 poolId = lockDealNFT.tokenOfOwnerByIndex(sigData.receiver, balanceOf - 1);
        uint256 investPoolId = sigData.poolId - 1;
        // if (
        //     lockDealNFT.poolIdToProvider(poolId) != dealProvider ||
        //     lockDealNFT.poolIdToProvider(investPoolId) != this
        // ) {
        //     revert InvalidProvider();
        // }
        lockDealNFT.safeTransferFrom(sigData.receiver, address(lockDealNFT), poolId);
        // Unwrap tokens to retrieve main coins
        IWBNB wToken = IWBNB(lockDealNFT.tokenOf(poolId));
        uint256 amount = wToken.balanceOf(sigData.receiver);
        // update states
        poolIdToPool[investPoolId].leftAmount += amount;
        wToken.withdrawFrom(sigData.receiver, payable(sigData.receiver), amount);
        emit Refunded(investPoolId, msg.sender, amount);
    }
}
