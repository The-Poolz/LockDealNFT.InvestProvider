// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWBNB {
    /// @dev Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @dev Withdraw wrapped ether to get ether
    function withdraw(uint256 wad) external;

    /// @dev Withdraw wrapped ether to get ether
    function withdrawFrom(address from, address payable to, uint256 value) external;

    /// @dev Get the balance of an account
    function balanceOf(address account) external view returns (uint256);

    /// @dev Approve an amount to be spent
    function approve(address spender, uint256 value) external returns (bool);

    /// @dev Allowance of an account
    function allowance(address owner, address spender) external view returns (uint256);
}
