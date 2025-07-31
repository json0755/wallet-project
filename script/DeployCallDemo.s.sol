// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";
import "../src/call/ContractA.sol";
import "../src/call/ContractB.sol";

contract DeployCallDemoScript is Script {
    function run() public {
        vm.startBroadcast();
        
        // 部署ContractB
        ContractB contractB = new ContractB();
        console.log("ContractB deployed at:", address(contractB));
        
        // 部署ContractA，传入ContractB的地址
        ContractA contractA = new ContractA(address(contractB));
        console.log("ContractA deployed at:", address(contractA));
        
        console.log("\n=== Initial State ===");
        console.log("ContractA counter:", contractA.getCounter());
        console.log("ContractB counter:", contractB.getCounter());
        
        // 演示delegatecall
        console.log("\n=== DelegateCall Demo ===");
        contractA.delegateCallIncrement();
        console.log("After delegatecall - ContractA counter:", contractA.getCounter());
        console.log("After delegatecall - ContractB counter:", contractB.getCounter());
        
        // 演示普通call
        console.log("\n=== Normal Call Demo ===");
        contractA.normalCallIncrement();
        console.log("After normal call - ContractA counter:", contractA.getCounter());
        console.log("After normal call - ContractB counter:", contractB.getCounter());
        
        vm.stopBroadcast();
    }
}