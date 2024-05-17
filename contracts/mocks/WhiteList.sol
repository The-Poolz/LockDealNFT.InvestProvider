// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IWhiteListRouter.sol";

contract MockRouter is IWhiteListRouter {
    function handleInvestment(
        address investor,
        uint256 whiteListId,
        uint256 amount
    ) external {
        // some logic
    }
}
