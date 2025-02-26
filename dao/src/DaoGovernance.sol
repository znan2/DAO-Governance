// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title DaoGovernance
 * @dev 간단한 토이 프로젝트용 거버넌스 컨트랙트
 *      - Submission을 통해 Ratification Poll(비준 투표) 시작 여부 결정
 *      - Ratification Poll은 3가지 옵션(찬성/반대/기권) 중 최다 득표로 결론
 *      - 투표 기간은 항상 3일로 통일
 */
contract DaoGovernance is Ownable {
    // 모든 투표 기간을 3일로 설정
    uint256 public constant VOTING_DURATION = 3 days;

    // 제안 상태
    enum ProposalStatus {
        Pending,       // 제안 생성 후, 아직 Submission 안 됨
        Submission,    // Submission = true 일 때 -> Ratification Poll 시작
        Completed      // 투표 종료 후 결과 확정
    }

    // Ratification Poll 결과
    enum PollResult {
        NotEnded,  // 투표 기간이 끝나지 않음
        Passed,    // 찬성이 최다
        Rejected,  // 반대가 최다
        Extended   // 기권이 최다 -> 투표 연장
    }

    // 제안 정보
    struct Proposal {
        uint256 id;
        string description;   // 제안 설명
        bool submission;      // Submission 여부 (true면 바로 Ratification Poll)
        ProposalStatus status;// 현재 제안 상태
        uint256 startTime;    // 투표 시작 시점
        uint256 endTime;      // 투표 종료 시점
        // Ratification Poll 투표 수
        uint256 yesVotes;     // 찬성 투표 수
        uint256 noVotes;      // 반대 투표 수
        uint256 abstainVotes; // 기권 투표 수
        PollResult result;    // 최종 결과
    }

    // 제안 ID 카운터
    uint256 public proposalCount;

    // 제안 매핑
    mapping(uint256 => Proposal) public proposals;

    // 각 제안별로 중복 투표 방지
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // 이벤트
    event ProposalCreated(
        uint256 indexed id,
        string description,
        bool submission,  
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        string option  // "yes" / "no" / "abstain"
    );

    event ProposalFinalized(
        uint256 indexed proposalId,
        PollResult result
    );

    constructor() Ownable(msg.sender) {
        // 초기화 로직이 필요하면 여기에 작성
    }

    /**
     * @notice 제안을 생성합니다.
     * @dev  submission = true 일 경우, 바로 Ratification Poll(비준 투표)을 시작합니다.
     *       false 일 경우에는 제안이 Pending 상태로 남아 투표가 진행되지 않습니다.
     * @param _description 제안 내용
     * @param _submission Ratification Poll 진행 여부
     */
    function createProposal(
        string memory _description,
        bool _submission
    )
        public
        onlyOwner
        returns (uint256)
    {
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

    /**
     * @notice Ratification Poll에 투표(찬성/반대/기권)합니다.
     * @dev submission = true인 제안만 투표 가능, 투표 기간 내 1회만 가능
     * @param _proposalId 투표할 제안의 ID
     * @param _option 0=찬성, 1=반대, 2=기권
     */
    function vote(uint256 _proposalId, uint8 _option) external {
        Proposal storage p = proposals[_proposalId];

        // submission = false인 경우 투표 진행 불가
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

    /**
     * @notice 투표 기간이 끝난 후, 최종 결과를 확정합니다.
     * @dev  가장 많은 득표를 받은 옵션에 따라 결과를 결정
     *       - yes 최다 -> Passed
     *       - no 최다 -> Rejected
     *       - abstain 최다 -> Extended (예: 투표 연장)
     */
    function finalize(uint256 _proposalId) external onlyOwner {
        Proposal storage p = proposals[_proposalId];
        require(p.status == ProposalStatus.Submission, "Proposal not in submission");
        require(block.timestamp > p.endTime, "Voting period not ended");

        // 최다 득표 옵션 판별
        if (p.yesVotes > p.noVotes && p.yesVotes > p.abstainVotes) {
            p.result = PollResult.Passed;
        } else if (p.noVotes > p.yesVotes && p.noVotes > p.abstainVotes) {
            p.result = PollResult.Rejected;
        } else {
            // 기권이 가장 많거나, 2가지 이상의 옵션이 동수일 경우
            // 여기서는 단순히 기권이 '가장 많을 경우' 연장이라고 가정
            // 동수 상황도 여기로 처리 가능 (필요 시 별도 처리)
            p.result = PollResult.Extended;
        }

        p.status = ProposalStatus.Completed;
        emit ProposalFinalized(_proposalId, p.result);
    }

    /**
     * @notice Extended 상태일 경우, 다시 투표 시작 가능(예: 재투표).
     *        여기서는 간단히 투표 종료 시간을 새로 설정하는 로직만 예시로 추가.
     */
    function extendVoting(uint256 _proposalId) external onlyOwner {
        Proposal storage p = proposals[_proposalId];
        require(p.status == ProposalStatus.Completed, "Not completed yet");
        require(p.result == PollResult.Extended, "Proposal not extended");

        // 재투표 시작(기존 투표 정보는 유지하거나 초기화할지 정책에 따라 결정)
        p.status = ProposalStatus.Submission;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + VOTING_DURATION;
        p.result = PollResult.NotEnded;

        // 이미 투표한 사람들의 투표를 어떻게 처리할지 결정 필요(예: reset)
        // 간단한 예시로 재투표 시 기존 투표 기록 초기화
        p.yesVotes = 0;
        p.noVotes = 0;
        p.abstainVotes = 0;
    }
}
