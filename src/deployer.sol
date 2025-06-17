// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PoolManager} from "./poolManager.sol";
import {Factory} from "./factory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Deployer is Ownable {
    // errors
    error Deployer__Unauthorized();

    // events
    event Deployer__PoolDeployed(
        uint256 chainId,
        address indexed poolAddress,
        address indexed token,
        string cidHash
    );

    // state variables
    uint256 public s_poolId;
    address private immutable i_ccipSender;

    Factory public factory;

    // constructor
    constructor(address _ccipSender) Ownable(msg.sender) {
        s_poolId = 0;
        i_ccipSender = _ccipSender;
    }

    // functions

    /**
     * @dev Deploys a new PoolManager contract. Used when a new pool is to be created.
     * @param _token The address of the token for the pool.
     * @param _cidHash The CID hash of the pool's metadata.
     * @return The address of the newly deployed PoolManager contract.
     * NOTE: 1. The function is called on the the respective contract deployed on all the chains.
     *       2. Only callable by the factory contract.
     */
    function deployNewPool(
        address _token,
        string memory _cidHash,
        address _fm
    ) external returns (address) {
        if (msg.sender != address(factory)) {
            revert Deployer__Unauthorized();
        }
        PoolManager poolManager = new PoolManager(
            _token,
            _cidHash,
            s_poolId,
            i_ccipSender,
            _fm
        );
        s_poolId++;

        emit Deployer__PoolDeployed(
            block.chainid,
            address(poolManager),
            _token,
            _cidHash
        );
        return address(poolManager);
    }

    /**
     * @dev Sets the factory contract address. Only callable by the owner.
     * @param _factory The address of the factory contract.
     */
    function setFactory(address _factory) external onlyOwner {
        factory = Factory(_factory);
    }
}
