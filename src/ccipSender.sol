// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRouterClient} from "@ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CCIPSender {
    using SafeERC20 for IERC20;

    // errors
    error CCIPSender__Insufficient_Link_Balance();
    error CCIPSender__Invalid_Receiver();

    // events
    event CCIPSender__TokensSent(
        uint64 indexed destinationChainId,
        address indexed token,
        address indexed receiver,
        uint256 amount
    );

    // state variables
    IRouterClient public immutable i_router;
    IERC20 public immutable i_linkToken;

    // constructor
    constructor(address _router, address _linkToken) {
        i_router = IRouterClient(_router);
        i_linkToken = IERC20(_linkToken);
    }

    // functions

    /**
     * @dev Sends tokens to a specified receiver on a destination chain.
     * @param _destinationChainId The ID of the destination chain.
     * @param _token The address of the token to send.
     * @param _receiver The address of the receiver on the destination chain.
     * @param _amount The amount of tokens to send.
     * NOTE: 1. The function is called by the PoolManager contract deployed on the respective chain.
     *       2. The receiver address must not be zero.
     *       3. The contract must be approved to spend the specified amount of tokens by the sender.
     */
    function sendTokens(
        uint64 _destinationChainId,
        address _token,
        address _receiver,
        uint256 _amount
    ) external {
        if (_receiver == address(0)) {
            revert CCIPSender__Invalid_Receiver();
        }

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        Client.EVMTokenAmount[]
            memory tokenAmount = new Client.EVMTokenAmount[](1);
        tokenAmount[0] = Client.EVMTokenAmount({
            token: _token,
            amount: _amount
        });
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: "",
            tokenAmounts: tokenAmount,
            feeToken: address(i_linkToken),
            extraArgs: ""
        });

        uint256 fee = i_router.getFee(_destinationChainId, message);
        if (fee > i_linkToken.balanceOf(address(this))) {
            revert CCIPSender__Insufficient_Link_Balance();
        }
        i_linkToken.approve(address(i_router), fee);

        i_router.ccipSend(_destinationChainId, message);
        emit CCIPSender__TokensSent(
            _destinationChainId,
            _token,
            _receiver,
            _amount
        );
    }
}
