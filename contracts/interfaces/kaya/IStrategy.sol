// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IStrategy {

    function init()external;

    function deposit(uint256 _amount)external;

    function withdraw(uint256 _amount)external;

    function withdrawOfUnderlying(address to,uint256 _amount)external;

    function extractableUnderlyingNumber(uint256 _amount)external view returns(uint256[] memory);

    function withdraw(address _token)external returns(uint256 balance);

    function withdrawAll()external;

    function assets()external view returns(uint256);

    function available() external view returns (uint256);
}
