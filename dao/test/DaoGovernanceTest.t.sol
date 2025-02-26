// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DaoGovernance.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract DaoGovernanceTest is Test {
    DaoGovernance dao;
    address owner = address(1);
    address alice = address(2);
    address bob   = address(3);
    function setUp() public {
        vm.prank(owner); 
        dao = new DaoGovernance();
    }

    function testCreateProposalSubmissionTrue() public {
        vm.prank(owner);
        uint256 proposalId = dao.createProposal("Test Proposal", true);
        assertEq(proposalId, dao.proposalCount());
    }

    function testCreateProposalSubmissionFalse() public {
        vm.prank(owner);
        uint256 proposalId = dao.createProposal("Pending Proposal", false);
        DaoGovernance.Proposal memory p = dao.getProposal(proposalId);
        assertEq(proposalId, dao.proposalCount());
        assertEq(uint(p.status), uint(DaoGovernance.ProposalStatus.Pending));
    }

    function testCreateProposalByAlcie() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        dao.createProposal("msg.sender == alice", true);
    }

    function testVote() public {
        vm.prank(owner);
        uint256 proposalId = dao.createProposal("Vote Test", true);
        vm.prank(alice);
        dao.vote(proposalId, 0);
        DaoGovernance.Proposal memory p = dao.getProposal(proposalId);
        assertEq(p.yesVotes, 1);
        assertEq(p.noVotes, 0);
        assertEq(p.abstainVotes, 0);
        // 재투표
        vm.prank(alice);
        vm.expectRevert("Already voted");
        dao.vote(proposalId, 1);
    }

    // 투표 기간 아닐 때 투표 되는지
    function testVoteOutsideVotingPeriod() public {
        vm.prank(owner);
        uint256 proposalId = dao.createProposal("Time Test", true);
        DaoGovernance.Proposal memory p = dao.getProposal(proposalId);
        vm.warp(p.startTime - 1);
        vm.prank(bob);
        vm.expectRevert("Voting not started");
        dao.vote(proposalId, 0);

        vm.warp(p.endTime + 1);
        vm.prank(bob);
        vm.expectRevert("Voting ended");
        dao.vote(proposalId, 0);
    }
}
