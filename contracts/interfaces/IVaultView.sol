// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVaultView {
    function getCurrentVaultIdByToken(
        address token
    ) external view returns (uint256);

    function vaultIdToVault(uint256 vaultId) external view returns (address);
}
