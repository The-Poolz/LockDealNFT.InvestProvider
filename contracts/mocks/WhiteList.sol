// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IWhiteListV2.sol";

contract WhiteList is IWhiteListV2 {
    function handleInvestment(
        address investor,
        uint256 whiteListId,
        uint256 amount
    ) external {
        // some logic
    }
}
