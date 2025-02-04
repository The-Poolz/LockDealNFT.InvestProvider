// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestValidation.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

/// @title InvestModifiers
/// @notice Provides various modifiers for validating inputs and conditions in investment-related contracts.
abstract contract InvestModifiers is InvestValidation {
    using ECDSA for bytes32;

    /**
     * @dev Modifier to ensure an address is not the zero address.
     * @param _address The address to check.
     */
    modifier notZeroAddress(address _address) {
        _notZeroAddress(_address);
        _;
    }

    /**
     * @dev Modifier to ensure an amount is not zero.
     * @param amount The amount to check.
     */
    modifier notZeroAmount(uint256 amount) {
        _notZeroAmount(amount);
        _;
    }

    /**
     * @dev Modifier to validate that the provided address is a valid provider for the given pool ID.
     * @param poolId The pool ID to check.
     */
    modifier isValidInvestProvider(uint256 poolId) {
        _isValidInvestProvider(poolId);
        _;
    }

    /**
     * @dev Modifier to validate that the parameters length is as expected.
     * @param paramsLength The actual length of parameters.
     * @param minLength The required minimum length of parameters.
     */
    modifier validParamsLength(uint256 paramsLength, uint256 minLength) {
        _validParamsLength(paramsLength, minLength);
        _;
    }

    /**
     * @dev Modifier to ensure that the caller is an approved provider.
     */
    modifier onlyProvider() {
        _onlyProvider();
        _;
    }

    /**
     * @dev Modifier to ensure that the caller is the NFT contract.
     */
    modifier onlyNFT() {
        _onlyNFT();
        _;
    }

    /**
     * @dev Modifier to ensure that the source pool ID is valid.
     * @param sourcePoolId The source pool ID to check.
     */
    modifier isValidSourcePoolId(uint256 sourcePoolId) {
        _isValidSourcePoolId(sourcePoolId);
        _;
    }

    /**
     * @dev Modifier to ensure that the pool is active.
     * @param poolId The pool ID to check.
     */
    modifier isPoolActive(uint256 poolId) {
        _isPoolActive(poolId);
        _;
    }

    /**
     * @dev Modifier to ensure that the current time is within the valid period specified by `validUntil`.
     * @param validUntil The timestamp until which the operation is valid.
     *                   The current block timestamp must be less than or equal to this value.
     */
    modifier isValidTime(uint256 validUntil) {
        _isValidTime(validUntil);
        _;
    }

    /// @notice Validates the signature provided for the dispense action.
    /// @dev Reverts with an `InvalidSignature` error if the signature is not valid.
    /// @param poolId The pool ID for the dispensation.
    /// @param validUntil The timestamp until which the dispensation is valid.
    /// @param amount The amount to dispense.
    /// @param signature The cryptographic signature to verify.
    modifier isValidSignature(
        uint256 poolId,
        uint256 validUntil,
        uint256 amount,
        bytes calldata signature
    ) {
        _isValidSignature(poolId, validUntil, amount, signature);
        _;
    }
}
