pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockBUSD is ERC20 {
  constructor() public ERC20("MockBUSD", "MBUSD") {
    _mint(msg.sender, 10000*10**18);
  }
}