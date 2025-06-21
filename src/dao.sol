// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PoolManager} from "./poolManager.sol";

contract Dao is Ownable {
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
    uint256 public constant VOTING_PERIOD = 7 days;
    PoolManager public immutable i_poolManager;

    // structs
    struct Proposal {
        ProposalType proposalType;
        address fm;
        uint256 value; // For CHANGE_TIER, it's the tier; for CHANGE_ROYALTY, it's the new royalty percentage; for CHANGE_MAX_WITHDRAWAL, it's the new limit
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    // constructor
    constructor() Ownable(msg.sender) {
        s_proposalId = 0;
        i_poolManager = PoolManager(msg.sender);
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
        uint256 value
    ) external returns (uint256 proposalId) {
        Proposal storage proposal = s_proposals[s_proposalId];
        proposal.proposalType = proposalType;
        proposal.fm = fm;
        proposal.value = value;
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
}
