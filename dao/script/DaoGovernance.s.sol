// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";

contract DaoGovernanceScript is Script {
    //DaoGovernanceV1 public dao;
//
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        //dao = new DaoGovernanceV1();

        vm.stopBroadcast();
    }
}
