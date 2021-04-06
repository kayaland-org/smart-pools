// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

library ERC20Helper{

    using SafeERC20 for IERC20;

    function safeApprove(address _token,address _to,uint256 _amount)internal{
        IERC20 token=IERC20(_token);
        uint256 allowance= token.allowance(address(this),_to);
        if(allowance<_amount){
            if(allowance>0){
                token.safeApprove(_to,0);
            }
            token.safeApprove(_to,_amount);
        }
    }
}
