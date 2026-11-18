// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AgentStreak} from "../src/AgentStreak.sol";

/// @notice Minimal cheatcode interface (subset of forge-std's Vm), so the
/// test suite has zero external dependencies.
interface Vm {
    function warp(uint256 newTimestamp) external;
    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function stopPrank() external;
    function expectRevert(bytes4 revertSelector) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;
}

/// @notice Mock Agent ID registry: an ERC-721-like contract with a settable balanceOf.
contract MockAgentId {
    mapping(address => uint256) private _balances;

    function setBalance(address owner, uint256 amount) external {
        _balances[owner] = amount;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }
}

contract AgentStreakTest {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MockAgentId internal registry;
    AgentStreak internal streak;

    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);

    // 2026-11-18 00:00:00 UTC
    uint256 internal constant DAY0 = 1794960000;

    event Checkin(address indexed user, uint256 indexed day, uint256 streak);

    function setUp() public {
        registry = new MockAgentId();
        streak = new AgentStreak(address(registry));
        vm.warp(DAY0);
    }

    // --- tiny assert helpers (no forge-std) ---

    function assertEq(uint256 a, uint256 b, string memory msg_) internal pure {
        require(a == b, msg_);
    }

    function assertEq(address a, address b, string memory msg_) internal pure {
        require(a == b, msg_);
    }

    function assertTrue(bool cond, string memory msg_) internal pure {
        require(cond, msg_);
    }

    // --- tests ---

    function test_RevertsWithoutAgentId() public {
        vm.prank(ALICE);
        vm.expectRevert(AgentStreak.NoAgentId.selector);
        streak.checkIn();
    }

    function test_FirstCheckin() public {
        registry.setBalance(ALICE, 1);
        vm.prank(ALICE);
        streak.checkIn();

        (uint256 cur, uint256 longest, uint256 total, uint256 lastDay) = streak.statsOf(ALICE);
        assertEq(cur, 1, "current streak should be 1");
        assertEq(longest, 1, "longest streak should be 1");
        assertEq(total, 1, "total check-ins should be 1");
        assertEq(lastDay, DAY0 / 1 days, "lastCheckinDay should be today");
        assertEq(streak.streakOf(ALICE), 1, "streakOf should be 1");
        assertEq(streak.totalCheckins(), 1, "global totalCheckins should be 1");
        assertEq(streak.totalUsers(), 1, "totalUsers should be 1");
        assertEq(streak.userAt(0), ALICE, "userAt(0) should be Alice");
        assertTrue(streak.hasCheckedInToday(ALICE), "hasCheckedInToday should be true");
    }

    function test_OneCheckinPerDay() public {
        registry.setBalance(ALICE, 1);
        vm.prank(ALICE);
        streak.checkIn();

        vm.prank(ALICE);
        vm.expectRevert(AgentStreak.AlreadyCheckedInToday.selector);
        streak.checkIn();

        // Still only one check-in recorded.
        (, , uint256 total, ) = streak.statsOf(ALICE);
        assertEq(total, 1, "total check-ins should still be 1");
        assertEq(streak.totalCheckins(), 1, "global total should still be 1");
    }

    function test_StreakIncrementsOnConsecutiveDays() public {
        registry.setBalance(ALICE, 1);
        vm.prank(ALICE);
        streak.checkIn();

        vm.warp(DAY0 + 1 days);
        vm.prank(ALICE);
        streak.checkIn();

        vm.warp(DAY0 + 2 days);
        vm.prank(ALICE);
        streak.checkIn();

        (uint256 cur, uint256 longest, uint256 total, ) = streak.statsOf(ALICE);
        assertEq(cur, 3, "current streak should be 3");
        assertEq(longest, 3, "longest streak should be 3");
        assertEq(total, 3, "total check-ins should be 3");
    }

    function test_StreakResetsAfterGap() public {
        registry.setBalance(ALICE, 1);
        vm.prank(ALICE);
        streak.checkIn();

        vm.warp(DAY0 + 1 days);
        vm.prank(ALICE);
        streak.checkIn();

        // Skip a day: next check-in is 3 days after the first one.
        vm.warp(DAY0 + 3 days);
        vm.prank(ALICE);
        streak.checkIn();

        (uint256 cur, uint256 longest, uint256 total, ) = streak.statsOf(ALICE);
        assertEq(cur, 1, "current streak should reset to 1");
        assertEq(longest, 2, "longest streak should stay 2");
        assertEq(total, 3, "total check-ins should be 3");
    }

    function test_LongestStreakTrackedAcrossResets() public {
        registry.setBalance(ALICE, 1);
        vm.startPrank(ALICE);
        streak.checkIn();
        vm.warp(DAY0 + 1 days);
        streak.checkIn();
        vm.warp(DAY0 + 2 days);
        streak.checkIn(); // streak 3
        vm.warp(DAY0 + 5 days);
        streak.checkIn(); // reset to 1
        vm.warp(DAY0 + 6 days);
        streak.checkIn(); // streak 2
        vm.stopPrank();

        (uint256 cur, uint256 longest, uint256 total, ) = streak.statsOf(ALICE);
        assertEq(cur, 2, "current streak should be 2");
        assertEq(longest, 3, "longest streak should stay 3");
        assertEq(total, 5, "total check-ins should be 5");
    }

    function test_EventEmitted() public {
        registry.setBalance(ALICE, 1);
        vm.prank(ALICE);
        vm.expectEmit(true, true, false, true);
        emit Checkin(ALICE, DAY0 / 1 days, 1);
        streak.checkIn();
    }

    function test_HasCheckedInToday() public {
        registry.setBalance(ALICE, 1);
        assertTrue(!streak.hasCheckedInToday(ALICE), "should be false before check-in");
        vm.prank(ALICE);
        streak.checkIn();
        assertTrue(streak.hasCheckedInToday(ALICE), "should be true after check-in");
        vm.warp(DAY0 + 1 days);
        assertTrue(!streak.hasCheckedInToday(ALICE), "should be false the next day");
    }

    function test_MultipleUsers() public {
        registry.setBalance(ALICE, 1);
        registry.setBalance(BOB, 1);

        vm.prank(ALICE);
        streak.checkIn();
        vm.prank(BOB);
        streak.checkIn();

        assertEq(streak.totalUsers(), 2, "totalUsers should be 2");
        assertEq(streak.totalCheckins(), 2, "global totalCheckins should be 2");
        assertEq(streak.userAt(0), ALICE, "userAt(0) should be Alice");
        assertEq(streak.userAt(1), BOB, "userAt(1) should be Bob");
        assertEq(streak.streakOf(BOB), 1, "Bob streak should be 1");

        // Alice checking in again the next day does not add a new user.
        vm.warp(DAY0 + 1 days);
        vm.prank(ALICE);
        streak.checkIn();
        assertEq(streak.totalUsers(), 2, "totalUsers should still be 2");
        assertEq(streak.totalCheckins(), 3, "global totalCheckins should be 3");
    }

    function test_LosingAgentIdBlocksCheckin() public {
        registry.setBalance(ALICE, 1);
        vm.prank(ALICE);
        streak.checkIn();

        registry.setBalance(ALICE, 0);
        vm.warp(DAY0 + 1 days);
        vm.prank(ALICE);
        vm.expectRevert(AgentStreak.NoAgentId.selector);
        streak.checkIn();
    }

    function test_StatsOfUnknownUserAreZero() public view {
        (uint256 cur, uint256 longest, uint256 total, uint256 lastDay) = streak.statsOf(ALICE);
        assertEq(cur, 0, "current streak should be 0");
        assertEq(longest, 0, "longest streak should be 0");
        assertEq(total, 0, "total check-ins should be 0");
        assertEq(lastDay, 0, "lastCheckinDay should be 0");
        assertTrue(!streak.hasCheckedInToday(ALICE), "hasCheckedInToday should be false");
    }
}
