// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

/**
 * @title DeployAndInit 部署并初始化脚本
 * @dev 一站式部署MemeFactory并创建示例代币的脚本
 * 
 * 环境变量配置：
 * - PRIVATE_KEY: 部署者私钥（必需）
 * - TOKEN_SYMBOL: 代币符号（可选，默认"DEMO"）
 * - TOKEN_TOTAL_SUPPLY: 总供应量（可选，默认1000000）
 * - TOKEN_PER_MINT: 每次铸造量（可选，默认1000）
 * - TOKEN_PRICE: 代币价格（可选，默认0.001 ETH）
 * 
 * 使用示例：
 * forge script script/DeployAndInit.s.sol:DeployAndInitScript --rpc-url $RPC_URL --broadcast
 */
contract DeployAndInitScript is Script {
    // 默认代币参数
    string constant DEFAULT_SYMBOL = "DEMO";
    uint256 constant DEFAULT_TOTAL_SUPPLY = 1000000 * 1e18;
    uint256 constant DEFAULT_PER_MINT = 1000 * 1e18;
    uint256 constant DEFAULT_PRICE = 0.001 ether;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 从环境变量读取代币参数（如果未设置则使用默认值）
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", DEFAULT_SYMBOL);
        uint256 tokenTotalSupply = vm.envOr("TOKEN_TOTAL_SUPPLY", DEFAULT_TOTAL_SUPPLY);
        uint256 tokenPerMint = vm.envOr("TOKEN_PER_MINT", DEFAULT_PER_MINT);
        uint256 tokenPrice = vm.envOr("TOKEN_PRICE", DEFAULT_PRICE);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Starting Meme Factory Deployment and Initialization ===");
        
        // 1. 部署MemeFactory
        console.log("\n1. Deploying MemeFactory...");
        MemeFactory factory = new MemeFactory();
        
        console.log("MemeFactory deployed at:", address(factory));
        console.log("Owner:", factory.owner());
        console.log("Platform Fee:", factory.PLATFORM_FEE_BPS(), "basis points (5%)");
        console.log("Uniswap Router:", address(factory.UNISWAP_ROUTER()));
        console.log("Uniswap Factory:", address(factory.UNISWAP_FACTORY()));
        console.log("WETH Address:", factory.WETH());
        
        // 2. 部署示例代币
        console.log("\n2. Deploying sample Meme token...");
        console.log("Token Symbol:", tokenSymbol);
        console.log("Total Supply:", tokenTotalSupply / 1e18, "tokens");
        console.log("Per Mint:", tokenPerMint / 1e18, "tokens");
        console.log("Price:", tokenPrice, "wei per token");
        
        address tokenAddr = factory.deployMeme(
            tokenSymbol,
            tokenTotalSupply,
            tokenPerMint,
            tokenPrice
        );
        
        console.log("Sample token deployed at:", tokenAddr);
        
        // 3. 获取代币信息
        console.log("\n3. Token Information:");
        (
            string memory symbol,
            uint256 totalSupply,
            uint256 perMint,
            uint256 price,
            address creator,
            uint256 currentSupply,
            bool canMint,
            bool liquidityAdded
        ) = factory.getTokenInfo(tokenAddr);
        
        console.log("Symbol:", symbol);
        console.log("Total Supply Cap:", totalSupply / 1e18, "tokens");
        console.log("Per Mint Amount:", perMint / 1e18, "tokens");
        console.log("Price per Token:", price, "wei");
        console.log("Creator:", creator);
        console.log("Current Supply:", currentSupply / 1e18, "tokens");
        console.log("Can Mint:", canMint);
        console.log("Liquidity Added:", liquidityAdded);
        
        // 4. 计算铸造费用
        console.log("\n4. Minting Cost Analysis:");
        (uint256 totalCost, uint256 platformFee, uint256 creatorFee) = factory.calculateMintCost(tokenAddr);
        console.log("Total Cost:", totalCost, "wei");
        console.log("Platform Fee (5%):", platformFee, "wei");
        console.log("Creator Fee (95%):", creatorFee, "wei");
        
        // 5. 显示工厂统计信息
        console.log("\n5. Factory Statistics:");
        console.log("Total Tokens Created:", factory.getAllTokensCount());
        console.log("Contract Paused:", factory.paused());
        
        // 6. 显示储备金信息
        console.log("\n6. Reserves Information:");
        uint256 ethReserve = factory.getReserves(tokenAddr);
        console.log("ETH Reserves for token:", ethReserve, "wei");
        
        console.log("\n=== Deployment and Initialization Complete ===");
        console.log("\nNext Steps:");
        console.log("1. Mint tokens: factory.mintMeme{value: totalCost}(tokenAddr)");
        console.log("2. Add liquidity: factory.addLiquidity(tokenAddr)");
        console.log("3. Buy from Uniswap: factory.buyMeme{value: ethAmount}(tokenAddr)");
        
        vm.stopBroadcast();
    }
}