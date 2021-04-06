// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
interface IPool{

    event PoolJoined(address indexed sender,address indexed to, uint256 amount);
    event PoolExited(address indexed sender,address indexed from, uint256 amount);
    event TokensApproved(address indexed sender,address indexed to, uint256 amount);

    function approveTokens() external;

    function joinPool(address to,uint256 amount) external;

    function exitPool(address from,uint256 amount) external;
}
