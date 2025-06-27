// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Deployer} from "./deployer.sol";
import {CCIPSender} from "./ccipSender.sol";

contract Factory {
    Deployer public deployerArbitrumSepolia;
    Deployer public deployerEthSepolia;
    Deployer public deployerBase;
    CCIPSender public immutable i_ccipSender;

    constructor(
        address _deployerArbitrumSepolia,
        address _deployerEthSepolia,
        address _deployerBase,
        address _ccipSender
    ) {
        deployerArbitrumSepolia = Deployer(_deployerArbitrumSepolia);
        deployerEthSepolia = Deployer(_deployerEthSepolia);
        deployerBase = Deployer(_deployerBase);
        i_ccipSender = CCIPSender(_ccipSender);
    }

    function createNewPool(
        address _tokenArbitrum,
        address _tokenEth,
        address _tokenBase,
        string memory _cidHash
    ) public {
        i_ccipSender.sendPoolDetails(
            16015286601757825753,
            address(deployerEthSepolia),
            msg.sender,
            _tokenEth,
            _cidHash
        );
        i_ccipSender.sendPoolDetails(
            3478487238524512106,
            address(deployerArbitrumSepolia),
            msg.sender,
            _tokenArbitrum,
            _cidHash
        );
        i_ccipSender.sendPoolDetails(
            10344971235874465080,
            address(deployerBase),
            msg.sender,
            _tokenBase,
            _cidHash
        );
    }
}
