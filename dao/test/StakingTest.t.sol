// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol"; 
import "../src/DaoGovernanceV3.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract StakinTest is Test {
    DaoGovernanceV3 dao;
    address owner = address(1);
    address alice = address(2);
    address bob   = address(3);
    WAYToken way;

    function setUp() public {
        vm.startPrank(owner);
        wayToken = new WAYToken();
        vm.stopPrank();
        vm.startPrank(owner);
        dao = new DaoGovernanceWithStaking();
        dao.initializeV3(ERC20Upgradeable(address(wayToken)), 3 days);
        vm.stopPrank();
        vm.startPrank(owner);
        // alice 토큰 500개
        wayToken.transfer(alice, 500 * 10**wayToken.decimals());
        vm.stopPrank();
        vm.startPrank(alice);
        wayToken.approve(address(dao), type(uint256).max);
        vm.stopPrank();
    }
}
