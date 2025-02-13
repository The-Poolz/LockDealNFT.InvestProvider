// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IVaultViews
interface IVaultViews {
    /// @notice Returns the vault ID by the token address.
    /// @param _tokenAddress The address of the token.
    function getCurrentVaultIdByToken(
        address _tokenAddress
    ) external view returns (uint vaultId);

    /// @notice Returns the vault address by its ID.
    /// @param _vaultId The ID of the vault.
    function vaultIdToVault(
        uint _vaultId
    ) external view returns (address vault);
}
