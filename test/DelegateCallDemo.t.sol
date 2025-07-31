// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/delegatecall/Storage.sol";
import "../src/delegatecall/Proxy.sol";
import "../src/delegatecall/CallComparison.sol";

/**
 * @title DelegateCallDemoTest
 * @dev 测试delegatecall的用法和效果
 */
contract DelegateCallDemoTest is Test {
    Storage public storageContract;
    Proxy public proxyContract;
    CallComparison public comparisonContract;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
    function setUp() public {
        // 部署合约
        storageContract = new Storage();
        proxyContract = new Proxy(address(storageContract));
        comparisonContract = new CallComparison(address(storageContract));
    }
    
    /**
     * @dev 测试基本的delegatecall功能
     */
    function testBasicDelegateCall() public {
        uint256 testValue = 100;
        
        // 通过代理合约使用delegatecall设置值
        vm.prank(user1);
        proxyContract.setValueViaDelegateCall(testValue);
        
        // 验证代理合约的状态被修改了
        assertEq(proxyContract.getValue(), testValue);
        assertEq(proxyContract.getOwner(), user1);
        
        // 验证原始存储合约的状态没有被修改
        assertEq(storageContract.getValue(), 0);
        assertEq(storageContract.owner(), address(0));
        
        console.log("=== Basic DelegateCall Test ===");
        console.log("Proxy contract value:", proxyContract.getValue());
        console.log("Proxy contract owner:", proxyContract.getOwner());
        console.log("Storage contract value:", storageContract.getValue());
        console.log("Storage contract owner:", storageContract.owner());
    }
    
    /**
     * @dev 测试delegatecall的累加功能
     */
    function testDelegateCallAddValue() public {
        uint256 initialValue = 50;
        uint256 addAmount = 30;
        
        // 先设置初始值
        vm.prank(user1);
        proxyContract.setValueViaDelegateCall(initialValue);
        
        // 然后增加值
        vm.prank(user2);
        proxyContract.addValueViaDelegateCall(addAmount);
        
        // 验证结果
        assertEq(proxyContract.getValue(), initialValue + addAmount);
        assertEq(proxyContract.getOwner(), user2); // 最后操作者
        
        console.log("=== DelegateCall Add Value Test ===");
        console.log("Final value:", proxyContract.getValue());
        console.log("Last operator:", proxyContract.getOwner());
    }
    
    /**
     * @dev 对比call和delegatecall的区别
     */
    function testCallVsDelegateCall() public {
        uint256 testValue = 200;
        
        console.log("=== Call vs DelegateCall Comparison ===");
        
        // 使用普通call
        vm.prank(user1);
        comparisonContract.useCall(testValue);
        
        console.log("After using Call:");
        (uint256 compValue, address compOwner, address compCaller) = comparisonContract.getCurrentState();
        console.log("  Comparison contract value:", compValue);
        console.log("  Comparison contract owner:", compOwner);
        console.log("  Storage contract value:", storageContract.getValue());
        console.log("  Storage contract owner:", storageContract.owner());
        
        // 重置状态
        comparisonContract.resetState();
        
        // 使用delegatecall
        vm.prank(user2);
        comparisonContract.useDelegateCall(testValue);
        
        console.log("After using DelegateCall:");
        (compValue, compOwner, compCaller) = comparisonContract.getCurrentState();
        console.log("  Comparison contract value:", compValue);
        console.log("  Comparison contract owner:", compOwner);
        console.log("  Storage contract value:", storageContract.getValue());
        console.log("  Storage contract owner:", storageContract.owner());
    }
    
    /**
     * @dev 测试通用delegatecall函数
     */
    function testGenericDelegateCall() public {
        uint256 testValue = 300;
        
        // 编码函数调用
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", testValue);
        
        // 使用通用delegatecall函数
        vm.prank(user1);
        (bool success, ) = proxyContract.delegateCallToImplementation(data);
        
        assertTrue(success);
        assertEq(proxyContract.getValue(), testValue);
        assertEq(proxyContract.getOwner(), user1);
        
        console.log("=== Generic DelegateCall Test ===");
        console.log("Call success:", success);
        console.log("Set value:", proxyContract.getValue());
    }
    
    /**
     * @dev 测试更新实现合约
     */
    function testUpdateImplementation() public {
        // 部署新的存储合约
        Storage newStorage = new Storage();
        
        // 更新实现合约地址
        proxyContract.updateImplementation(address(newStorage));
        
        // 验证实现合约地址已更新
        assertEq(proxyContract.implementation(), address(newStorage));
        
        console.log("=== Update Implementation Test ===");
        console.log("New implementation address:", proxyContract.implementation());
    }
}