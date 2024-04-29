// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestState.sol";

abstract contract InvestModifiers is InvestState {
    /// @dev Modifier to ensure an address is not zero
    modifier notZeroAddress(address _address) {
        _notZeroAddress(_address);
        _;
    }

    /// @dev Modifier to ensure an amount is not zero
    modifier notZeroAmount(uint256 amount) {
        _notZeroAmount(amount);
        _;
    }

    modifier invalidProvider(uint256 poolId, IProvider provider) {
        _invalidProvider(poolId, provider);
        _;
    }

    modifier validParamsLength(uint256 paramsLength, uint256 minLength) {
        _validParamsLength(paramsLength, minLength);
        _;
    }

    modifier onlyProvider() {
        _onlyProvider();
        _;
    }

    modifier onlyNFT() {
        _onlyNFT();
        _;
    }

    function _validParamsLength(
        uint256 paramsLength,
        uint256 minLength
    ) internal pure {
        if (paramsLength != minLength)
            revert InvalidParamsLength(paramsLength, minLength);
    }

    function _invalidProvider(
        uint256 poolId,
        IProvider provider
    ) internal view {
        if (lockDealNFT.poolIdToProvider(poolId) != provider)
            revert InvalidProvider();
    }

    /// @dev Internal function to check that an amount is not zero
    function _notZeroAmount(uint256 amount) internal pure {
        if (amount == 0) revert NoZeroAmount();
    }

    function _onlyNFT() internal view {
        if (msg.sender != address(lockDealNFT)) revert OnlyLockDealNFT();
    }

    function _onlyProvider() private view {
        if (!lockDealNFT.approvedContracts(msg.sender))
            revert InvalidProvider();
    }

    /// @dev Internal function to check that an address is not zero
    function _notZeroAddress(address _address) internal pure {
        if (_address == address(0)) revert NoZeroAddress();
    }
}
