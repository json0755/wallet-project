// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; 

import "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";

contract MyToken is ERC1363 { 
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {  
        _mint(msg.sender, 100*1e18);
    }
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}