// factory contracts are used to deploy multiple instances of other contracts.
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Deployer} from "./deployer.sol";

contract Factory {
    Deployer public deployerArbitrumSepolia;
    Deployer public deployerEthSepolia;
    Deployer public deployerPolygon;

    constructor(
        address _deployerArbitrumSepolia,
        address _deployerEthSepolia,
        address _deployerPolygon
    ) {
        deployerArbitrumSepolia = Deployer(_deployerArbitrumSepolia);
        deployerEthSepolia = Deployer(_deployerEthSepolia);
        deployerPolygon = Deployer(_deployerPolygon);
    }

    function createNewPool(
        address _tokenArbitrum,
        address _tokenEth,
        address _tokenPolygon,
        string memory _cidHash
    ) public returns (address, address, address) {
        address poolArbitrumSepolia = deployerArbitrumSepolia.deployNewPool(
            _tokenArbitrum,
            _cidHash,
            msg.sender
        );
        address poolEthSepolia = deployerEthSepolia.deployNewPool(
            _tokenEth,
            _cidHash,
            msg.sender
        );
        address poolPolygon = deployerPolygon.deployNewPool(
            _tokenPolygon,
            _cidHash,
            msg.sender
        );

        return (poolArbitrumSepolia, poolEthSepolia, poolPolygon);
    }
}
