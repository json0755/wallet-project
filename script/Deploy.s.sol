// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/tokenbank/Permit2.sol";
import "../src/tokenbank/EIP2612Token.sol";
import "../src/tokenbank/EIP2612TokenBank.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Permit2
        Permit2 permit2 = new Permit2();
        console.log("Permit2 deployed to:", address(permit2));

        // Deploy EIP2612Token
        EIP2612Token token = new EIP2612Token(
            "EIP2612 Test Token",
            "E2612",
            1000000,
            18,
            0
        );
        console.log("EIP2612Token deployed to:", address(token));

        // Deploy EIP2612TokenBank
        EIP2612TokenBank tokenBank = new EIP2612TokenBank(
            IERC20(address(token)),
            address(permit2)
        );
        console.log("EIP2612TokenBank deployed to:", address(tokenBank));

        vm.stopBroadcast();
    }
}