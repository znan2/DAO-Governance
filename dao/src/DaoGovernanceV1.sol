// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract DaoGovernanceV1 is UUPSUpgradeable, OwnableUpgradeable, ERC20Upgradeable {
    ERC20Upgradeable public token;
    uint256 public constant VOTING_DURATION = 1 minutes;
    uint256 public votingDuration;
    bool public upgradeApproved;

    enum ProposalStatus {
        Pending,       // 제안 생성 후, 아직 Submission 안 됨
        Submission,    // Submission = true 일 때 -> Ratification Poll 시작
        Completed      // 투표 종료 후 결과 확정
    }

    // Ratification Poll 결과
    enum PollResult {
        NotEnded,  // 투표 기간이 끝나지 않음
        Passed,    // 찬성이 젤 많으면 Passed
        Rejected,  // 반대가 젤 많으면 Rejected
        Extended   // 기권이 최다 -> 투표 연장
    }

    // 제안 정보
    struct Proposal {
        uint256 id;
        string description;   // 제안 설명
        bool submission;      // Submission 여부 (true면 바로 Ratification Poll)
        ProposalStatus status;// 현재 제안 상태, pending/submission/completed
        uint256 startTime;    // 투표 시작 시점
        uint256 endTime;      // 투표 종료 시점
        // Ratification Poll 투표 수
        uint256 yesVotes;     // 찬성 투표 수
        uint256 noVotes;      // 반대 투표 수
        uint256 abstainVotes; // 기권 투표 수
        PollResult result;    // 최종 결과
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;


    function initialize(ERC20Upgradeable _token) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ERC20_init("WAYToken", "WAY");
        token = _token;
        votingDuration = VOTING_DURATION;
        upgradeApproved = false;
    }

    function createProposal(string memory _description, bool _submission) public onlyOwner returns (uint256) {
        proposalCount++;
        uint256 newId = proposalCount;

        Proposal storage p = proposals[newId];
        p.id = newId;
        p.description = _description;
        p.submission = _submission;
        p.result = PollResult.NotEnded;

        if (_submission) {
            // submission = true -> 투표 시작
            p.status = ProposalStatus.Submission;
            p.startTime = block.timestamp;
            p.endTime = block.timestamp + votingDuration;
        } else {
            // submission = false -> 투표 진행 X (Pending 상태 유지)
            p.status = ProposalStatus.Pending;
        }
        return newId;
    }

    function approveUpgrade() external onlyOwner {
        // 예: 투표 결과가 찬성 과반이라면 true 
        upgradeApproved = true;
    }

    function _authorizeUpgrade(address newImplementation) internal override view{
        require(owner() == msg.sender, "Not owner");
        require(upgradeApproved, "Upgrade not approved by vote");
    }

    function upgradeImplementation(address newImplementation, bytes memory data) external onlyOwner {
        require(upgradeApproved, "Upgrade not approved");
        upgradeToAndCall(newImplementation, data);
    }

    function vote(uint256 _proposalId, uint8 _option) external {
        Proposal storage p = proposals[_proposalId];

        require(p.submission, "Proposal not submitted for Ratification");
        require(p.status == ProposalStatus.Submission, "Proposal not in submission status");
        require(block.timestamp >= p.startTime, "Voting not started");
        require(block.timestamp <= p.endTime, "Voting ended");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        require(_option <= 2, "Invalid option");

        uint256 votingPower = token.balanceOf(msg.sender);
        require(votingPower > 0, "No voting power");

        hasVoted[_proposalId][msg.sender] = true;

        if (_option == 0) {
            p.yesVotes += votingPower;
        } else if (_option == 1) {
            p.noVotes += votingPower;
        } else {
            p.abstainVotes += votingPower;
        }
    }

    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        return proposals[_proposalId];
    }

    function finalize(uint256 _proposalId) external onlyOwner {
        Proposal storage p = proposals[_proposalId];
        require(p.status == ProposalStatus.Submission, "Proposal not in submission");
        require(block.timestamp > p.endTime, "Voting period not ended");

        if (p.yesVotes > p.noVotes && p.yesVotes > p.abstainVotes) {
            p.result = PollResult.Passed;
        } else if (p.noVotes > p.yesVotes && p.noVotes > p.abstainVotes) {
            p.result = PollResult.Rejected;
        } else {
            p.result = PollResult.Extended;
        }

        p.status = ProposalStatus.Completed;
    }

    function extendVoting(uint256 _proposalId) external onlyOwner {
        Proposal storage p = proposals[_proposalId];
        require(p.status == ProposalStatus.Completed, "Not completed yet");
        require(p.result == PollResult.Extended, "Proposal not extended");

        p.status = ProposalStatus.Submission;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + votingDuration;
        p.result = PollResult.NotEnded;
        p.yesVotes = 0;
        p.noVotes = 0;
        p.abstainVotes = 0;
    }

    function getVotingDuration() public view returns (uint256) {
        return votingDuration;
    }

    function version() public pure returns (string memory) {
        return "V1";
    }
}
