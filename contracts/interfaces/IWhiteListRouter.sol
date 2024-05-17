// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWhiteListRouter {
    function handleInvestment(
        address user,
        uint256 whiteListId,
        uint256 amount
    ) external;
}
