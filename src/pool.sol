// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Pool is ERC20, Ownable(msg.sender) {
    // errors
    error Pool__Insufficient_Amount();
    error Pool__Insufficient_Balance();

    // state variables
    address public immutable i_token;

    // constructor
    constructor(
        string memory name,
        string memory symbol,
        address token
    ) ERC20(name, symbol) {
        i_token = token;
    }

    // functions

    /**
     * @dev Mints tokens to the specified receiver.
     * @param _receiver The address to receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     * NOTE: Only the owner(poolManager) contract can call this function.
     */
    function mint(address _receiver, uint256 _amount) external onlyOwner {
        _mint(_receiver, _amount);
    }

    /**
     * @dev Burns tokens from the specified account.
     * @param _account The address from which to burn tokens.
     * @param _amount The amount of tokens to burn.
     * NOTE: Only the owner(poolManager) contract can call this function.
     */
    function burn(address _account, uint256 _amount) external onlyOwner {
        _burn(_account, _amount);
    }

    /**
     * @dev Transfers tokens from the pool to a specified address.
     * @param _to The address to which tokens will be transferred.
     * @param _amount The amount of tokens to transfer.
     * NOTE: Only the owner(poolManager) contract can call this function.
     */
    function transferTokens(address _to, uint256 _amount) external onlyOwner {
        if (_amount == 0) {
            revert Pool__Insufficient_Amount();
        }
        if (IERC20(i_token).balanceOf(address(this)) < _amount) {
            revert Pool__Insufficient_Balance();
        }

        IERC20(i_token).transfer(_to, _amount);
    }
}
