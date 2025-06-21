// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CCIPSender} from "./ccipSender.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pool} from "./pool.sol";
import {Dao} from "./dao.sol";

contract PoolManager {
    using SafeERC20 for IERC20;

    // errors
    error PoolManager__Not_Fund_Manager();
    error PoolManager__Insufficient_Amount();
    error PoolManager__Insufficient_Balance();
    error PoolManager__Limit_Exceeded();

    // events
    event PoolManager__LiquidityAdded(
        uint256 indexed poolId,
        address depositor,
        uint256 amount
    );
    event PoolManager__LiquidityRemoved(
        uint256 indexed poolId,
        address withdrawer,
        uint256 amount
    );
    event PoolManager__FundsWithdrawn(
        uint256 indexed poolId,
        address fundManager,
        uint256 amount
    );
    event PoolManager__FundsReturned(
        uint256 indexed poolId,
        address fundManager,
        uint256 amount
    );

    // state variables
    enum Tier {
        T1,
        T2,
        T3
    }

    address public immutable i_token;
    string public s_cidHash; // IPFS Cid for metadata
    uint256 public immutable i_poolId;
    CCIPSender public immutable i_ccipSender;
    Pool public immutable i_pool;
    Dao public immutable i_dao;

    mapping(address => bool) public s_isFM;
    mapping(address => Tier) public s_tiers;
    mapping(address => uint256) public s_fmWithdrawn; // address of each fund manager mapped to total amount withdrawn by each fund manager
    mapping(Tier => uint256) public s_tierLimits; // percentage of the total liquidity that a fund manager of a specific tier can withdraw at a time
    mapping(Tier => uint256) public s_royalties; // percentage of the total profit that a fund manager of a specific tier can take as royalties

    // modifiers
    modifier onlyFM() {
        if (!s_isFM[msg.sender]) {
            revert PoolManager__Not_Fund_Manager();
        }
        _;
    }

    // constructor
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

        s_royalties[Tier.T1] = 5;
        s_royalties[Tier.T2] = 8;
        s_royalties[Tier.T3] = 12;

        i_pool = new Pool("abc", "def", _token);
        i_dao = new Dao();
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

        IERC20(i_token).safeTransferFrom(msg.sender, address(i_pool), _amount);
        i_pool.mint(msg.sender, _amount);

        emit PoolManager__LiquidityAdded(i_poolId, msg.sender, _amount);
    }

    /**
     * @dev Used to remove liquidity from the pool by burning the lp tokens and transferring the corresponding amount
     *      of tokens back to the lp.
     * @param _amount The number of lp tokens to burn.
     * NOTE: The amount of tokens transferred back to the lp is calculated based on the total liquidity in the pool.
     */
    function removeLiquidity(uint256 _amount) public {
        if (_amount == 0) revert PoolManager__Insufficient_Amount();
        if (_amount > i_pool.balanceOf(msg.sender)) {
            revert PoolManager__Insufficient_Balance();
        }

        uint256 totalLiquidity = getTotalLiquidity();
        uint256 amountToTransfer = (_amount * totalLiquidity) /
            i_pool.totalSupply();
        i_pool.burn(msg.sender, _amount);
        i_pool.transferTokens(msg.sender, amountToTransfer);

        emit PoolManager__LiquidityRemoved(
            i_poolId,
            msg.sender,
            amountToTransfer
        );
    }

    /**
     * @dev Withdraws liquidity from the pool by a fund manager.
     * @param _amount The amount of tokens to withdraw.
     * NOTE: The amount withdrawn by a fund manager is limited based on their tier.
     */
    function withdrawFunds(uint256 _amount) external onlyFM {
        if (_amount == 0) {
            revert PoolManager__Insufficient_Amount();
        }

        Tier tier = s_tiers[msg.sender];
        uint256 tierLimit = (getTotalLiquidity() * s_tierLimits[tier]) / 100;
        uint256 withdrawn = s_fmWithdrawn[msg.sender];

        if (withdrawn + _amount > tierLimit)
            revert PoolManager__Limit_Exceeded();

        s_fmWithdrawn[msg.sender] += _amount;
        i_pool.transferTokens(msg.sender, _amount);

        emit PoolManager__FundsWithdrawn(i_poolId, msg.sender, _amount);
    }

    /**
     * @dev Returns funds back to the pool after a withdrawal by the fund manager.
     * @param _amount The amount of tokens to return.
     * NOTE: If the total amount withdrawn by the fund manager is less than the amount returned,
     *       the profit is calculated and a royalty is transferred to the fund manager based on their tier.
     */
    function returnFunds(uint256 _amount) external onlyFM {
        if (_amount == 0) revert PoolManager__Insufficient_Amount();

        IERC20(i_token).safeTransferFrom(msg.sender, address(i_pool), _amount);

        Tier tier = s_tiers[msg.sender];
        uint256 totalWithdrawn = s_fmWithdrawn[msg.sender];

        if (totalWithdrawn < _amount) {
            s_fmWithdrawn[msg.sender] = 0;
            uint256 profit = _amount - totalWithdrawn;
            uint256 royalty = (profit * s_royalties[tier]) / 100;
            i_pool.transferTokens(msg.sender, royalty);
        } else {
            s_fmWithdrawn[msg.sender] -= _amount;
        }

        emit PoolManager__FundsReturned(i_poolId, msg.sender, _amount);
    }

    /**
     * @dev Used to get the total liquidity in the pool.
     * @return The total liquidity in the pool.
     */
    function getTotalLiquidity() public view returns (uint256) {
        return IERC20(i_token).balanceOf(address(i_pool));
    }

    /**
     * @dev Returns the balance of lp tokens for a given account.
     * @param _account The address of the account to check.
     * @return The balance of lp tokens for the account.
     */
    function getLpBalance(address _account) public view returns (uint256) {
        return i_pool.balanceOf(_account);
    }
}
