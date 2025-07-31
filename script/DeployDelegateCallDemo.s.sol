// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../src/delegatecall/Storage.sol";
import "../src/delegatecall/Proxy.sol";
import "../src/delegatecall/CallComparison.sol";

/**
 * @title DeployDelegateCallDemo
 * @dev 部署delegatecall演示合约的脚本
 */
contract DeployDelegateCallDemo is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署存储合约
        Storage storageContract = new Storage();
        console.log("Storage contract deployed at:", address(storageContract));
        
        // 2. 部署代理合约
        Proxy proxyContract = new Proxy(address(storageContract));
        console.log("Proxy contract deployed at:", address(proxyContract));
        
        // 3. 部署对比合约
        CallComparison comparisonContract = new CallComparison(address(storageContract));
        console.log("CallComparison contract deployed at:", address(comparisonContract));
        
        // 4. 演示基本用法
        console.log("\n=== Demonstrating DelegateCall ===");
        
        // 通过代理合约设置值
        proxyContract.setValueViaDelegateCall(1000);
        console.log("Set value 1000 via proxy contract");
        
        // 检查状态
        console.log("Proxy contract value:", proxyContract.getValue());
        console.log("Proxy contract owner:", proxyContract.getOwner());
        console.log("Storage contract value:", storageContract.getValue());
        console.log("Storage contract owner:", storageContract.owner());
        
        // 增加值
        proxyContract.addValueViaDelegateCall(500);
        console.log("\nAdded 500 to value via proxy contract");
        console.log("New proxy contract value:", proxyContract.getValue());
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("Storage:", address(storageContract));
        console.log("Proxy:", address(proxyContract));
        console.log("CallComparison:", address(comparisonContract));
    }
}