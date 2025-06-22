// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAny2EVMMessageReceiver} from "@ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Client} from "@ccip/libraries/Client.sol";
import {CCIPSender} from "./ccipSender.sol";

contract DaoAggregator is IAny2EVMMessageReceiver, Ownable {
    // state variables
    address public s_daoEthSepolia;
    address public s_daoArbitrumSepolia;
    address public s_daoPolygonTestnet;
    CCIPSender public s_ccipSender;
    mapping(uint256 proposalId => mapping(uint256 chainId => bool executed))
        public s_proposalExecuted;
    mapping(uint256 proposalId => uint256 posVotes) public s_proposalPosVotes;
    mapping(uint256 proposalId => uint256 negVotes) public s_proposalNegVotes;

    // constructor
    constructor() Ownable(msg.sender) {}

    // functions

    /**
     * @dev Receives messages from the CCIP network sent by the DAO contracts on different chains.
     * @param message The message containing proposal data, including proposalId, posVotes, and negVotes.
     * NOTE: 1. The function is called by the CCIP network when a message is received.
     *       2. The message must contain the proposalId, posVotes, and negVotes.
     *       3. In case the proposal has been executed on all chains, it sends the result to the respective
     *       DAO contracts.
     */
    function ccipReceive(
        Client.Any2EVMMessage calldata message
    ) external override {
        uint64 sourceChainSelector = message.sourceChainSelector;
        (uint256 proposalId, uint256 posVotes, uint256 negVotes) = abi.decode(
            message.data,
            (uint256, uint256, uint256)
        );
        s_proposalExecuted[proposalId][sourceChainSelector] = true;
        s_proposalPosVotes[proposalId] += posVotes;
        s_proposalNegVotes[proposalId] += negVotes;

        if (
            s_proposalExecuted[proposalId][1] && // Eth Sepolia
            s_proposalExecuted[proposalId][2] && // Arbitrum Sepolia
            s_proposalExecuted[proposalId][3] // Polygon Testnet, real chain id's to be added later
        ) {
            bool approved = (s_proposalPosVotes[proposalId] >=
                s_proposalNegVotes[proposalId]);

            s_ccipSender.sendProposalResult(
                1,
                proposalId,
                approved,
                s_daoEthSepolia
            );
            s_ccipSender.sendProposalResult(
                2,
                proposalId,
                approved,
                s_daoArbitrumSepolia
            );
            s_ccipSender.sendProposalResult(
                3,
                proposalId,
                approved,
                s_daoPolygonTestnet
            );
        }
    }

    /**
     * @dev Sets the DAO contract address for Ethereum Sepolia.
     * @param _daoEthSepolia The address of the DAO contract on Ethereum Sepolia.
     * NOTE: Only callable by the owner of the contract.
     */
    function setDaoEthSepolia(address _daoEthSepolia) external onlyOwner {
        s_daoEthSepolia = _daoEthSepolia;
    }

    /**
     * @dev Sets the DAO contract address for Arbitrum Sepolia.
     * @param _daoArbitrumSepolia The address of the DAO contract on Arbitrum Sepolia.
     * NOTE: Only callable by the owner of the contract.
     */
    function setDaoArbitrumSepolia(
        address _daoArbitrumSepolia
    ) external onlyOwner {
        s_daoArbitrumSepolia = _daoArbitrumSepolia;
    }

    /**
     * @dev Sets the DAO contract address for Polygon Testnet.
     * @param _daoPolygonTestnet The address of the DAO contract on Polygon Testnet.
     * NOTE: Only callable by the owner of the contract.
     */
    function setDaoPolygonTestnet(
        address _daoPolygonTestnet
    ) external onlyOwner {
        s_daoPolygonTestnet = _daoPolygonTestnet;
    }

    /**
     * @dev Sets the CCIP sender contract address on Ethereum Sepolia.
     * @param _ccipSender The address of the CCIP sender contract.
     * NOTE: Only callable by the owner of the contract.
     */
    function setCCIPSender(address _ccipSender) external onlyOwner {
        s_ccipSender = CCIPSender(_ccipSender);
    }
}
