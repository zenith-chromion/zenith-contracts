// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from '../lib/openzeppelin-contracts/contracts/access/Ownable.sol';

contract Pool is ERC20,Ownable(msg.sender)  {// this contract will be deployed from poolManager.sol , so it will be the owner
    
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        
    }
    function mint(address _receiver, uint256 _amount) external onlyOwner {
        _mint(_receiver, _amount);
    }

}