// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal interface of the Agent ID registry (SPACE ID Agent ID, ERC-721).
/// Only the function AgentStreak needs is declared.
interface IAgentIdRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title Agent Streak
/// @notice Daily check-ins for Agent ID holders. One check-in per address per UTC day.
/// @dev Fully immutable after deployment: no owner, no admin functions, no pause,
/// no fees, no payments, no minting. The only state changes are check-ins.
/// Streaks are keyed to addresses that hold an Agent ID (checked via the registry).
contract AgentStreak {
    IAgentIdRegistry public immutable agentIdRegistry;

    struct UserStats {
        uint256 currentStreak;
        uint256 longestStreak;
        uint256 totalCheckins;
        uint256 lastCheckinDay;
    }

    mapping(address => UserStats) private _stats;
    address[] private _users;
    mapping(address => bool) private _seen;

    /// @notice Total number of check-ins across all users.
    uint256 public totalCheckins;

    event Checkin(address indexed user, uint256 indexed day, uint256 streak);

    error NoAgentId();
    error AlreadyCheckedInToday();

    constructor(address registry) {
        agentIdRegistry = IAgentIdRegistry(registry);
    }

    /// @notice Current UTC day number (days since the Unix epoch).
    function currentDay() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    /// @notice Check in for today. Only Agent ID holders, at most once per UTC day.
    /// Streak increments when yesterday was checked in, otherwise resets to 1.
    function checkIn() external {
        if (agentIdRegistry.balanceOf(msg.sender) < 1) revert NoAgentId();

        uint256 day = currentDay();
        UserStats storage s = _stats[msg.sender];
        if (s.lastCheckinDay == day) revert AlreadyCheckedInToday();

        uint256 streak = (s.lastCheckinDay + 1 == day) ? s.currentStreak + 1 : 1;
        s.currentStreak = streak;
        if (streak > s.longestStreak) {
            s.longestStreak = streak;
        }
        s.totalCheckins += 1;
        s.lastCheckinDay = day;
        totalCheckins += 1;

        if (!_seen[msg.sender]) {
            _seen[msg.sender] = true;
            _users.push(msg.sender);
        }

        emit Checkin(msg.sender, day, streak);
    }

    /// @notice Current streak of `user`.
    function streakOf(address user) external view returns (uint256) {
        return _stats[user].currentStreak;
    }

    /// @notice (currentStreak, longestStreak, totalCheckins, lastCheckinDay) of `user`.
    function statsOf(address user)
        external
        view
        returns (uint256 currentStreak, uint256 longestStreak, uint256 totalCheckins_, uint256 lastCheckinDay)
    {
        UserStats storage s = _stats[user];
        return (s.currentStreak, s.longestStreak, s.totalCheckins, s.lastCheckinDay);
    }

    /// @notice Number of distinct addresses that have ever checked in.
    function totalUsers() external view returns (uint256) {
        return _users.length;
    }

    /// @notice Address of the user at `index` (insertion order).
    function userAt(uint256 index) external view returns (address) {
        return _users[index];
    }

    /// @notice True if `user` already checked in today.
    function hasCheckedInToday(address user) external view returns (bool) {
        return _stats[user].lastCheckinDay == currentDay();
    }
}
