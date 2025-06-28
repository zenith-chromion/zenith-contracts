// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DaoAggregator} from "../src/daoAggregator.sol";
import {CCIPSender} from "../src/ccipSender.sol";
import {Deployer} from "../src/deployer.sol";
import {Factory} from "../src/factory.sol";

contract DeployDaoAggregator is Script {
    function run() public returns (DaoAggregator) {
        address ccipRouter = vm.envAddress("CCIP_ROUTER");
        vm.startBroadcast();
        DaoAggregator daoAggregator = new DaoAggregator(ccipRouter);
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
        address router = vm.envAddress("CCIP_ROUTER");
        vm.startBroadcast();
        Deployer deployer = new Deployer(ccipSender, router);
        vm.stopBroadcast();
        return deployer;
    }
}

contract DeployFactory is Script {
    function run() public returns (Factory) {
        vm.startBroadcast();
        address deployerArbitrum = vm.envAddress("DEPLOYER_ARBITRUM");
        address deployerEth = vm.envAddress("DEPLOYER_ETH");
        address deployerBase = vm.envAddress("DEPLOYER_BASE");
        address ccipSender = vm.envAddress("CCIP_SENDER");
        Factory factory = new Factory(
            deployerArbitrum,
            deployerEth,
            deployerBase,
            ccipSender
        );
        vm.stopBroadcast();
        return factory;
    }
}
