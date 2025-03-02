// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

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
        uint256 deployerPrivateKey = "PK";
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast();
        DaoGovernanceV1 daoV1 = new DaoGovernanceV1();
        WAYToken token = new WAYToken();
        // V1 초기화
        bytes memory initDataV1 = abi.encodeWithSelector(
            daoV1.initialize.selector,
            ERC20Upgradeable(address(token))
        );
        // 프록시 배포
        DaoProxy proxy = new DaoProxy(address(daoV1), initDataV1);
        // V1
        DaoGovernanceV1 governanceV1 = DaoGovernanceV1(address(proxy));
        console.log("V1 deployed via proxy at:", address(proxy));

        DaoGovernanceV2 daoV2 = new DaoGovernanceV2();
        bytes memory initDataV2 = abi.encodeWithSelector(
            DaoGovernanceV2.initializeV2.selector,
            ERC20Upgradeable(address(token))
        );
        governanceV1.approveUpgrade();
        governanceV1.upgradeImplementation(address(daoV2), initDataV2);

        // V2
        DaoGovernanceV2 governanceV2 = DaoGovernanceV2(address(proxy));
        DaoGovernanceV3 daoV3 = new DaoGovernanceV3();
        bytes memory initDataV3 = abi.encodeWithSelector(
            DaoGovernanceV3.initializeV3.selector,
            ERC20Upgradeable(address(token))
        );
        governanceV2.approveUpgrade();
        governanceV2.upgradeImplementation(address(daoV3), initDataV3);

        // V3
        DaoGovernanceV3 governanceV3 = DaoGovernanceV3(address(proxy));
    }
}
