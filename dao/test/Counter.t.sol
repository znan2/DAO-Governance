// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "../src/DaoGovernance.sol";

contract DaoGovernanceTest is Test {
    DaoGovernance public dao;

    function setUp() public {
        dao = new DaoGovernance();
    }

    function test_Increment() public {
        
    }
}
