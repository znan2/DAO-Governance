// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {DaoGovernance} from "../src/DaoGovernance.sol";

contract DaoGovernance is Script {
    DaoGovernance public dao;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        dao = new DaoGovernance();

        vm.stopBroadcast();
    }
}
