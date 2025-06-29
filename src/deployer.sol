// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PoolManager} from "./poolManager.sol";
import {Factory} from "./factory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAny2EVMMessageReceiver} from "@ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {Client} from "@ccip/libraries/Client.sol";
import {CCIPReceiver} from "@ccip/applications/CCIPReceiver.sol";

contract Deployer is Ownable, CCIPReceiver {
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
    constructor(address _ccipSender, address _router) Ownable(msg.sender) CCIPReceiver(_router) {
        s_poolId = 0;
        i_ccipSender = _ccipSender;
    }

    // functions

    /**
     * @dev Deploys a new PoolManager contract. Used when a new pool is to be created.
     * @param _token The address of the token for the pool.
     * @param _cidHash The CID hash of the pool's metadata.
     * @return The address of the newly deployed PoolManager contract.
     * NOTE: The function is called on the the respective contract deployed on all the chains when a factory contract
     *       sends a message to deploy a new pool.
     */
    function deployNewPool(
        address _token,
        string memory _cidHash,
        address _fm,
        address _router
    ) internal returns (address) {
        PoolManager poolManager = new PoolManager(
            _token,
            _cidHash,
            s_poolId,
            i_ccipSender,
            _fm,
            _router
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
     * @dev Receives messages from the CCIP network to deploy new pools.
     * @param message The message containing the token address, CID hash, and fund manager address.
     * NOTE: 1. The function is called by the CCIP network when a message is sent from the factory contract.
     *       2. The message must contain the token address, CID hash, and fund manager address.
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        (address token, string memory cidHash, address fm) = abi.decode(
            message.data,
            (address, string, address)
        );
        deployNewPool(token, cidHash, fm, getRouter());
    }

    /**
     * @dev Sets the factory contract address. Only callable by the owner.
     * @param _factory The address of the factory contract.
     */
    function setFactory(address _factory) external onlyOwner {
        factory = Factory(_factory);
    }
}
