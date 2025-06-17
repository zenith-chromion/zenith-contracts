// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PoolManager} from "./poolManager.sol";
import {Factory} from "./factory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Deployer is Ownable {
    error Deployer__Unauthorized();

    event Deployer__PoolDeployed(
        address indexed poolAddress,
        address indexed token,
        string cidHash
    );

    uint256 public poolId;

    Factory public factory;

    constructor() Ownable(msg.sender) {
        poolId = 0;
    }

    function deployNewPool(
        address _token,
        string memory _cidHash
    ) external returns (address) {
        if (msg.sender != address(factory)) {
            revert Deployer__Unauthorized();
        }
        PoolManager poolManager = new PoolManager(_token, _cidHash, poolId);
        poolId++;

        emit Deployer__PoolDeployed(address(poolManager), _token, _cidHash);
        return address(poolManager);
    }

    function setFactory(address _factory) external onlyOwner {
        factory = Factory(_factory);
    }
}
