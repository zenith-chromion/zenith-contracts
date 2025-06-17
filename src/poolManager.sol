// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CCIPSender} from "./ccipSender.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PoolManager {
    using SafeERC20 for IERC20;

    error PoolManager__Not_Fund_Manager();
    error PoolManager__Insufficient_Amount();

    event PoolManager__LiquidityAdded(
        uint256 indexed poolId,
        address depositor,
        uint256 amount
    );

    enum Tier {
        T1,
        T2,
        T3
    }

    address public immutable i_token;
    string public s_cidHash;
    uint256 public immutable i_poolId;
    CCIPSender public immutable i_ccipSender;

    mapping(address => bool) public s_isFM;
    mapping(address => Tier) public s_tiers;
    mapping(address => uint256) public s_fmWithdrawn; // total amount withdrawn by each fund manager
    mapping(Tier => uint256) public s_tierLimits; // percentage of the total liquidity that a fund manager of a specific tier can withdraw at a time

    modifier onlyFM() {
        if (!s_isFM[msg.sender]) {
            revert PoolManager__Not_Fund_Manager();
        }
        _;
    }

    constructor(
        address _token,
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
    }

    function addLiquidity(uint256 _amount) public {
        if (_amount == 0) {
            revert PoolManager__Insufficient_Amount();
        }
        IERC20(i_token).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(i_token).approve(address(i_ccipSender), _amount);
        if (block.chainid == 11155111) {
            // logic to be added
        } else {
            i_ccipSender.sendTokens(
                11155111, // destination chain ID for Sepolia
                i_token,
                address(0), // receiver address(pool) to be added
                _amount
            );
        }

        //logic to mint lp tokens to the depositor to be added
    }
}
