// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";
import "../src/AirdopMerkleNFTMarket/AirdopMerkleNFTMarket.sol";
import "../src/AirdopMerkleNFTMarket/PermitToken.sol";
import "../src/AirdopMerkleNFTMarket/AirdropNFT.sol";
import "../src/AirdopMerkleNFTMarket/MulticallHelper.sol";

contract DeployAirdopMerkleNFTMarket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署PermitToken
        PermitToken token = new PermitToken(
            "Airdrop Token",
            "ADT",
            1000000 * 10**18 // 1M tokens
        );
        console.log("PermitToken deployed at:", address(token));
        
        // 2. 部署AirdropNFT
        AirdropNFT nft = new AirdropNFT(
            "Airdrop NFT",
            "ANFT"
        );
        console.log("AirdropNFT deployed at:", address(nft));
        
        // 3. 创建测试用的Merkle根
        // 这里使用一个示例地址作为白名单
        address whitelistUser = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        bytes32 merkleRoot = keccak256(abi.encodePacked(whitelistUser));
        console.log("Merkle root:");
        console.logBytes32(merkleRoot);
        console.log("Whitelist user:", whitelistUser);
        
        // 4. 部署AirdopMerkleNFTMarket
        AirdopMerkleNFTMarket market = new AirdopMerkleNFTMarket(
            address(token),
            address(nft),
            merkleRoot
        );
        console.log("AirdopMerkleNFTMarket deployed at:", address(market));
        
        // 5. 部署MulticallHelper
        MulticallHelper helper = new MulticallHelper();
        console.log("MulticallHelper deployed at:", address(helper));
        
        // 6. 设置NFT市场合约
        nft.setMarketContract(address(market));
        console.log("NFT market contract set");
        
        // 7. 铸造一些测试NFT
        uint256 tokenId1 = nft.mint(deployer, "ipfs://QmTest1");
        uint256 tokenId2 = nft.mint(deployer, "ipfs://QmTest2");
        console.log("Minted NFT tokenId1:", tokenId1);
        console.log("Minted NFT tokenId2:", tokenId2);
        
        // 8. 给白名单用户分发代币
        token.mint(whitelistUser, 1000 * 10**18);
        console.log("Minted 1000 tokens to whitelist user:", whitelistUser);
        
        // 9. 授权NFT给市场
        nft.setApprovalForAll(address(market), true);
        console.log("Approved NFTs to market");
        
        // 10. 上架NFT
        uint256 nftPrice = 100 * 10**18; // 100 tokens
        market.listNFT(tokenId1, nftPrice);
        market.listNFT(tokenId2, nftPrice);
        console.log("Listed NFTs with price:", nftPrice);
        
        // 11. 显示折扣价格
        uint256 discountedPrice = market.getDiscountedPrice(tokenId1);
        console.log("Discounted price for whitelist users:", discountedPrice);
        
        vm.stopBroadcast();
        
        // 12. 显示部署总结
        console.log("\n=== Deployment Summary ===");
        console.log("PermitToken:", address(token));
        console.log("AirdropNFT:", address(nft));
        console.log("AirdopMerkleNFTMarket:", address(market));
        console.log("MulticallHelper:", address(helper));
        console.log("Deployer:", deployer);
        console.log("Whitelist User:", whitelistUser);
        console.log("NFT Price:", nftPrice);
        console.log("Discounted Price:", discountedPrice);
        
        console.log("\n=== Next Steps ===");
        console.log("1. Whitelist user can use multicall to permit + claimNFT");
        console.log("2. Normal users can buyNFT at full price");
        console.log("3. Use MulticallHelper to create batch transaction data");
    }
    
    // 辅助函数：演示如何创建multicall数据
    function demonstrateMulticall() external {
        // 这个函数展示如何使用MulticallHelper创建批量调用数据
        console.log("\n=== Multicall Demo ===");
        
        // 示例参数
        address owner = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        address spender = address(0x123); // 市场合约地址
        uint256 value = 50 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 tokenId = 1;
        bytes32[] memory proof = new bytes32[](0);
        
        MulticallHelper helper = new MulticallHelper();
        
        // 创建permit数据
        MulticallHelper.PermitData memory permitData = MulticallHelper.PermitData({
            owner: owner,
            spender: spender,
            value: value,
            deadline: deadline,
            v: 27, // 示例签名
            r: bytes32(0),
            s: bytes32(0)
        });
        
        // 创建批量调用数据
        bytes[] memory calls = helper.createPermitAndClaimData(permitData, tokenId, proof);
        
        console.log("Created multicall data with", calls.length, "calls");
        console.log("Call 1 (permitPrePay) length:", calls[0].length);
        console.log("Call 2 (claimNFT) length:", calls[1].length);
    }
}