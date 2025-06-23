// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Deployer} from "./deployer.sol";
import {CCIPSender} from "./ccipSender.sol";

contract Factory {
    Deployer public deployerArbitrumSepolia;
    Deployer public deployerEthSepolia;
    Deployer public deployerPolygon;
    CCIPSender public immutable i_ccipSender;

    constructor(
        address _deployerArbitrumSepolia,
        address _deployerEthSepolia,
        address _deployerPolygon,
        address _ccipSender
    ) {
        deployerArbitrumSepolia = Deployer(_deployerArbitrumSepolia);
        deployerEthSepolia = Deployer(_deployerEthSepolia);
        deployerPolygon = Deployer(_deployerPolygon);
        i_ccipSender = CCIPSender(_ccipSender);
    }

    function createNewPool(
        address _tokenArbitrum,
        address _tokenEth,
        address _tokenPolygon,
        string memory _cidHash
    ) public {
        i_ccipSender.sendPoolDetails(
            1,
            address(deployerEthSepolia),
            msg.sender,
            _tokenEth,
            _cidHash
        );
        i_ccipSender.sendPoolDetails(
            2,
            address(deployerArbitrumSepolia),
            msg.sender,
            _tokenArbitrum,
            _cidHash
        );
        i_ccipSender.sendPoolDetails(
            3,
            address(deployerPolygon),
            msg.sender,
            _tokenPolygon,
            _cidHash
        );
    }
}
