// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestState.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title InvestModifiers
/// @notice Provides various modifiers for validating inputs and conditions in investment-related contracts.
abstract contract InvestModifiers is InvestState {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

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
     * @param provider The provider address to validate.
     */
    modifier invalidProvider(uint256 poolId, IProvider provider) {
        _invalidProvider(poolId, provider);
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
     * @dev Modifier to ensure that the current time is within the valid period specified by `validUntil`.
     * @param validUntil The timestamp until which the operation is valid.
     *                   The current block timestamp must be less than or equal to this value.
     */
    modifier isValidTime(uint256 validUntil) {
        if (validUntil < block.timestamp) revert InvalidTime(block.timestamp, validUntil);
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
        address signer = lockDealNFT.getData(poolId).owner;
        bytes32 messageHash = keccak256(
            abi.encodePacked(poolId, msg.sender, validUntil, amount)
        );
        address expectedSigner = messageHash.toEthSignedMessageHash().recover(
            signature
        );
        if (signer != expectedSigner) {
            revert InvalidSignature(poolId, msg.sender);
        }
        _;
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

    /**
     * @notice Validates that the given provider is the correct provider for the specified pool ID.
     * @param poolId The ID of the pool.
     * @param provider The address of the provider to verify.
     * @dev Reverts with `InvalidProvider` if the provider does not match the expected one for the pool.
     */
    function _invalidProvider(
        uint256 poolId,
        IProvider provider
    ) internal view {
        if (lockDealNFT.poolIdToProvider(poolId) != provider)
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
    function _onlyProvider() private view {
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
