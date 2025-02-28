// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/WAYToken.sol";
import "../src/DaoGovernanceV3.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract V3Test is Test {
    DaoGovernanceV3 dao;
    WAYToken wayToken;

    address owner = address(1);
    address alice = address(2);
    address bob   = address(3);

    function setUp() public {
        vm.startPrank(owner);
        wayToken = new WAYToken();
        vm.stopPrank();

        vm.startPrank(owner);
        dao = new DaoGovernanceV3();
        dao.initializeV3(ERC20Upgradeable(address(wayToken)));
        vm.stopPrank();

        vm.startPrank(owner);
        wayToken.transfer(alice, 500 * 1e18);
        vm.stopPrank();

        vm.startPrank(alice);
        wayToken.approve(address(dao), type(uint256).max);
        vm.stopPrank();
    }

    function testStake() public {
        vm.prank(alice);
        dao.stake(100 * 1e18);

        uint256 stakedAlice = dao.stakedBalances(alice);
        assertEq(stakedAlice, 100 * 1e18);
        uint256 daoBalance = wayToken.balanceOf(address(dao));
        assertEq(daoBalance, 100 * 1e18);
    }

    function testUnstakeWithoutReward() public {
        vm.startPrank(alice);
        dao.stake(200 * 1e18);
        vm.warp(block.timestamp + 1 days);

        // 50토큰만 unstake
        dao.unstake(50 * 1e18);
        uint256 stakedNow = dao.stakedBalances(alice);
        assertEq(stakedNow, 150 * 1e18);

        uint256 pending = dao.pendingWithdrawals(alice);
        assertEq(pending, 50 * 1e18, "Pending withdrawal should be 50 tokens");

        dao.withdraw();
        // 350개 남아있어야 함
        uint256 aliceBalance = wayToken.balanceOf(alice);
        assertEq(aliceBalance, 350 * 1e18);
        vm.stopPrank();
    }

    function testUnstakeWithReward() public {
        vm.startPrank(alice);
        dao.stake(200 * 1e18);
        vm.warp(block.timestamp + 7 days + 1);
        dao.unstake(50 * 1e18);
        uint256 stakedNow = dao.stakedBalances(alice);
        assertEq(stakedNow, 150 * 1e18);
        uint256 pending = dao.pendingWithdrawals(alice);
        assertEq(pending, 55 * 1e18, "Pending withdrawal should be 55 tokens");
        dao.withdraw();
        // 355개 남아있어야 함
        uint256 aliceBalance = wayToken.balanceOf(alice);
        assertEq(aliceBalance, 355 * 1e18);

        vm.stopPrank();
    }

    function testEmergencyStopAndResume() public {
        vm.prank(owner);
        dao.stopContract();
        // 중지 상태
        vm.prank(alice);
        vm.expectRevert("Contract is stopped");
        dao.stake(50);

        // resumeContract()테스트
        vm.prank(owner);
        dao.resumeContract();
        vm.prank(alice);
        dao.stake(50 * 1e18);
        uint256 staked = dao.stakedBalances(alice);
        assertEq(staked, 50 * 1e18, "Alice should stake 50 tokens after resume");
    }

    function testEmergencyWithdraw() public {
        vm.startPrank(alice);
        dao.stake(200 * 1e18);
        dao.unstake(50 * 1e18);
        // EmergencyWithdraw total = 200
        vm.stopPrank();
        // 중지
        vm.prank(owner);
        dao.stopContract();
        vm.prank(alice);
        dao.emergencyWithdraw();

        uint256 remainingStake = dao.stakedBalances(alice);
        uint256 remainingPending = dao.pendingWithdrawals(alice);
        assertEq(remainingStake, 0, "Staked balance should be reset to 0");
        assertEq(remainingPending, 0, "Pending withdrawals should be reset to 0");
        uint256 aliceBalance = wayToken.balanceOf(alice);
        assertEq(aliceBalance, 500 * 1e18, "Alice balance should be restored to 500 tokens");
    }
}
