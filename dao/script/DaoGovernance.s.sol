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
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast();
        DaoGovernanceV1 daoV1 = new DaoGovernanceV1();
        WAYToken token = new WAYToken();
        bytes memory initDataV1 = abi.encodeWithSelector(daoV1.initialize.selector, 
            ERC20Upgradeable(address(token))
        );
        //프록시
        DaoProxy proxy = new DaoProxy(address(daoV1), initDataV1);
        DaoGovernanceV1 governance = DaoGovernanceV1(address(proxy));

        DaoGovernanceV2 daoV2 = new DaoGovernanceV2();
        bytes memory initDataV2 = abi.encodeWithSelector(DaoGovernanceV2.initializeV2.selector, 
            ERC20Upgradeable(address(token))
        );
        governance.approveUpgrade();
        //V2업그레이드
        governance.upgradeImplementation(address(daoV2), initDataV2);
        DaoGovernanceV2 governanceV2 = DaoGovernanceV2(address(proxy));
        string memory ver2 = governanceV2.version();
        console.log(ver2);

        DaoGovernanceV3 daoV3 = new DaoGovernanceV3();
        bytes memory initDataV3 = abi.encodeWithSelector(
            DaoGovernanceV3.initializeV3.selector, 
            ERC20Upgradeable(address(token))
        );
        governanceV2.approveUpgrade();
        //V3업그레이드
        governanceV2.upgradeImplementation(address(daoV3), initDataV3);
        DaoGovernanceV3 governanceV3 = DaoGovernanceV3(address(proxy));
        string memory ver3 = governanceV3.version();
        console.log(ver3);

        //스테이킹
        uint256 stakeAmount = 100 ether;
        token.approve(address(governanceV3), stakeAmount);

        console.log("Deployer balance before staking:", token.balanceOf(deployer));
        governanceV3.stake(stakeAmount);
        console.log("Deployer balance after staking:", token.balanceOf(deployer));
        //7일 뒤에 unstaking
        uint256 currentTime = block.timestamp;
        vm.warp(currentTime + 7 days + 1);
        uint256 unstakeAmount = stakeAmount / 2;
        governanceV3.unstake(unstakeAmount);
        console.log("Deployer balance after unstaking:", token.balanceOf(deployer));
        //출금
        governanceV3.withdraw();
        console.log("Deployer balance after withdraw:", token.balanceOf(deployer));
        vm.stopBroadcast();
    }
}
