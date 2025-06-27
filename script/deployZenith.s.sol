// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DaoAggregator} from "../src/daoAggregator.sol";
import {CCIPSender} from "../src/ccipSender.sol";
import {Deployer} from "../src/deployer.sol";
import {Factory} from "../src/factory.sol";

contract DeployDaoAggregator is Script {
    function run() public returns (DaoAggregator) {
        vm.startBroadcast();
        DaoAggregator daoAggregator = new DaoAggregator();
        vm.stopBroadcast();
        return daoAggregator;
    }
}

contract DeployCCIPSender is Script {
    function run() public returns (CCIPSender) {
        address router = vm.envAddress("CCIP_ROUTER");
        address linkToken = vm.envAddress("LINK_TOKEN");
        vm.startBroadcast();
        CCIPSender ccipSender = new CCIPSender(router, linkToken);
        vm.stopBroadcast();
        return ccipSender;
    }
}

contract DeployDeployer is Script {
    function run() public returns (Deployer) {
        address ccipSender = vm.envAddress("CCIP_SENDER");
        vm.startBroadcast();
        Deployer deployer = new Deployer(ccipSender);
        vm.stopBroadcast();
        return deployer;
    }
}

contract DeployFactory is Script {
    function run() public returns (Factory) {
        vm.startBroadcast();
        Factory factory = new Factory(
            0xcC6711ea916Bbd0713b440D734580605E0f2500b,
            0xf8dC7E714Fca80C7F732f15B6c585D6878FE065E,
            0x3BCE2eA01dA58A3790AF5235830F00a4A5ab64a6,
            0x18B93432ee5651c0B54c38a656F9e5201D1bF0D1
        );
        vm.stopBroadcast();
        return factory;
    }
}
