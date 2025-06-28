// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAny2EVMMessageReceiver} from "@ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Client} from "@ccip/libraries/Client.sol";
import {CCIPSender} from "./ccipSender.sol";
import {CCIPReceiver} from "@ccip/applications/CCIPReceiver.sol";

contract DaoAggregator is CCIPReceiver, Ownable {
    // state variables
    CCIPSender public s_ccipSender;
    mapping(uint256 proposalId => mapping(uint256 chainId => bool executed))
        public s_proposalExecuted;
    mapping(uint256 proposalId => uint256 posVotes) public s_proposalPosVotes;
    mapping(uint256 proposalId => uint256 negVotes) public s_proposalNegVotes;
    mapping(uint256 proposalId => address receiver)
        public s_ethSepoliaProposalReceiver;
    mapping(uint256 proposalId => address receiver)
        public s_arbitrumSepoliaProposalReceiver;
    mapping(uint256 proposalId => address receiver)
        public s_baseTestnetProposalReceiver;

    // constructor
    constructor(address _router) Ownable(msg.sender) CCIPReceiver(_router) {}

    // functions

    /**
     * @dev Receives messages from the CCIP network sent by the DAO contracts on different chains.
     * @param message The message containing proposal data, including proposalId, posVotes, and negVotes.
     * NOTE: 1. The function is called by the CCIP network when a message is received.
     *       2. The message must contain the proposalId, posVotes, and negVotes.
     *       3. In case the proposal has been executed on all chains, it sends the result to the respective
     *       DAO contracts.
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        uint64 sourceChainSelector = message.sourceChainSelector;
        (
            uint256 proposalId,
            uint256 posVotes,
            uint256 negVotes,
            address receiver
        ) = abi.decode(message.data, (uint256, uint256, uint256, address));
        s_proposalExecuted[proposalId][sourceChainSelector] = true;
        s_proposalPosVotes[proposalId] += posVotes;
        s_proposalNegVotes[proposalId] += negVotes;

        if (sourceChainSelector == 16015286601757825753) {
            s_ethSepoliaProposalReceiver[proposalId] = receiver;
        } else if (sourceChainSelector == 3478487238524512106) {
            s_arbitrumSepoliaProposalReceiver[proposalId] = receiver;
        } else if (sourceChainSelector == 10344971235874465080) {
            s_baseTestnetProposalReceiver[proposalId] = receiver;
        }

        if (
            s_proposalExecuted[proposalId][16015286601757825753] && // Eth Sepolia
            s_proposalExecuted[proposalId][3478487238524512106] && // Arbitrum Sepolia
            s_proposalExecuted[proposalId][10344971235874465080] // Base Sepolia
        ) {
            bool approved = (s_proposalPosVotes[proposalId] >=
                s_proposalNegVotes[proposalId]);

            s_ccipSender.sendProposalResult(
                16015286601757825753,
                proposalId,
                approved,
                s_ethSepoliaProposalReceiver[proposalId]
            );
            s_ccipSender.sendProposalResult(
                3478487238524512106,
                proposalId,
                approved,
                s_arbitrumSepoliaProposalReceiver[proposalId]
            );
            s_ccipSender.sendProposalResult(
                10344971235874465080,
                proposalId,
                approved,
                s_baseTestnetProposalReceiver[proposalId]
            );
        }
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
