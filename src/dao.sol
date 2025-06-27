// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PoolManager} from "./poolManager.sol";
import {AutomationCompatibleInterface} from "../lib/chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {Client} from "@ccip/libraries/Client.sol";
import {CCIPSender} from "./ccipSender.sol";
import {IAny2EVMMessageReceiver} from "@ccip/interfaces/IAny2EVMMessageReceiver.sol";

contract Dao is
    Ownable,
    AutomationCompatibleInterface,
    IAny2EVMMessageReceiver
{
    // errors
    error Dao__Already_Voted();
    error Dao__Deadline_Exceeded();
    error Dao__Not_Eligible();

    // events
    event Dao__ProposalCreated(
        uint256 indexed proposalId,
        ProposalType proposalType,
        address indexed fm,
        uint256 value
    );
    event Dao__VoteCasted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support
    );
    event Dao__ProposalExecuted(
        uint256 indexed proposalId,
        ProposalType proposalType,
        bool approved
    );

    // enums
    enum ProposalType {
        ADD_FM,
        REMOVE_FM,
        CHANGE_TIER,
        CHANGE_ROYALTY,
        CHANGE_MAX_WITHDRAWAL
    }

    // state variables
    mapping(uint256 => Proposal) public s_proposals;
    uint256 public s_proposalId;
    uint256 public s_nextProposalToExecute; // tracks the next proposal to execute, is incremented after each execution
    uint256 public constant VOTING_PERIOD = 7 days;
    address public immutable i_daoAggregator;
    PoolManager public immutable i_poolManager;
    CCIPSender public immutable i_ccipSender;

    // structs
    struct Proposal {
        ProposalType proposalType;
        address fm;
        uint256 value; // for CHANGE_ROYALTY, it's the new royalty percentage; for CHANGE_MAX_WITHDRAWAL, it's the new limit
        uint256 tier;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    // constructor
    constructor(
        address _daoAggregator,
        address _ccipSender
    ) Ownable(msg.sender) {
        s_proposalId = 0;
        s_nextProposalToExecute = 0;
        i_poolManager = PoolManager(msg.sender);
        i_daoAggregator = _daoAggregator;
        i_ccipSender = CCIPSender(_ccipSender);
    }

    // functions

    /**
     * @dev Creates a new proposal.
     * @param proposalType The type of the proposal.
     * @param fm The address of the fund manager (FM) related to the proposal.
     * @param value The value associated with the proposal (e.g., tier, royalty percentage, or max withdrawal limit).
     * @return proposalId The ID of the created proposal.
     * NOTE: The function is called by the PoolManager contract deployed on the respective chain.
     */
    function createProposal(
        ProposalType proposalType,
        address fm,
        uint256 value,
        uint256 tier
    ) external returns (uint256 proposalId) {
        Proposal storage proposal = s_proposals[s_proposalId];
        proposal.proposalType = proposalType;
        proposal.fm = fm;
        proposal.value = value;
        proposal.tier = tier;
        proposal.votesFor = 0;
        proposal.votesAgainst = 0;
        proposal.deadline = block.timestamp + VOTING_PERIOD;
        proposal.executed = false;

        proposalId = s_proposalId;
        s_proposalId++;

        emit Dao__ProposalCreated(proposalId, proposalType, fm, value);
    }

    /**
     * @dev Casts a vote on a proposal.
     * @param proposalId The ID of the proposal to vote on.
     * @param support True if the voter supports the proposal, false otherwise.
     * NOTE: Only liquidity providers (LPs) can vote. The function checks if the voter has already voted, if the voting
     *       period has ended, and if the voter is eligible (has LP tokens).
     */
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = s_proposals[proposalId];

        if (block.timestamp > proposal.deadline)
            revert Dao__Deadline_Exceeded();
        if (proposal.hasVoted[msg.sender]) revert Dao__Already_Voted();
        if (i_poolManager.getLpBalance(msg.sender) == 0)
            revert Dao__Not_Eligible();

        proposal.hasVoted[msg.sender] = true;

        if (support) proposal.votesFor++;
        else proposal.votesAgainst++;

        emit Dao__VoteCasted(proposalId, msg.sender, support);
    }

    /**
     * @dev Checks if the upkeep is needed for the next proposal to execute.
     * @param data The data passed to the function (not used in this implementation).
     * @return upkeepNeeded True if the upkeep is needed, false otherwise.
     * @return data The data to be passed to the performUpkeep function (not used in this implementation).
     */
    function checkUpkeep(
        bytes calldata
    ) external view override returns (bool upkeepNeeded, bytes memory data) {
        Proposal storage proposal = s_proposals[s_nextProposalToExecute];
        upkeepNeeded = (!proposal.executed &&
            proposal.deadline <= block.timestamp);
    }

    /**
     * @dev Performs the upkeep for the next proposal to execute.
     * NOTE: The function sends the vote count to the DAO aggregator via CCIP and marks the proposal as executed.
     */
    function performUpkeep(bytes calldata) external override {
        Proposal storage proposal = s_proposals[s_nextProposalToExecute];
        i_ccipSender.sendVoteCount(
            16015286601757825753, // Eth Sepolia chain selector
            s_nextProposalToExecute,
            proposal.votesFor,
            proposal.votesAgainst,
            address(this),
            i_daoAggregator
        );

        proposal.executed = true;
        s_nextProposalToExecute++;
    }

    /**
     * @dev Receives the proposal result from the DAO aggregator via CCIP.
     * @param message The message containing the proposal result.
     * NOTE: The function executes the proposal based on the received data.
     */
    function ccipReceive(
        Client.Any2EVMMessage calldata message
    ) external override {
        (uint256 proposalId, bool approved) = abi.decode(
            message.data,
            (uint256, bool)
        );
        Proposal storage proposal = s_proposals[proposalId];

        if (approved) {
            if (proposal.proposalType == ProposalType.ADD_FM) {
                i_poolManager.addFundManager(proposal.fm);
            } else if (proposal.proposalType == ProposalType.REMOVE_FM) {
                i_poolManager.removeFundManager(proposal.fm);
            } else if (proposal.proposalType == ProposalType.CHANGE_TIER) {
                i_poolManager.changeTier(
                    proposal.fm,
                    PoolManager.Tier(proposal.tier)
                );
            } else if (proposal.proposalType == ProposalType.CHANGE_ROYALTY) {
                i_poolManager.changeRoyalties(
                    PoolManager.Tier(proposal.tier),
                    proposal.value
                );
            } else if (
                proposal.proposalType == ProposalType.CHANGE_MAX_WITHDRAWAL
            ) {
                i_poolManager.changeMaxWithdrawal(
                    PoolManager.Tier(proposal.tier),
                    proposal.value
                );
            }
        }

        emit Dao__ProposalExecuted(proposalId, proposal.proposalType, approved);
    }
}
