// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DaoGovernanceV1.sol";
import "../src/DaoGovernanceV2.sol";
import "../src/DaoProxy.sol";
import "../src/WAYToken.sol";

contract ProxyTest is Test {
    DaoProxy proxy;
    DaoGovernanceV1 daoV1; // Implementation V1
    DaoGovernanceV2 daoV2; // Implementation V2
    WAYToken way;         // WAYToken
    address owner = address(1);
    address alice = address(2);

    function setUp() public {
        // 1. owner로 WAYToken 배포 (초기 mint는 owner에게 할당)
        vm.prank(owner);
        way = new WAYToken();

        // 2. owner로 DaoGovernanceV1 배포
        vm.prank(owner);
        daoV1 = new DaoGovernanceV1();

        // 3. 초기화 데이터 생성: DaoGovernanceV1.initialize(token, 3 days)
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,uint256)",
            ERC20Upgradeable(address(way)),
            3 days
        );

        // 4. UUPSProxy 배포, 초기 구현은 daoV1
        vm.prank(owner);
        proxy = new DaoProxy(address(daoV1), initData);

        // 5. owner가 alice에게 토큰 전송하여 voting power 확보
        vm.prank(owner);
        way.transfer(alice, 1);
    }

    function testProxyCallsV1() public {
        // proxy를 DaoGovernanceV1 인터페이스로 캐스팅하여 V1 함수 호출
        DaoGovernanceV1 proxyV1 = DaoGovernanceV1(address(proxy));
        vm.prank(owner);
        uint256 proposalId = proxyV1.createProposal("Test Proposal V1", true);
        assertEq(proposalId, proxyV1.proposalCount());
    }

    function testUpgradeFromV1ToV2() public {
        // 1. proxy를 DaoGovernanceV1 인터페이스로 캐스팅하여 V1 기능 테스트
        DaoGovernanceV1 proxyV1 = DaoGovernanceV1(address(proxy));
        vm.prank(owner);
        uint256 proposalId = proxyV1.createProposal("Upgrade Proposal", true);

        // 2. 투표 결과로 업그레이드 승인 (approveUpgrade)
        vm.prank(owner);
        proxyV1.approveUpgrade();
        // upgradeApproved == true

        // 3. owner로 DaoGovernanceV2 Implementation 배포
        vm.prank(owner);
        daoV2 = new DaoGovernanceV2();
        // V2는 reinitializer(2) 함수로 초기화
        vm.prank(owner);
        daoV2.initializeV2(ERC20Upgradeable(address(way)));

        // 4. proxy를 통해 V1의 upgradeImplementation() 함수 호출하여 업그레이드 실행
        vm.prank(owner);
        proxyV1.upgradeImplementation(address(daoV2));

        // 5. 이제 proxy는 V2 Implementation을 바라봄
        DaoGovernanceV2 proxyV2 = DaoGovernanceV2(address(proxy));
        // V2는 getVotingDuration() 함수와 version() 함수를 제공함
        assertEq(proxyV2.getVotingDuration(), 5 days);
        assertEq(proxyV2.version(), "V2");
    }
}
