// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestProvider.sol";
import "./interfaces/IWBNB.sol";

/// @title InvestWrappedProvider
/// @notice Contract for adding wrapped tokens to the investment pool
contract InvestWrappedProvider is InvestProvider {
    /// @dev Mapping of pool ID to wrapped status.
    mapping(uint256 => bool) public poolIdToWrapped;

    /// @dev Constructor to initialize the contract with a `lockDealNFT`.
    /// @param _lockDealNFT The address of the `ILockDealNFT` contract.
    /// @param _dispenserProvider The address of the `IProvider` contract for dispensers.
    constructor(
        ILockDealNFT _lockDealNFT,
        IProvider _dispenserProvider
    ) InvestProvider(_lockDealNFT, _dispenserProvider) {
        name = "InvestWrappedProvider";
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
    function createNewETHPool(
        uint256 poolAmount,
        address investSigner,
        address dispenserSigner,
        uint256 sourcePoolId
    ) external virtual returns (uint256 poolId) {
        poolId = createNewPool(
            poolAmount,
            investSigner,
            dispenserSigner,
            sourcePoolId
        );
        poolIdToWrapped[poolId] = true;
    }

    function createNewETHPool(
        uint256 poolAmount,
        uint256 sourcePoolId
    ) external virtual returns (uint256 poolId) {
        poolId = createNewPool(poolAmount, sourcePoolId);
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
        isValidInvestProvider(poolId)
        isPoolActive(poolId)
        isValidTime(validUntil)
    {
        bool isWrapped = poolIdToWrapped[poolId];
        uint256 investAmount = isWrapped ? msg.value : amount;

        _notZeroAmount(investAmount);
        _isValidSignature(poolId, validUntil, investAmount, signature);

        if (isWrapped) {
            IWBNB wToken = IWBNB(lockDealNFT.tokenOf(poolId));
            wToken.deposit{value: msg.value}();
            _handleInvest(poolId, address(this), msg.value);
        } else {
            _handleInvest(poolId, msg.sender, amount);
        }
    }

    /**
     * @notice Splits an old pool into a new pool with a specified ratio.
     * @param oldPoolId The ID of the old pool to split.
     * @param newPoolId The ID of the new pool to create.
     * @param ratio The ratio to split the amounts between the old and new pools.
     * @dev Reduces the amounts of the old pool and creates the new pool with the calculated amounts.
     */
    function split(
        uint256 oldPoolId,
        uint256 newPoolId,
        uint256 ratio
    ) public virtual override {
        super.split(oldPoolId, newPoolId, ratio);
        poolIdToWrapped[newPoolId] = poolIdToWrapped[oldPoolId];
    }
}
