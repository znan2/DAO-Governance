// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import "../src/DaoGovernance.sol";

contract DaoGovernanceScript is Script {
    DaoGovernance public dao;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        dao = new DaoGovernance();

        vm.stopBroadcast();
    }
}
