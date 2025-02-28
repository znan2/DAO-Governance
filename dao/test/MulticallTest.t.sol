// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/WAYToken.sol";
import "../src/DaoGovernanceV3.sol";

contract MulticallTest is Test {
    DaoGovernanceV3 dao;
    WAYToken wayToken;
    address owner = address(1);
    address alice = address(2);

    function setUp() public {
        vm.startPrank(owner);
        wayToken = new WAYToken();
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
}