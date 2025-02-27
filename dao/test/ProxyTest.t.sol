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
        vm.prank(owner);
        way = new WAYToken();
        vm.prank(owner);
        daoV1 = new DaoGovernanceV1();
        bytes memory initData = abi.encodeWithSignature("initialize(address,uint256)", ERC20Upgradeable(address(way)), 3 days);
        vm.prank(owner);
        proxy = new DaoProxy(address(daoV1), initData);
        //voting power
        vm.prank(owner);
        way.transfer(alice, 1);
    }

    function testProxyCallsV1Proposal() public {
        DaoGovernanceV1 proxyV1 = DaoGovernanceV1(address(proxy));
        vm.prank(owner);
        uint256 proposalId = proxyV1.createProposal("Test Proposal V1", true);
        assertEq(proposalId, proxyV1.proposalCount());
    }

    function testUpgradeFromV1ToV2() public {
        DaoGovernanceV1 proxyV1 = DaoGovernanceV1(address(proxy));
        vm.prank(owner);
        uint256 proposalId = proxyV1.createProposal("Upgrade Proposal", true);

        // 업그레이드 승인
        vm.prank(owner);
        proxyV1.approveUpgrade();

        // DaoGovernanceV2 배포
        vm.prank(owner);
        daoV2 = new DaoGovernanceV2();

        // V2는 reinitializer(2) 함수로 초기화
        vm.prank(owner);
        daoV2.initializeV2(ERC20Upgradeable(address(way)), 5 days);

        // upgradeImplementation() 함수 호출
        vm.prank(owner);
        proxyV1.upgradeImplementation(address(daoV2), abi.encodeWithSignature("initializeV2(address,uint256)", ERC20Upgradeable(address(way)), 5 days));

        DaoGovernanceV2 proxyV2 = DaoGovernanceV2(address(proxy));
        assertEq(proxyV2.getVotingDuration(), 5 days);
        assertEq(proxyV2.version(), "V2");
    }
}
