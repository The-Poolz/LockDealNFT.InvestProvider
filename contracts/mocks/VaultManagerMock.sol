// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract VaultManagerMock {
    mapping(address => uint) public tokenToVaultId;
    mapping(uint256 => address) public vaultIdToTokenAddress;
    uint256 public Id = 0;

    function safeDeposit(
        address _tokenAddress,
        uint,
        address,
        bytes memory signature
    ) external returns (uint vaultId) {
        require(
            keccak256(abi.encodePacked(signature)) ==
                keccak256(abi.encodePacked("signature")),
            "wrong signature"
        );
        vaultId = _depositByToken(_tokenAddress);
    }

    function _depositByToken(
        address _tokenAddress
    ) internal returns (uint vaultId) {
        if (tokenToVaultId[_tokenAddress] == 0) {
            vaultId = ++Id;
            vaultIdToTokenAddress[vaultId] = _tokenAddress;
            tokenToVaultId[_tokenAddress] = vaultId;
        }
    }
}
