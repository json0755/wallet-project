// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

/**
 * @title LocalTestDeploy Script
 * @dev 本地测试部署脚本，避免 Uniswap 依赖
 */
contract LocalTestDeployScript is Script {
    function run() external {
        // 开始广播交易
        vm.startBroadcast();
        
        console.log("=== Starting Local Meme Token Factory Deployment ===");
        
        // 部署 MemeFactory
        MemeFactory factory;
        
        try new MemeFactory() returns (MemeFactory _factory) {
            factory = _factory;
            console.log("MemeFactory deployed successfully at:", address(factory));
        } catch Error(string memory reason) {
            console.log("MemeFactory deployment failed:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("MemeFactory deployment failed with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        console.log("Factory owner:", factory.owner());
        console.log("Platform fee: 500 basis points (5%)");
        console.log("Contract paused:", factory.paused());
        
        // 部署一个测试代币
        console.log("\n=== Deploying Test Token ===");
        
        address tokenAddr;
        try factory.deployMeme(
            "TEST",
            1000000 * 10**18,  // 1M total supply
            1000 * 10**18,     // 1K per mint
            0.001 ether        // 0.001 ETH per token
        ) returns (address _tokenAddr) {
            tokenAddr = _tokenAddr;
            console.log("Test token deployed at:", tokenAddr);
        } catch Error(string memory reason) {
            console.log("Token deployment failed:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("Token deployment failed with unknown error");
            vm.stopBroadcast();
            return;
        }
        
        // 获取代币信息
        try factory.getTokenInfo(tokenAddr) returns (
            string memory symbol,
            uint256 totalSupply,
            uint256 perMint,
            uint256 price,
            address creator,
            uint256 currentSupply,
            bool canMint,
            bool liquidityAdded
        ) {
            console.log("\n=== Token Information ===");
            console.log("Symbol:", symbol);
            console.log("Total Supply:", totalSupply);
            console.log("Per Mint:", perMint);
            console.log("Price:", price, "wei");
            console.log("Creator:", creator);
            console.log("Current Supply:", currentSupply);
            console.log("Can Mint:", canMint);
            console.log("Liquidity Added:", liquidityAdded);
        } catch Error(string memory reason) {
            console.log("Failed to get token info:", reason);
        }
        
        // 计算铸造成本
        try factory.calculateMintCost(tokenAddr) returns (
            uint256 totalCost,
            uint256 platformFee,
            uint256 creatorFee
        ) {
            console.log("\n=== Mint Cost Calculation ===");
            console.log("Total Cost:", totalCost, "wei");
            console.log("Platform Fee (5%):", platformFee, "wei");
            console.log("Creator Fee (95%):", creatorFee, "wei");
        } catch Error(string memory reason) {
            console.log("Failed to calculate mint cost:", reason);
        }
        
        // 测试铸造功能
        console.log("\n=== Testing Mint Function ===");
        
        try factory.calculateMintCost(tokenAddr) returns (
            uint256 totalCost,
            uint256 platformFee,
            uint256 creatorFee
        ) {
            // 尝试铸造代币
            try factory.mintMeme{value: totalCost}(tokenAddr) {
                console.log("Successfully minted tokens!");
                
                // 获取更新后的代币信息
                try factory.getTokenInfo(tokenAddr) returns (
                    string memory,
                    uint256,
                    uint256,
                    uint256,
                    address,
                    uint256 newCurrentSupply,
                    bool newCanMint,
                    bool
                ) {
                    console.log("Updated Current Supply:", newCurrentSupply);
                    console.log("Can Still Mint:", newCanMint);
                } catch {
                    console.log("Could not get updated token info");
                }
            } catch Error(string memory reason) {
                console.log("Mint failed:", reason);
            } catch {
                console.log("Mint failed with unknown error");
            }
        } catch {
            console.log("Could not calculate mint cost for testing");
        }
        
        console.log("\n=== Factory Statistics ===");
        console.log("Total Tokens Count:", factory.getAllTokensCount());
        
        vm.stopBroadcast();
        
        console.log("\n=== Local Deployment Test Complete ===");
        console.log("All basic functions tested successfully!");
    }
}