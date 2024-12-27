// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWBNB {
    /// @dev Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @dev Withdraw wrapped ether to get ether
    function withdraw(uint wad) external;
}
