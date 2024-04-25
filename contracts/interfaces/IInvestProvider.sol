// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IInvestedProvider.sol";
import "@poolzfinance/poolz-helper-v2/contracts/interfaces/IProvider.sol";

interface IInvestProvider is IProvider {
    /// @notice Invest in a IDO pool
    /// @param poolId - the ID of the pool
    /// @param amount - the amount of tokens to invest
    function invest(uint256 poolId, uint256 amount, bytes calldata data) external;

    function createNewPool(
        IDO calldata pool,
        bytes calldata data,
        uint256 sourcePoolId
    ) external returns (uint256 poolId);

    struct IDO {
        uint256 maxAmount;
        uint256 leftAmount;
        uint256 startTime;
        uint256 endTime;
        uint256 FCFSTime;
        uint256 whiteListId;
        IInvestedProvider investedProvider;
    }

    event Invested(
        uint256 indexed poolId,
        address indexed user,
        uint256 amount
    );
    event NewPoolCreated(uint256 indexed poolId, IDO pool);

    error InvalidLockDealNFT();
    error InvalidInvestedProvider();
    error InvalidProvider();
    error InvalidPoolId();
    error NoZeroAddress();
    error InvalidTime();
    error NoZeroAmount();
    error NotStarted();
    error Ended();
    error ExceededMaxAmount();
    /// @dev Error thrown when the length of parameters is invalid
    error InvalidParamsLength(uint256 paramsLength, uint256 minLength);
}
