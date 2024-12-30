// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestProvider.sol";
import "./interfaces/IWBNB.sol";

/// @title InvestWrapped
/// @notice Contract for adding wrapped tokens to the investment pool
contract InvestWrapped is InvestProvider {
    /// @dev Mapping of pool ID to wrapped status.
    mapping(uint256 => bool) public poolIdToWrapped;

    /// @dev Constructor to initialize the contract with a `lockDealNFT`.
    /// @param _lockDealNFT The address of the `ILockDealNFT` contract.
    /// @param _dispenserProvider The address of the `IProvider` contract for dispensers.
    constructor(
        ILockDealNFT _lockDealNFT,
        IProvider _dispenserProvider
    ) InvestProvider(_lockDealNFT, _dispenserProvider) {
        name = "InvestWrapped";
    }

    /**
     * @notice Creates a new pool with a wrapped token.
     * @param poolAmount The amount to allocate to the pool.
     * @param investSigner The address of the signer for investments.
     * @param dispenserSigner The address of the signer for dispenses.
     * @param sourcePoolId The ID of the source pool to token clone.
     * @return poolId The ID of the newly created pool.
     * @dev Emits the `NewPoolCreated` event upon successful creation.
     */
    function createNewPool(
        uint256 poolAmount,
        address investSigner,
        address dispenserSigner,
        uint256 sourcePoolId
    )
        public
        override
        firewallProtected
        notZeroAddress(investSigner)
        notZeroAddress(dispenserSigner)
        notZeroAmount(poolAmount)
        isValidSourcePoolId(sourcePoolId)
        returns (uint256 poolId)
    {
        poolId = super.createNewPool(
            poolAmount,
            investSigner,
            dispenserSigner,
            sourcePoolId
        );
        poolIdToWrapped[poolId] = true;
    }

    function createNewPool(
        uint256 poolAmount,
        uint256 sourcePoolId
    )
        public
        virtual
        override
        firewallProtected
        notZeroAmount(poolAmount)
        isValidSourcePoolId(sourcePoolId)
        returns (uint256 poolId)
    {
        poolId = super.createNewPool(poolAmount, sourcePoolId);
        poolIdToWrapped[poolId] = true;
    }

    
    /** @notice Invests in a pool with a wrapped token.
     *  @param poolId The ID of the pool to invest in.
     *  @param amount The amount to invest.
     *  @param signature The signature to validate the investment.
     *  @param validUntil The expiration time for the signature.
     *  @dev Emits the `Invested` event after a successful investment.
     */
    function invest(
        uint256 poolId,
        uint256 amount,
        uint256 validUntil,
        bytes calldata signature
    )
        public
        payable
        override
        firewallProtected
        notZeroAmount(amount)
        isValidInvestProvider(poolId)
        isPoolActive(poolId)
        isValidTime(validUntil)
        isValidSignature(poolId, validUntil, amount, signature)
    {
        if (poolIdToWrapped[poolId]) {
            if (msg.value != amount) revert UnequalAmount();
            IWBNB wToken = IWBNB(lockDealNFT.tokenOf(poolId));
            wToken.deposit{value: msg.value}();
            _handleInvest(poolId, address(this), amount);
        } else {
            super.invest(poolId, amount, validUntil, signature);
        }
    }
}
