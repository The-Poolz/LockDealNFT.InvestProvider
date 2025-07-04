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

    /// @notice validates the invest action
    modifier validateInvest(
        uint256 poolId,
        uint256 amount,
        uint256 validUntil,
        bytes calldata signature
    ) {
        _notZeroAmount(amount);
        _isValidInvestProvider(poolId);
        _isPoolActive(poolId);
        _isValidSignature(poolId, validUntil, amount, signature);
        _;
    }

    modifier isValidTime(uint256 validUntil) {
        if (validUntil < block.timestamp) revert InvalidTime(block.timestamp, validUntil);
        _;
    }
}
