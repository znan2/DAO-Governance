// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract DaoGovernanceV3 is UUPSUpgradeable, OwnableUpgradeable{
    ERC20Upgradeable public token;
    uint256 public votingDuration;
    bool public upgradeApproved; // 업그레이드 승인 여부
    bool public paused;
    uint256 public constant VOTING_DURATION = 3 days;
    mapping(address => uint256) public pendingWithdrawals;
    bool public isStopped;

    modifier onlyWhenNotStopped() {
        require(!isStopped, "Contract is stopped");
        _;
    }

    modifier onlyWhenStopped() {
        require(isStopped, "Contract is not stopped");
        _;
    }

    modifier onlyAuthorized() {
        require(msg.sender == owner(), "Not authorized");
        _;
    }

    function stopContract() external onlyAuthorized onlyWhenNotStopped {
        isStopped = true;
    }
    function resumeContract() external onlyAuthorized onlyWhenStopped {
        isStopped = false;
    }
  
    enum ProposalStatus {
        Pending,    
        Submission,
        Completed  
    }

    enum PollResult {
        NotEnded,  
        Passed,    
        Rejected,  
        Extended   
    }


    struct Proposal {
        uint256 id;
        string description;
        bool submission;
        ProposalStatus status;
        uint256 startTime;
        uint256 endTime;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 abstainVotes;
        PollResult result;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => uint256) public stakedBalances; // 스테이킹된 토큰 양
    uint256 public constant REWARD_PERCENT = 10; // 보상률
    mapping(address => uint256) public stakedTimestamp; //스테이킹한 기간 추적용

    function initializeV3(ERC20Upgradeable _token) public reinitializer(3) {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        token = _token;
        votingDuration = VOTING_DURATION; 
        paused = false;
        upgradeApproved = false;
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        require(owner() == msg.sender, "Not owner");
        require(upgradeApproved, "Upgrade not approved");
    }

    function approveUpgrade() external onlyAuthorized() {
        upgradeApproved = true;
    }

    function upgradeImplementation(address newImplementation, bytes memory data) external onlyAuthorized() {
        require(upgradeApproved, "Upgrade not approved");
        upgradeToAndCall(newImplementation, data);
    }


    function emergencyStop() external onlyAuthorized() {
        paused = true;
    }

    function resume() external onlyAuthorized() {
        paused = false;
    }
    //CEI
    function stake(uint256 amount) external onlyWhenNotStopped {
        require(amount > 0, "Cannot stake zero");
        if (stakedBalances[msg.sender] == 0) {
            stakedTimestamp[msg.sender] = block.timestamp;
        }
        stakedBalances[msg.sender] += amount;
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");
    }
    //CEI, Pull over Push
    function unstake(uint256 amount) external onlyWhenNotStopped {
        require(amount > 0, "Cannot unstake zero");
        require(stakedBalances[msg.sender] >= amount, "Not enough staked");
        uint256 reward = 0;
        if (stakedTimestamp[msg.sender] > 0 && (block.timestamp - stakedTimestamp[msg.sender] >= 7 days)) {
            reward = (amount * REWARD_PERCENT) / 100;
        }

        stakedBalances[msg.sender] -= amount;
        if (stakedBalances[msg.sender] == 0) {
            stakedTimestamp[msg.sender] = 0;
        }

        pendingWithdrawals[msg.sender] += (amount + reward);
    }

    function withdraw() external onlyWhenNotStopped {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending withdrawal");
        pendingWithdrawals[msg.sender] = 0;
        bool success = token.transfer(msg.sender, amount);
        require(success, "Token transfer failed");
    }

    //pendingWithdrawals 말고 스테이킹된 금액에서도 뺄 수 있음
    function emergencyWithdraw() external onlyWhenStopped {
        uint256 amount = stakedBalances[msg.sender] + pendingWithdrawals[msg.sender];
        require(amount > 0, "No staked funds");
        
        // 내부 상태 업데이트
        stakedBalances[msg.sender] = 0;
        pendingWithdrawals[msg.sender] = 0;
        stakedTimestamp[msg.sender] = 0;
        
        // 외부 상호작용: 토큰 전송
        bool success = token.transfer(msg.sender, amount);
        require(success, "Token transfer failed");
    }


    function createProposal(string memory _description, bool _submission) public onlyAuthorized() returns (uint256) {
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

    function vote(uint256 _proposalId, uint8 _option) external onlyWhenNotStopped {
        Proposal storage p = proposals[_proposalId];

        require(p.status == ProposalStatus.Submission, "Proposal not in submission");
        require(block.timestamp >= p.startTime, "Voting not started");
        require(block.timestamp <= p.endTime, "Voting ended");
        // ^_^
        require(_option <= 2, "Invalid option");

        // 스테이킹 수량 = 투표권
        uint256 votingPower = stakedBalances[msg.sender];
        require(votingPower > 0, "No staking -> no voting power");

        hasVoted[_proposalId][msg.sender] = true;

        if (_option == 0) {
            p.yesVotes += votingPower;
        } else if (_option == 1) {
            p.noVotes += votingPower;
        } else {
            p.abstainVotes += votingPower;
        }
    }

    function finalize(uint256 _proposalId) external onlyAuthorized() {
        Proposal storage p = proposals[_proposalId];
        require(p.status == ProposalStatus.Submission, "Proposal not in submission");
        require(block.timestamp > p.endTime, "Voting period not ended");

        if (p.yesVotes > p.noVotes && p.yesVotes > p.abstainVotes) {
            p.result = PollResult.Passed;
        } else if (p.noVotes > p.yesVotes && p.noVotes > p.abstainVotes) {
            p.result = PollResult.Rejected;
        } else {
            // 기권 최다 or 동점 => 투표 연장
            p.result = PollResult.Extended;
        }
        p.status = ProposalStatus.Completed;
    }

    function extendVoting(uint256 _proposalId) external onlyAuthorized() {
        Proposal storage p = proposals[_proposalId];
        require(p.status == ProposalStatus.Completed, "Not completed yet");
        require(p.result == PollResult.Extended, "Proposal not extended");

        // 재투표(Submission 상태로 되돌림)
        p.status = ProposalStatus.Submission;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + votingDuration;
        p.result = PollResult.NotEnded;
        p.yesVotes = 0;
        p.noVotes = 0;
        p.abstainVotes = 0;
    }

    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        return proposals[_proposalId];
    }

    //멀티콜
    function multicall(bytes[] calldata calls) external onlyWhenNotStopped returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory retData) = address(this).delegatecall(calls[i]);
            if (!success) {
                // revert reason 추출
                if (retData.length > 0) {
                    assembly {
                        let returndata_size := mload(retData)
                        revert(add(32, retData), returndata_size)
                    }
                } else {
                    revert("Multicall subcall failed");
                }
            }
            results[i] = retData;
        }
    }

    function getVotingDuration() public view returns (uint256) {
        return votingDuration;
    }

    function version() public pure returns (string memory) {
        return "V3";
    }

    function executeProposalCreationAndVote() external onlyAuthorized {
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(this.createProposal.selector, "Multicall Proposal", true);
        calls[1] = abi.encodeWithSelector(this.vote.selector, uint256(1), uint8(0));
        this.multicall(calls);
    }
}
