// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@ironblocks/firewall-consumer/contracts/FirewallConsumer.sol";

abstract contract InvestNonce is FirewallConsumer {
    /// @notice Maps pool IDs to the investments made in the pool.
    /// @dev Each pool ID corresponds to an array of `UserInvest` structs containing investment details.
    mapping(uint256 => mapping(address => UserInvest[])) public poolIdToInvests;

    /**
     * @dev Struct that represents an investment in an IDO pool, containing the timestamp and amount of the investment.
     */
    struct UserInvest {
        uint256 blockTimestamp;
        uint256 amount;
    }

    /// @dev Adds a new track item for the specified ID and address.
    /// @param poolId The ID associated with the address.
    /// @param amount The amount to associate with this track.
    /// 0x31f1a01e - bytes4(keccak256("_addInvestTrack(uint256,uint256)"))
    function _addInvestTrack(
        uint256 poolId,
        uint256 amount
    ) internal firewallProtectedSig(0x31f1a01e) returns (uint256 nonce) {
        poolIdToInvests[poolId][msg.sender].push(UserInvest(block.timestamp, amount));
        nonce = _getNonce(poolId, msg.sender);
    }

    /**
     * @notice Retrieves nonce of the user in the pool.
     * @param poolId The ID of the pool to fetch investments for.
     * @return nonce The number of investments made by the msg.sender in the pool.
     */
    function getNonce(
        uint256 poolId,
        address user
    ) external view returns (uint256 nonce) {
        nonce = _getNonce(poolId, user);
    }

    /**
     *  internal function to get nonce of the user in the pool.
     * @param poolId The ID of the pool to fetch investments for.
     */
    function _getNonce(
        uint256 poolId,
        address user
    ) internal view returns (uint256 nonce) {
        nonce = poolIdToInvests[poolId][user].length;
    }

    /**
     * @notice Retrieves the investments made in a pool by a user.
     * @param poolId The ID of the pool to fetch investments for.
     * @return invests An array of `UserInvest` structs containing investment details.
     */
    function getUserInvests(
        uint256 poolId,
        address user
    ) external view returns (UserInvest[] memory) {
        return poolIdToInvests[poolId][user];
    }
}
