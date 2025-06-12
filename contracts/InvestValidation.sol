// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestInternal.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

/// @title InvestValidation
/// @notice Provides various checks for validating inputs and conditions in investment-related contracts.
abstract contract InvestValidation is InvestInternal {
    using ECDSA for bytes32;

    /// @notice Validates the signature provided for the dispense action.
    /// @dev Reverts with an `InvalidSignature` error if the signature is not valid.
    /// @param poolId The pool ID for the dispensation.
    /// @param validUntil The timestamp until which the dispensation is valid.
    /// @param amount The amount to dispense.
    /// @param signature The cryptographic signature to verify.
    function _isValidSignature(
        uint256 poolId,
        uint256 validUntil,
        uint256 amount,
        bytes calldata signature
    ) internal view {
        uint256 nonce = _getNonce(poolId, msg.sender);
        InvestMessage memory message = InvestMessage(poolId, msg.sender, amount, validUntil, nonce);
        bytes memory data = abi.encodePacked(
            INVEST_TYPEHASH,
            abi.encode(message)
        );
        _verify(poolId, data, signature);
    }

    /**
     * @notice Checks if the pool is active.
     * @param poolId The ID of the pool to check.
     * @dev Reverts with `InactivePool` if the pool is not active.
     */
    function _isPoolActive(uint256 poolId) internal view {
        if (
            lockDealNFT.ownerOf(poolId) == address(lockDealNFT) ||
            lockDealNFT.ownerOf(poolId + 1) == address(lockDealNFT) // dispense pool
        ) revert InactivePool(poolId);
    }

    /**
     * @notice Checks if the length of parameters meets the required minimum length.
     * @param paramsLength The actual length of parameters.
     * @param minLength The minimum length of parameters expected.
     * @dev Reverts with `InvalidParamsLength` if the length does not meet the requirement.
     */
    function _validParamsLength(
        uint256 paramsLength,
        uint256 minLength
    ) internal pure {
        if (paramsLength != minLength)
            revert InvalidParamsLength(paramsLength, minLength);
    }

    function _isValidSourcePoolId(uint256 sourcePoolId) internal view {
        if (lockDealNFT.poolIdToProvider(sourcePoolId) == IProvider(address(0)))
            revert InvalidSourcePoolId(sourcePoolId);
    }

    /**
     * @notice Validates that the given provider is the correct provider for the specified pool ID.
     * @param poolId The ID of the pool.
     * @dev Reverts with `InvalidProvider` if the provider does not match the expected one for the pool.
     */
    function _isValidInvestProvider(uint256 poolId) internal view {
        if (lockDealNFT.poolIdToProvider(poolId) != this)
            revert InvalidProvider();
    }

    /**
     * @notice Checks if the given amount is non-zero.
     * @param amount The amount to check.
     * @dev Reverts with `NoZeroAmount` if the amount is zero.
     */
    function _notZeroAmount(uint256 amount) internal pure {
        if (amount == 0) revert NoZeroAmount();
    }

    /**
     * @notice Ensures that only the NFT contract can call the function.
     * @dev Reverts with `OnlyLockDealNFT` if the caller is not the NFT contract.
     */
    function _onlyNFT() internal view {
        if (msg.sender != address(lockDealNFT)) revert OnlyLockDealNFT();
    }

    /**
     * @notice Ensures that the caller is an approved provider contract.
     * @dev Reverts with `InvalidProvider` if the caller is not an approved contract.
     */
    function _onlyProvider() internal view {
        if (!lockDealNFT.approvedContracts(msg.sender))
            revert InvalidProvider();
    }

    /**
     * @notice Checks if the provided address is non-zero.
     * @param _address The address to check.
     * @dev Reverts with `NoZeroAddress` if the address is zero.
     */
    function _notZeroAddress(address _address) internal pure {
        if (_address == address(0)) revert NoZeroAddress();
    }
}
