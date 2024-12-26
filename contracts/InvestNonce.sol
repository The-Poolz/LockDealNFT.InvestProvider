// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InvestState.sol";

abstract contract InvestNonce is InvestState {
    /// @dev Adds a new track item for the specified ID and address.
    /// @param poolId The ID associated with the address.
    /// @param amount The amount to associate with this track.
    function _addInvestTrack(uint256 poolId, uint256 amount) internal {
        poolIdToInvests[poolId][msg.sender].push(
            UserInvest(block.timestamp, amount)
        );
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
     *  internal function to get nonce of the user in the pool.
     * @param poolId The ID of the pool to fetch investments for.
     */
    function _getNonce(
        uint256 poolId
    ) internal view returns (uint256 nonce) {
        nonce = poolIdToInvests[poolId][msg.sender].length;
    }

    /// @dev Returns the track at a specific index for the specified ID and address.
    /// @param id The ID associated with the address.
    /// @param user The address for which the track is being retrieved.
    /// @param index The index of the track to retrieve.
    /// @return The track item (blockTimestamp and amount).
    function getInvestTrack(
        uint256 id,
        address user,
        uint256 index
    ) external view returns (UserInvest memory) {
        return poolIdToInvests[id][user][index];
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
