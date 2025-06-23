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
    error PoolManager__Not_Dao();
    error PoolManager__Already_Fund_Manager();
    error PoolManager__Already_At_This_Tier();

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
    event PoolManager__FundManagerAdded(
        address indexed fundManager,
        PoolManager.Tier tier
    );
    event PoolManager__TierChanged(
        address indexed fundManager,
        PoolManager.Tier newTier
    );
    event PoolManager__RoyaltyChanged(
        PoolManager.Tier indexed tier,
        uint256 newRoyalty
    );
    event PoolManager__MaxWithdrawalChanged(
        PoolManager.Tier indexed tier,
        uint256 newLimit
    );
    event PoolManager__FundManagerRemoved(address indexed fundManager);

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

    modifier onlyDao() {
        if (msg.sender != address(i_dao)) {
            revert PoolManager__Not_Dao();
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
        i_dao = new Dao(address(0), _ccipSender); // address(0) is a placeholder, should be set to the DAO aggregator address later
    }

    // functions

    /**
     * @dev Adds liquidity to the pool(on the corresponding chain) by transferring tokens from the sender to the contract.
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
     * @dev Requests to become a fund manager by creating a proposal in the DAO.
     * NOTE: The proposal will be processed by the DAO and the fund manager will be added if the proposal is approved.
     */
    function requestFM() public {
        if (s_isFM[msg.sender]) revert PoolManager__Already_Fund_Manager();

        i_dao.createProposal(
            Dao.ProposalType.ADD_FM,
            msg.sender,
            0, // value is not used for this proposal type
            0 // tier is not used for this proposal type
        );
    }

    /**
     * @dev Requests to change the tier of the fund manager.
     * @param _tier The new tier to change to.
     * NOTE: The proposal will be processed by the DAO and the tier will be set to new tier if the proposal is approved.
     */
    function requestChangeTier(Tier _tier) public onlyFM {
        if (_tier == s_tiers[msg.sender])
            revert PoolManager__Already_At_This_Tier();

        i_dao.createProposal(
            Dao.ProposalType.CHANGE_TIER,
            msg.sender,
            0, // value is not used for this proposal type
            uint256(_tier)
        );
    }

    /**
     * @dev Proposes to remove a fund manager from the pool.
     * @param _fm The address of the fund manager to remove.
     * NOTE: The proposal will be processed by the DAO and the fund manager will be removed if the proposal is approved.
     */
    function proposeRemoveFM(address _fm) public {
        if (!s_isFM[_fm]) revert PoolManager__Not_Fund_Manager();

        i_dao.createProposal(
            Dao.ProposalType.REMOVE_FM,
            _fm,
            0, // value is not used for this proposal type
            0 // tier is not used for this proposal type
        );
    }

    /**
     * @dev Proposes to change the royalty percentage for a specific tier.
     * @param _royalty The new royalty percentage to set (between 0 and 100).
     * @param _tier The tier for which the royalty is being set.
     * NOTE: The proposal will be processed by the DAO and the royalty will be set if the proposal is approved.
     */
    function proposeChangeRoyalty(uint256 _royalty, Tier _tier) public {
        if (_royalty < 0 || _royalty > 100)
            revert PoolManager__Insufficient_Amount(); // royalty must be between 0 and 100

        i_dao.createProposal(
            Dao.ProposalType.CHANGE_ROYALTY,
            address(0), // no specific fund manager for this proposal
            _royalty,
            uint256(_tier) // tier is used to specify which tier's royalty is changing
        );
    }

    /**
     * @dev Proposes to change the maximum withdrawal limit for a specific tier.
     * @param _limit The new maximum withdrawal limit (between 0 and 100).
     * @param _tier The tier for which the limit is being set.
     * NOTE: The proposal will be processed by the DAO and the limit will be set if the proposal is approved.
     */
    function proposeMaxWithdrawal(uint256 _limit, Tier _tier) public {
        if (_limit < 0 || _limit > 100)
            revert PoolManager__Insufficient_Amount(); // limit must be between 0 and 100

        i_dao.createProposal(
            Dao.ProposalType.CHANGE_MAX_WITHDRAWAL,
            address(0), // no specific fund manager for this proposal
            _limit,
            uint256(_tier) // tier is used to specify which tier's limit is changing
        );
    }

    /**
     * @dev Adds a fund manager to the pool.
     * @param _fm The address of the fund manager to add.
     * NOTE: 1. Called by the DAO contract to when the proposal to add a fund manager is approved.
     *       2. The fund manager is added with a default tier of T1.
     */
    function addFundManager(address _fm) external onlyDao {
        s_isFM[_fm] = true;
        s_tiers[_fm] = Tier.T1; // default tier is T1

        emit PoolManager__FundManagerAdded(_fm, Tier.T1);
    }

    /**
     * @dev Removes a fund manager from the pool.
     * @param _fm The address of the fund manager to remove.
     * NOTE: 1. Called by the DAO contract when the proposal to remove a fund manager is approved.
     *       2. The fund manager is removed and their tier and withdrawn amount are reset.
     */
    function removeFundManager(address _fm) external onlyDao {
        if (!s_isFM[_fm]) revert PoolManager__Not_Fund_Manager();

        s_isFM[_fm] = false;
        delete s_tiers[_fm];
        delete s_fmWithdrawn[_fm];

        emit PoolManager__FundManagerRemoved(_fm);
    }

    /**
     * @dev Changes the tier of a fund manager.
     * @param _fm The address of the fund manager whose tier is being set.
     * @param _tier The new tier to set for the fund manager.
     * NOTE: 1. Called by the DAO contract when the proposal to change a fund manager's tier is approved.
     *       2. The fund manager must already exist in the pool.
     */
    function changeTier(address _fm, Tier _tier) external onlyDao {
        if (!s_isFM[_fm]) revert PoolManager__Not_Fund_Manager();
        if (_tier == s_tiers[_fm]) revert PoolManager__Already_At_This_Tier();

        s_tiers[_fm] = _tier;

        emit PoolManager__TierChanged(_fm, _tier);
    }

    /**
     * @dev Changes the royalty percentage for a specific tier.
     * @param _tier The tier for which the royalty is being set.
     * @param _royalty The new royalty percentage to set (between 0 and 100).
     * NOTE: Called by the DAO contract when the proposal to change royalty is approved.
     */
    function changeRoyalties(Tier _tier, uint256 _royalty) external onlyDao {
        if (_royalty < 0 || _royalty > 100)
            revert PoolManager__Insufficient_Amount();

        s_royalties[_tier] = _royalty;

        emit PoolManager__RoyaltyChanged(_tier, _royalty);
    }

    /**
     * @dev Changes the maximum withdrawal limit for a specific tier.
     * @param _tier The tier for which the limit is being set.
     * @param _limit The new maximum withdrawal limit (between 0 and 100).
     * NOTE: Called by the DAO contract when the proposal to change max withdrawal is approved.
     */
    function changeMaxWithdrawal(Tier _tier, uint256 _limit) external onlyDao {
        if (_limit < 0 || _limit > 100)
            revert PoolManager__Insufficient_Amount();

        s_tierLimits[_tier] = _limit;

        emit PoolManager__MaxWithdrawalChanged(_tier, _limit);
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
