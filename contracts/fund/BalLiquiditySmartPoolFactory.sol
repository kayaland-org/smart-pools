// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/balancer/IBFactory.sol";
import "../other/ProxyPausable.sol";
import "./BalLiquiditySmartPool.sol";

contract BalLiquiditySmartPoolFactory is Ownable {

  IBFactory public balancerFactory;
  address public smartPoolImplementation;
  mapping(address => bool) public isPool;
  address[] public pools;

  event SmartPoolCreated(address indexed poolAddress, string name, string symbol);

  function init(address _balancerFactory) public {
    require(smartPoolImplementation == address(0), "Already initialised");
    balancerFactory = IBFactory(_balancerFactory);

    BalLiquiditySmartPool implementation = new BalLiquiditySmartPool();
    implementation.init(address(1), "IMPL", "IMPL", 1 ether);
    smartPoolImplementation = address(implementation);
  }

  function newProxiedSmartPool(
    string memory _name,
    string memory _symbol,
    uint256 _initialSupply,
    address[] memory _tokens,
    uint256[] memory _amounts,
    uint256[] memory _weights,
    uint256 _cap
  ) public onlyOwner returns (address) {
    // Deploy proxy contract
    ProxyPausable proxy = new ProxyPausable();

    // Setup proxy
    proxy.setImplementation(smartPoolImplementation);
    proxy.setPauzer(msg.sender);
    proxy.setProxyOwner(msg.sender);

    // Setup balancer pool
    address balancerPoolAddress = balancerFactory.newBPool();
    IBPool bPool = IBPool(balancerPoolAddress);
    for (uint256 i = 0; i < _tokens.length; i++) {
      IERC20 token = IERC20(_tokens[i]);
      // Transfer tokens to this contract
      token.transferFrom(msg.sender, address(this), _amounts[i]);
      // Approve the balancer pool
      token.approve(balancerPoolAddress, uint256(-1));
      // Bind tokens
      bPool.bind(_tokens[i], _amounts[i], _weights[i]);
    }
    bPool.setController(address(proxy));

    // Setup smart pool
    BalLiquiditySmartPool smartPool = BalLiquiditySmartPool(address(proxy));

    smartPool.init(balancerPoolAddress, _name, _symbol, _initialSupply);
    smartPool.setCap(_cap);
    smartPool.setPublicSwapSetter(msg.sender);
    smartPool.setTokenBinder(msg.sender);
    smartPool.setController(msg.sender);
    smartPool.approveTokens();

    isPool[address(smartPool)] = true;
    pools.push(address(smartPool));
    smartPool.transfer(msg.sender, _initialSupply);
    emit SmartPoolCreated(address(smartPool), _name, _symbol);
    return address(smartPool);
  }
}
