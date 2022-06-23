pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockSAFU is ERC20 {
  constructor() public ERC20("MockSAFU", "MSAFU") {
    _mint(msg.sender, 10000*10**18);
  }
}