// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
interface ISmartPool{

    function joinPool(uint256 amount) external;

    function exitPool(uint256 amount) external;

    function transferCash(address to,uint256 amount)external;

    function token()external view returns(address);

    function assets()external view returns(uint256);
}
