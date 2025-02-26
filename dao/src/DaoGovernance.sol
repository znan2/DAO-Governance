// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// OpenZeppelin의 Ownable 컨트랙트를 사용해 관리자 기능 제공
import "node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract DaoGovernance is Ownable {
    // 제안 유형: 온체인 폴과 이그제큐티브 제안 구분
    enum ProposalType { OnChainPoll, ExecutiveProposal }
    // 투표 주기: Monthly와 Weekly
    enum VotingCycle { Monthly, Weekly }
    
    // 제안 구조체 정의
    struct Proposal {
        uint256 id;
        string description;         // 제안 설명 (예: 변경사항, 논의 내용)
        ProposalType proposalType;  // 온체인 폴 / 이그제큐티브 제안 구분
        VotingCycle cycle;          // 월간 / 주간 투표
        uint256 startTime;          // 투표 시작 시간 (timestamp)
        uint256 endTime;            // 투표 종료 시간 (timestamp)
        uint256 yesVotes;           // 찬성 투표 수
        uint256 noVotes;            // 반대 투표 수
        bool executed;              // 실행 여부 (집행된 경우 true)
    }
    
    // 제안 ID 카운터
    uint256 public proposalCount;
    // 제안 저장 매핑
    mapping(uint256 => Proposal) public proposals;
    // 각 제안에 대해 주소별 투표 여부 기록 (중복 투표 방지)
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    // 월간 및 주간 투표 기간 (예시: 월간은 3일, 주간은 1일로 설정)
    uint256 public constant MONTHLY_DURATION = 3 days;
    uint256 public constant WEEKLY_DURATION = 1 days;
    
    // 이벤트
    event ProposalCreated(
        uint256 indexed id, 
        string description, 
        ProposalType proposalType, 
        VotingCycle cycle, 
        uint256 startTime, 
        uint256 endTime
    );
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);

    /// @notice 제안을 생성합니다.
    /// @param _description 제안 내용
    /// @param _proposalType 온체인 폴 또는 이그제큐티브 제안 여부
    /// @param _cycle 월간 또는 주간 투표 방식 선택
    function createProposal(
        string memory _description,
        ProposalType _proposalType,
        VotingCycle _cycle
    ) public onlyOwner returns (uint256) {
        uint256 startTime = block.timestamp;
        uint256 duration = (_cycle == VotingCycle.Monthly) ? MONTHLY_DURATION : WEEKLY_DURATION;
        uint256 endTime = startTime + duration;
        
        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            description: _description,
            proposalType: _proposalType,
            cycle: _cycle,
            startTime: startTime,
            endTime: endTime,
            yesVotes: 0,
            noVotes: 0,
            executed: false
        });
        emit ProposalCreated(proposalCount, _description, _proposalType, _cycle, startTime, endTime);
        return proposalCount;
    }
    
    /// @notice 투표를 진행합니다.
    /// @param _proposalId 투표할 제안의 ID
    /// @param support 찬성(true) 또는 반대(false) 여부
    function vote(uint256 _proposalId, bool support) public {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        
        hasVoted[_proposalId][msg.sender] = true;
        if (support) {
            proposal.yesVotes++;
        } else {
            proposal.noVotes++;
        }
        emit VoteCast(_proposalId, msg.sender, support);
    }
    
    /// @notice (이그제큐티브 제안에 대해) 제안을 실행합니다.
    /// @dev 이 함수는 단순 예시로, 실제 프로토콜에서는 제안에 따른 다양한 실행 로직이 필요합니다.
    function executeProposal(uint256 _proposalId) public onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp > proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Already executed");
        
        // 간단한 다수결 기준: 찬성 투표 수가 반대보다 많으면 통과
        bool passed = (proposal.yesVotes > proposal.noVotes);
        proposal.executed = true;
        
        // 실제 이그제큐티브 제안일 경우, 이곳에서 프로토콜 변경 로직을 실행합니다.
        emit ProposalExecuted(_proposalId, passed);
    }
}
