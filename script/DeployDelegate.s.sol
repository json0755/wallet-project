// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Delegate} from "../src/Delegate.sol";

/**
 * @title DeployDelegate
 * @dev 部署Delegate合约到Anvil网络的脚本
 */
contract DeployDelegate is Script {
    function run() external {
        // 获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署Delegate合约
        Delegate delegate = new Delegate();
        
        // 停止广播
        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("=== Delegate Contract Deployment ===");
        console.log("Delegate deployed to:", address(delegate));
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Block number:", block.number);
        console.log("Gas price:", tx.gasprice);
        
        // 验证合约部署
        require(address(delegate).code.length > 0, "Delegate deployment failed");
        console.log("Delegate contract deployed successfully!");
        
        // 输出前端配置信息
        console.log("\n=== Frontend Configuration ===");
        console.log("Add this to your contracts.ts:");
        console.log("DELEGATE: '%s' as `0x${string}`,", address(delegate));
    }
}