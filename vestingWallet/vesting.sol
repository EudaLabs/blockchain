// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../token/ERC20/IERC20.sol";
import {SafeERC20} from "../token/ERC20/utils/SafeERC20.sol";
import {Address} from "../utils/Address.sol";
import {Context} from "../utils/Context.sol";
import {Ownable} from "../access/Ownable.sol";

/**
 * @title VestingWallet
 * @dev A contract to lock and gradually release ETH and ERC20 tokens to a beneficiary based on a linear vesting schedule.
 */
contract VestingWallet is Context, Ownable {
    event EtherReleased(uint256 amount);
    event ERC20Released(address indexed token, uint256 amount);

    uint256 private _released; // Tracks total ETH released
    mapping(address => uint256) private _erc20Released; // Tracks total ERC20 tokens released per token
    uint64 private immutable _start; // Start timestamp of the vesting schedule
    uint64 private immutable _duration; // Duration of the vesting schedule in seconds

    /**
     * @dev Initializes the contract with the beneficiary, start time, and vesting duration.
     * @param beneficiary Address of the initial owner (beneficiary).
     * @param startTimestamp Start time of the vesting (in Unix timestamp).
     * @param durationSeconds Duration of the vesting period in seconds.
     */
    constructor(address beneficiary, uint64 startTimestamp, uint64 durationSeconds) payable Ownable(beneficiary) {
        _start = startTimestamp;
        _duration = durationSeconds;
    }

    /// @dev Allows the contract to receive ETH.
    receive() external payable virtual {}

    /// @notice Returns the vesting start timestamp.
    function start() public view virtual returns (uint256) {
        return _start;
    }

    /// @notice Returns the vesting duration.
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /// @notice Returns the end timestamp of the vesting schedule.
    function end() public view virtual returns (uint256) {
        return start() + duration();
    }

    /// @notice Returns the total amount of ETH already released.
    function released() public view virtual returns (uint256) {
        return _released;
    }

    /// @notice Returns the total amount of ERC20 tokens already released for a specific token.
    function released(address token) public view virtual returns (uint256) {
        return _erc20Released[token];
    }

    /// @notice Returns the amount of ETH currently releasable.
    function releasable() public view virtual returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    /// @notice Returns the amount of ERC20 tokens currently releasable for a specific token.
    function releasable(address token) public view virtual returns (uint256) {
        return vestedAmount(token, uint64(block.timestamp)) - released(token);
    }

    /**
     * @notice Releases the vested ETH to the beneficiary.
     * Emits an {EtherReleased} event.
     */
    function release() public virtual {
        uint256 amount = releasable();
        _released += amount;
        emit EtherReleased(amount);
        Address.sendValue(payable(owner()), amount);
    }

    /**
     * @notice Releases the vested ERC20 tokens to the beneficiary.
     * @param token Address of the ERC20 token to release.
     * Emits an {ERC20Released} event.
     */
    function release(address token) public virtual {
        uint256 amount = releasable(token);
        _erc20Released[token] += amount;
        emit ERC20Released(token, amount);
        SafeERC20.safeTransfer(IERC20(token), owner(), amount);
    }

    /**
     * @dev Calculates the amount of vested ETH at a specific timestamp.
     * @param timestamp The current timestamp.
     * @return The amount of vested ETH.
     */
    function vestedAmount(uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(address(this).balance + released(), timestamp);
    }

    /**
     * @dev Calculates the amount of vested ERC20 tokens at a specific timestamp.
     * @param token Address of the ERC20 token.
     * @param timestamp The current timestamp.
     * @return The amount of vested ERC20 tokens.
     */
    function vestedAmount(address token, uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(IERC20(token).balanceOf(address(this)) + released(token), timestamp);
    }

    /**
     * @dev Internal function implementing the linear vesting formula.
     * @param totalAllocation Total amount allocated (ETH or token balance).
     * @param timestamp Current timestamp.
     * @return The vested amount based on linear vesting.
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view virtual returns (uint256) {
        if (timestamp < start()) {
            return 0; // No vesting before the start time
        } else if (timestamp >= end()) {
            return totalAllocation; // Full vesting after the end time
        } else {
            return (totalAllocation * (timestamp - start())) / duration(); // Linear vesting calculation
        }
    }
}
