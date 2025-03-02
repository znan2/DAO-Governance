// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import { DaoGovernanceV1 } from "../src/DaoGovernanceV1.sol";
import { DaoGovernanceV2 } from "../src/DaoGovernanceV2.sol";
import { DaoGovernanceV3 } from "../src/DaoGovernanceV3.sol";
import { WAYToken } from "../src/WAYToken.sol";
import { DaoProxy } from "../src/DaoProxy.sol";

contract DaoGovernanceScript is Script {
    //DaoGovernanceV1 public dao;
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        vm.startBroadcast();
        DaoGovernanceV1 daoV1 = new DaoGovernanceV1();
        WAYToken token = new WAYToken();
        bytes memory initDataV1 = abi.encodeWithSelector(daoV1.initialize.selector, 
            ERC20Upgradeable(address(token))
        );

        DaoProxy proxy = new DaoProxy(address(daoV1), initDataV1);
        DaoGovernanceV1 governance = DaoGovernanceV1(address(proxy));

        DaoGovernanceV2 daoV2 = new DaoGovernanceV2();
        bytes memory initDataV2 = abi.encodeWithSelector(DaoGovernanceV2.initializeV2.selector, 
            ERC20Upgradeable(address(token))
        );
        governance.approveUpgrade();
        governance.upgradeImplementation(address(daoV2), initDataV2);
        DaoGovernanceV2 governanceV2 = DaoGovernanceV2(address(proxy));
        string memory ver = governanceV2.version();
        console.log(ver);
        vm.stopBroadcast();
    }
}
