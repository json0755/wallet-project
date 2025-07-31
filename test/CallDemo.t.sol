// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";
import "../src/call/ContractA.sol";
import "../src/call/ContractB.sol";

contract CallDemoTest is Test {
    ContractA public contractA;
    ContractB public contractB;
    
    function setUp() public {
        // 部署B合约
        contractB = new ContractB();
        
        // 部署A合约，传入B合约地址
        contractA = new ContractA(address(contractB));
    }
    
    function testDelegateCallIncrement() public {
        console.log("=== DelegateCall Increment Test ===");
        
        // 初始状态
        console.log("Initial state:");
        console.log("ContractA counter:", contractA.getCounter());
        console.log("ContractB counter:", contractB.getCounter());
        
        // 通过A合约delegatecall调用B合约的increment方法
        contractA.delegateCallIncrement();
        
        console.log("\nAfter delegatecall increment:");
        console.log("ContractA counter:", contractA.getCounter());
        console.log("ContractB counter:", contractB.getCounter());
        
        // 验证结果：A合约的counter应该增加，B合约的counter保持不变
        assertEq(contractA.getCounter(), 1, "ContractA counter should be 1");
        assertEq(contractB.getCounter(), 0, "ContractB counter should remain 0");
    }
    
    function testNormalCallIncrement() public {
        console.log("\n=== Normal Call Increment Test ===");
        
        // 初始状态
        console.log("Initial state:");
        console.log("ContractA counter:", contractA.getCounter());
        console.log("ContractB counter:", contractB.getCounter());
        
        // 通过A合约普通call调用B合约的increment方法
        contractA.normalCallIncrement();
        
        console.log("\nAfter normal call increment:");
        console.log("ContractA counter:", contractA.getCounter());
        console.log("ContractB counter:", contractB.getCounter());
        
        // 验证结果：A合约的counter保持不变，B合约的counter应该增加
        assertEq(contractA.getCounter(), 0, "ContractA counter should remain 0");
        assertEq(contractB.getCounter(), 1, "ContractB counter should be 1");
    }
    
    function testMultipleDelegateCalls() public {
        console.log("\n=== Multiple DelegateCalls Test ===");
        
        // 多次delegatecall
        for (uint i = 0; i < 3; i++) {
            contractA.delegateCallIncrement();
        }
        
        console.log("After 3 delegatecalls:");
        console.log("ContractA counter:", contractA.getCounter());
        console.log("ContractB counter:", contractB.getCounter());
        
        // 验证结果
        assertEq(contractA.getCounter(), 3, "ContractA counter should be 3");
        assertEq(contractB.getCounter(), 0, "ContractB counter should remain 0");
    }
    
    function testMixedCalls() public {
        console.log("\n=== Mixed Calls Test ===");
        
        // 先delegatecall，再normalcall
        contractA.delegateCallIncrement();
        contractA.normalCallIncrement();
        
        console.log("After 1 delegatecall + 1 normal call:");
        console.log("ContractA counter:", contractA.getCounter());
        console.log("ContractB counter:", contractB.getCounter());
        
        // 验证结果
        assertEq(contractA.getCounter(), 1, "ContractA counter should be 1");
        assertEq(contractB.getCounter(), 1, "ContractB counter should be 1");
    }
}