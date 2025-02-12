// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestCreation.sol";

/// @title InvestProvider
/// @notice This contract provides functionality for creating investment pools, managing investments.
/// @dev Inherits from `InvestCreation` and includes logic to create, invest, and split pools, as well as withdraw funds. It uses `SafeERC20` for token transfers and `CalcUtils` for mathematical operations.
contract InvestProvider is InvestCreation {
    /// @dev Constructor to initialize the contract with a `lockDealNFT`.
    /// @param _lockDealNFT The address of the `ILockDealNFT` contract.
    /// @param _dispenserProvider The address of the `IProvider` contract for dispensers.
    /// @param _investedProvider The address of the `IProvider` contract for invested providers.
    constructor(
        ILockDealNFT _lockDealNFT,
        IProvider _dispenserProvider,
        IProvider _investedProvider
    ) EIP712("InvestProvider", "1") {
        if (address(_lockDealNFT) == address(0)) revert NoZeroAddress();
        if (address(_dispenserProvider) == address(0)) revert NoZeroAddress();
        if (address(_investedProvider) == address(0)) revert NoZeroAddress();
        lockDealNFT = _lockDealNFT;
        dispenserProvider = _dispenserProvider;
        investedProvider = _investedProvider;
        name = "InvestProvider";
    }

    /**
     * @notice Allows an address to invest a specified amount into a pool.
     * @param poolId The ID of the pool to invest in.
     * @param amount The amount to invest.
     * @param signature The signature to validate the investment.
     * @param validUntil The expiration time for the signature.
     * @dev Emits the `Invested` event after a successful investment.
     */
    function invest(
        uint256 poolId,
        uint256 amount,
        uint256 validUntil,
        bytes calldata signature
    )
        external
        firewallProtected
        nonReentrant
        notZeroAmount(amount)
        isValidInvestProvider(poolId)
        isPoolActive(poolId)
        isValidTime(validUntil)
        isValidSignature(poolId, validUntil, amount, signature)
    {
        uint256 nonce = _handleInvest(poolId, amount);
        emit Invested(poolId, msg.sender, amount, nonce);
    }

    /**
     * @notice Allows an address to invest a specified amount into a pool.
     * @param poolId The ID of the pool to invest in.
     * @param amount The amount to invest.
     * @param eip712Signature The signature to validate the investment.
     * @param validUntil The expiration time for the signature.
     * @dev Emits the `Invested` event after a successful investment.
     */
    function invest(
        uint256 poolId,
        uint256 amount,
        uint256 validUntil,
        bytes calldata eip712Signature,
        bytes calldata tokenSignature 
    )
        external
        firewallProtected
        nonReentrant
        notZeroAmount(amount)
        isValidInvestProvider(poolId)
        isPoolActive(poolId)
        isValidTime(validUntil)
        isValidSignature(poolId, validUntil, amount, eip712Signature)
    {
        uint256 nonce = _handleInvest(poolId, amount, tokenSignature);
        emit Invested(poolId, msg.sender, amount, nonce);
    }
}
