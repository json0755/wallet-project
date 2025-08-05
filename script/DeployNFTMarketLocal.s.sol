// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/upgrade/NFTMarketV1.sol";
import "../src/upgrade/NFTMarketV2.sol";
import "../src/upgrade/UpgradeableNFT.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title DeployNFTMarketLocal
 * @dev 本地部署脚本，用于演示NFT市场从V1到V2的升级过程
 */
contract DeployNFTMarketLocal is Script {
    // 部署参数
    uint256 constant PLATFORM_FEE_RATE = 250; // 2.5%
    
    // 部署的合约地址
    address public proxyAdmin;
    address public nftImplementation;
    address public nftProxy;
    address public marketV1Implementation;
    address public marketV1Proxy;
    address public marketV2Implementation;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署ProxyAdmin
        console.log("\n=== Deploying ProxyAdmin ===");
        ProxyAdmin admin = new ProxyAdmin(deployer);
        proxyAdmin = address(admin);
        console.log("ProxyAdmin deployed at:", proxyAdmin);
        
        // 2. 部署UpgradeableNFT实现合约
        console.log("\n=== Deploying UpgradeableNFT Implementation ===");
        UpgradeableNFT nftImpl = new UpgradeableNFT();
        nftImplementation = address(nftImpl);
        console.log("UpgradeableNFT Implementation deployed at:", nftImplementation);
        
        // 3. 部署UpgradeableNFT代理合约
        console.log("\n=== Deploying UpgradeableNFT Proxy ===");
        bytes memory nftInitData = abi.encodeWithSelector(
            UpgradeableNFT.initialize.selector,
            "Upgradeable NFT",
            "UNFT",
            deployer
        );
        
        TransparentUpgradeableProxy nftProxyContract = new TransparentUpgradeableProxy(
            nftImplementation,
            proxyAdmin,
            nftInitData
        );
        nftProxy = address(nftProxyContract);
        console.log("UpgradeableNFT Proxy deployed at:", nftProxy);
        
        // 4. 部署NFTMarketV1实现合约
        console.log("\n=== Deploying NFTMarketV1 Implementation ===");
        NFTMarketV1 marketV1Impl = new NFTMarketV1();
        marketV1Implementation = address(marketV1Impl);
        console.log("NFTMarketV1 Implementation deployed at:", marketV1Implementation);
        
        // 5. 部署NFTMarketV1代理合约（使用ERC1967Proxy for UUPS）
        console.log("\n=== Deploying NFTMarketV1 Proxy ===");
        bytes memory marketV1InitData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector,
            deployer,
            deployer,
            PLATFORM_FEE_RATE
        );
        
        ERC1967Proxy marketV1ProxyContract = new ERC1967Proxy(
            marketV1Implementation,
            marketV1InitData
        );
        marketV1Proxy = address(marketV1ProxyContract);
        console.log("NFTMarketV1 Proxy deployed at:", marketV1Proxy);
        
        // 6. 部署NFTMarketV2实现合约
        console.log("\n=== Deploying NFTMarketV2 Implementation ===");
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        marketV2Implementation = address(marketV2Impl);
        console.log("NFTMarketV2 Implementation deployed at:", marketV2Implementation);
        
        // 7. 升级市场合约从V1到V2（使用UUPS升级）
        console.log("\n=== Upgrading Market from V1 to V2 ===");
        
        // 使用UUPS升级方式
        NFTMarketV1(marketV1Proxy).upgradeToAndCall(
            marketV2Implementation,
            "" // 空的data，不调用任何函数
        );
        console.log("Market upgraded to V2 successfully");
        
        vm.stopBroadcast();
        
        // 8. 验证部署
        console.log("\n=== Verification ===");
        UpgradeableNFT nft = UpgradeableNFT(nftProxy);
        console.log("NFT Name:", nft.name());
        console.log("NFT Symbol:", nft.symbol());
        console.log("NFT Owner:", nft.owner());
        
        NFTMarketV2 market = NFTMarketV2(marketV1Proxy);
        console.log("Market Owner:", market.owner());
        console.log("Market Fee Rate:", market.platformFeeRate());
        console.log("Market Fee Recipient:", market.feeRecipient());
        
        // 9. 保存部署地址
        console.log("\n=== Deployment Summary ===");
        console.log("ProxyAdmin:", proxyAdmin);
        console.log("UpgradeableNFT_Implementation:", nftImplementation);
        console.log("UpgradeableNFT_Proxy:", nftProxy);
        console.log("NFTMarketV1_Implementation:", marketV1Implementation);
        console.log("NFTMarketV2_Implementation:", marketV2Implementation);
        console.log("NFTMarket_Proxy (V2):", marketV1Proxy);
        
        // 保存地址到文件
        string memory addresses = string.concat(
            "# NFT Market Local Deployment Addresses\n",
            "ProxyAdmin=", vm.toString(proxyAdmin), "\n",
            "UpgradeableNFT_Implementation=", vm.toString(nftImplementation), "\n",
            "UpgradeableNFT_Proxy=", vm.toString(nftProxy), "\n",
            "NFTMarketV1_Implementation=", vm.toString(marketV1Implementation), "\n",
            "NFTMarketV2_Implementation=", vm.toString(marketV2Implementation), "\n",
            "NFTMarket_Proxy=", vm.toString(marketV1Proxy), "\n"
        );
        
        vm.writeFile("nft-market-local-deployment.txt", addresses);
        console.log("\nDeployment addresses saved to: nft-market-local-deployment.txt");
    }
}