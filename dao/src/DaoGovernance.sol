// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/access/Ownable.sol";


contract DaoGovernance is Ownable {
    // 모든 투표 기간을 3일로 설정
    uint256 public constant VOTING_DURATION = 3 days;

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

    // 이벤트
    event ProposalCreated(
        uint256 indexed id,
        string description,
        bool submission,  
        uint256 startTime,
        uint256 endTime
    );
    event VoteCast(uint256 indexed proposalId, address indexed voter, string option);
    event ProposalFinalized(uint256 indexed proposalId, PollResult result);
    event VotingExtended(uint256 indexed proposalId, uint256 newEndTime);

    constructor() Ownable(msg.sender) {
        // 초기화 로직
    }

    function createProposal(string memory _description,bool _submission) public onlyOwner returns (uint256) {
        proposalCount++;
        uint256 newId = proposalCount;

        Proposal storage p = proposals[newId];
        p.id = newId;
        p.description = _description;
        p.submission = _submission;
        p.result = PollResult.NotEnded;

        if (_submission) {
            // submission = true -> 곧바로 투표 시작
            p.status = ProposalStatus.Submission;
            p.startTime = block.timestamp;
            p.endTime = block.timestamp + VOTING_DURATION;
        } else {
            // submission = false -> 투표 진행 X (Pending 상태 유지)
            p.status = ProposalStatus.Pending;
        }
        emit ProposalCreated(
            newId,
            _description,
            _submission,
            p.startTime,
            p.endTime
        );
        return newId;
    }

    function vote(uint256 _proposalId, uint8 _option) external {
        Proposal storage p = proposals[_proposalId];

        require(p.submission, "Proposal not submitted for Ratification");
        require(p.status == ProposalStatus.Submission, "Proposal not in submission status");
        require(block.timestamp >= p.startTime, "Voting not started");
        require(block.timestamp <= p.endTime, "Voting ended");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        require(_option <= 2, "Invalid option");

        hasVoted[_proposalId][msg.sender] = true;

        if (_option == 0) {
            p.yesVotes++;
            emit VoteCast(_proposalId, msg.sender, "yes");
        } else if (_option == 1) {
            p.noVotes++;
            emit VoteCast(_proposalId, msg.sender, "no");
        } else {
            p.abstainVotes++;
            emit VoteCast(_proposalId, msg.sender, "abstain");
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
            // 기권이 제일 많을 때나 동표가 나왔을 때
            p.result = PollResult.Extended;
            emit VotingExtended(_proposalId, p.endTime + VOTING_DURATION);
        }

        p.status = ProposalStatus.Completed;
        emit ProposalFinalized(_proposalId, p.result);
    }

    function extendVoting(uint256 _proposalId) external onlyOwner {
        Proposal storage p = proposals[_proposalId];
        require(p.status == ProposalStatus.Completed, "Not completed yet");
        require(p.result == PollResult.Extended, "Proposal not extended");

        // 재투표 시작하면 시간 연장하고 표는 초기화
        p.status = ProposalStatus.Submission;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + VOTING_DURATION;
        p.result = PollResult.NotEnded;
        p.yesVotes = 0;
        p.noVotes = 0;
        p.abstainVotes = 0;
    }
}
