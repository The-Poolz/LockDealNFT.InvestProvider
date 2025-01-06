// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWBNB {
    /// @dev Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @dev Withdraw wrapped ether to get ether
    function withdraw(uint wad) external;

    /// @dev Get the balance of an account
    function balanceOf(address account) external view returns (uint);

    /// @dev Approve an amount to be spent
    function approve(address spender, uint value) external returns (bool);
}
