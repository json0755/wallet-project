// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/tokenbank/EIP2612Token.sol";

contract DeployEIP2612TokenScript is Script {
    function run() external {
        vm.startBroadcast();
        
        // Deploy EIP2612Token with permit support
        EIP2612Token token = new EIP2612Token(
            "BapeToken",      // name
            "BAPE",           // symbol
            10000,            // initialSupply (10,000 tokens)
            18,               // decimals
            0                 // supplyCap (0 = no cap)
        );
        
        console2.log("EIP2612Token deployed at:", address(token));
        console2.log("Token name:", token.name());
        console2.log("Token symbol:", token.symbol());
        console2.log("Token decimals:", token.decimals());
        console2.log("Initial supply:", token.totalSupply());
        
        vm.stopBroadcast();
    }
} 