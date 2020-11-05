// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20{
  constructor (string memory name, string memory symbol,uint256 totalSupply) public ERC20(name,symbol) {
      _mint(msg.sender,totalSupply.mul(10**18));
  }
}
