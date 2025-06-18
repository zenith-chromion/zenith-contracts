// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CCIPSender} from "./ccipSender.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pool} from './pool.sol';

contract PoolManager {
    using SafeERC20 for IERC20;

    // errors
    error PoolManager__Not_Fund_Manager();
    error PoolManager__Insufficient_Amount();

    // events
    event PoolManager__LiquidityAdded(
        uint256 indexed poolId,
        address depositor,
        uint256 amount
    );
    event poolManager__mintedLpTokensToDepositor();

    // state variables
    enum Tier {
        T1,
        T2,
        T3
    }

    address public immutable i_token; // ERC20 token
    string public s_cidHash; // IPFS Cid for metadata
    uint256 public immutable i_poolId; // different id's for different pools
    CCIPSender public immutable i_ccipSender; // instance of contract CCIPSender
    Pool public immutable i_pool; // created a new instance of pool as told by you.

    mapping(address => bool) public s_isFM; // whether an address is a fund manager or not
    mapping(address => Tier) public s_tiers; // addresss of fund manager mapped to its corresponding tier level
    mapping(address => uint256) public s_fmWithdrawn; // address of each fund manager mapped to total amount withdrawn by each fund manager
    mapping(Tier => uint256) public s_tierLimits; // percentage of the total liquidity that a fund manager of a specific tier can withdraw at a time

    // modifiers
    modifier onlyFM() {
        if (!s_isFM[msg.sender]) {
            revert PoolManager__Not_Fund_Manager();
        }
        _;
    }

    // constructor
    constructor(
        address _token, // which ERC20 token is used in the pool
        string memory _cidHash,
        uint256 _poolId,
        address _ccipSender,
        address _fm
    ) {
        i_token = _token;
        s_cidHash = _cidHash;
        i_poolId = _poolId;
        i_ccipSender = CCIPSender(_ccipSender);
        s_isFM[_fm] = true;
        s_tiers[_fm] = Tier.T1;

        s_tierLimits[Tier.T1] = 10;
        s_tierLimits[Tier.T2] = 15;
        s_tierLimits[Tier.T3] = 20;

        i_pool = new Pool("abc","def");
    }

    // functions

    /**
     * @dev Adds liquidity to the pool(on eth sepolia) by transferring tokens from the sender to the contract.
     * @param _amount The amount of tokens to add as liquidity.
     * NOTE: The contract must be approved to spend the specified amount of tokens by the sender.
     */
    function addLiquidity(uint256 _amount) public {
        if (_amount == 0) {
            revert PoolManager__Insufficient_Amount();
        }
        IERC20(i_token).safeTransferFrom(msg.sender, address(i_pool), _amount); // send the amount worth of tokens from user to contract
        IERC20(i_token).approve(address(i_ccipSender), _amount); // now this approoves ccipSender to transfer 'amount' worth of tokens to 
        if (block.chainid == 11155111) {
            // logic to be added
        } else {
            i_ccipSender.sendTokens(
                11155111, // destination chain ID for Sepolia
                i_token,
                address(i_pool), // receiver address(pool) to be added
                _amount
            );
        }

        //logic to mint lp tokens to the depositor to be added
        i_pool.mint(msg.sender, _amount); // msg.sender is the one whp is the receiver.
        emit poolManager__mintedLpTokensToDepositor();
    }
}
