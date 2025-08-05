// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/upgrade/UpgradeableNFT.sol";
import "../src/upgrade/NFTMarketV1.sol";
import "../src/upgrade/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title NFTMarketTest
 * @dev NFT市场合约测试用例
 * 测试V1基础功能、代理升级流程和V2签名功能
 */
contract NFTMarketTest is Test {
    // 合约实例
    UpgradeableNFT public nft;
    NFTMarketV1 public marketV1;
    NFTMarketV2 public marketV2;
    ERC1967Proxy public marketProxy;
    ERC1967Proxy public nftProxy;
    
    // 测试账户
    address public owner;
    address public seller;
    address public buyer = address(0x3);
    address public user;
    
    // 测试用私钥（用于签名测试）
    uint256 public sellerPrivateKey = 0x2;
    uint256 public userPrivateKey = 0x4;
    
    // 测试常量
    uint256 public constant TOKEN_ID = 1;
    uint256 public constant PRICE = 1 ether;
    uint256 public constant FEE_RATE = 250; // 2.5%
    
    function setUp() public {
        // 设置owner为测试地址
        owner = address(0x1234);
        
        // 根据私钥计算地址
        seller = vm.addr(sellerPrivateKey);
        user = vm.addr(userPrivateKey);
        
        // 设置测试账户余额
        vm.deal(owner, 100 ether);
        vm.deal(seller, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.deal(user, 100 ether);
        
        vm.startPrank(owner);
        
        // 部署NFT实现合约
        UpgradeableNFT nftImpl = new UpgradeableNFT();
        
        // 部署NFT代理合约
        bytes memory nftInitData = abi.encodeWithSelector(
            UpgradeableNFT.initialize.selector,
            "Test NFT",
            "TNFT",
            owner
        );
        
        nftProxy = new ERC1967Proxy(
            address(nftImpl),
            nftInitData
        );
        
        nft = UpgradeableNFT(address(nftProxy));
        
        // 部署市场V1实现合约
        NFTMarketV1 marketV1Impl = new NFTMarketV1();
        
        // 部署市场代理合约
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector,
            owner,
            owner,
            FEE_RATE
        );
        
        marketProxy = new ERC1967Proxy(
            address(marketV1Impl),
            marketInitData
        );
        
        marketV1 = NFTMarketV1(address(marketProxy));
        
        // 铸造测试NFT
        nft.mint(seller, TOKEN_ID);
        
        vm.stopPrank();
        
        // 设置NFT授权
        vm.prank(seller);
        nft.setApprovalForAll(address(marketV1), true);
    }
    
    /**
     * @dev 测试V1基础功能 - 上架NFT
     */
    function testListNFT() public {
        vm.prank(seller);
        marketV1.listNFT(address(nft), TOKEN_ID, PRICE);
        
        (uint256 tokenId, uint256 price, address sellerAddr, bool isActive) = 
            marketV1.listings(address(nft), TOKEN_ID);
            
        assertEq(tokenId, TOKEN_ID);
        assertEq(price, PRICE);
        assertEq(sellerAddr, seller);
        assertTrue(isActive);
        
        console.log("[SUCCESS] NFT listed successfully");
    }
    
    /**
     * @dev 测试V1基础功能 - 购买NFT
     */
    function testBuyNFT() public {
        // 先上架
        vm.prank(seller);
        marketV1.listNFT(address(nft), TOKEN_ID, PRICE);
        
        // 记录购买前余额
        uint256 sellerBalanceBefore = seller.balance;
        uint256 ownerBalanceBefore = owner.balance;
        
        // 购买NFT
        vm.prank(buyer);
        marketV1.buyNFT{value: PRICE}(address(nft), TOKEN_ID);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(TOKEN_ID), buyer);
        
        // 验证上架状态
        (, , , bool isActive) = marketV1.listings(address(nft), TOKEN_ID);
        assertFalse(isActive);
        
        // 验证费用分配
        uint256 fee = (PRICE * FEE_RATE) / 10000;
        uint256 sellerAmount = PRICE - fee;
        
        assertEq(seller.balance, sellerBalanceBefore + sellerAmount);
        assertEq(owner.balance, ownerBalanceBefore + fee);
        
        console.log("[SUCCESS] NFT purchased successfully");
        console.log("  Seller received:", sellerAmount);
        console.log("  Platform fee:", fee);
    }
    
    /**
     * @dev 测试V1基础功能 - 取消上架
     */
    function testCancelListing() public {
        // 先上架
        vm.prank(seller);
        marketV1.listNFT(address(nft), TOKEN_ID, PRICE);
        
        // 取消上架
        vm.prank(seller);
        marketV1.cancelListing(address(nft), TOKEN_ID);
        
        // 验证上架状态
        (, , , bool isActive) = marketV1.listings(address(nft), TOKEN_ID);
        assertFalse(isActive);
        
        console.log("[SUCCESS] Listing cancelled successfully");
    }
    
    /**
     * @dev 测试代理升级到V2
     */
    function testUpgradeToV2() public {
        // 先在V1中上架一个NFT
        vm.prank(seller);
        marketV1.listNFT(address(nft), TOKEN_ID, PRICE);
        
        // 验证V1状态
        (, uint256 priceBefore, address sellerBefore, bool isActiveBefore) = 
            marketV1.listings(address(nft), TOKEN_ID);
        assertTrue(isActiveBefore);
        
        vm.startPrank(owner);
        
        // 部署V2实现合约
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        
        // 使用UUPS升级代理合约
        marketV1.upgradeToAndCall(
            address(marketV2Impl),
            abi.encodeWithSelector(NFTMarketV2.initializeV2.selector)
        );
        
        vm.stopPrank();
        
        // 创建V2接口实例
        marketV2 = NFTMarketV2(address(marketProxy));
        
        // 验证升级后状态保持一致
        (, uint256 priceAfter, address sellerAfter, bool isActiveAfter) = 
            marketV2.listings(address(nft), TOKEN_ID);
            
        assertEq(priceAfter, priceBefore);
        assertEq(sellerAfter, sellerBefore);
        assertEq(isActiveAfter, isActiveBefore);
        
        // 验证V2新功能可用
        assertEq(marketV2.getNonce(seller), 0);
        assertTrue(marketV2.DOMAIN_SEPARATOR() != bytes32(0));
        
        console.log("[SUCCESS] Successfully upgraded to V2");
        console.log("[SUCCESS] Previous listings preserved");
        console.log("[SUCCESS] V2 features available");
    }
    
    /**
     * @dev 测试V2签名上架功能
     */
    function testPermitListNFT() public {
        // 先升级到V2
        testUpgradeToV2();
        
        // 铸造新的NFT用于签名测试
        uint256 newTokenId = 2;
        vm.prank(owner);
        nft.mint(user, newTokenId);
        
        // 设置授权
        vm.prank(user);
        nft.setApprovalForAll(address(marketV2), true);
        
        // 准备签名参数
        uint256 nonce = marketV2.getNonce(user);
        uint256 deadline = block.timestamp + 1 hours;
        
        NFTMarketV2.ListingParams memory params = NFTMarketV2.ListingParams({
            tokenId: newTokenId,
            price: PRICE,
            nonce: nonce,
            deadline: deadline
        });
        
        // 生成签名
        bytes32 messageHash = marketV2.getMessageHash(address(nft), params);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // 执行签名上架
        vm.prank(buyer); // 任何人都可以代为执行签名上架
        marketV2.permitListNFT(address(nft), params, signature);
        
        // 验证上架成功
        (uint256 tokenId, uint256 price, address sellerAddr, bool isActive) = 
            marketV2.listings(address(nft), newTokenId);
            
        assertEq(tokenId, newTokenId);
        assertEq(price, PRICE);
        assertEq(sellerAddr, user);
        assertTrue(isActive);
        
        // 验证nonce增加
        assertEq(marketV2.getNonce(user), nonce + 1);
        
        console.log("[SUCCESS] Permit listing successful");
        console.log("  Token ID:", newTokenId);
        console.log("  Price:", price);
        console.log("  Seller:", sellerAddr);
        console.log("  New nonce:", marketV2.getNonce(user));
    }
    
    /**
     * @dev 测试签名过期
     */
    function testPermitListNFTExpired() public {
        // 先升级到V2
        testUpgradeToV2();
        
        // 铸造新的NFT
        uint256 newTokenId = 3;
        vm.prank(owner);
        nft.mint(user, newTokenId);
        
        vm.prank(user);
        nft.setApprovalForAll(address(marketV2), true);
        
        // 准备过期的签名参数
        uint256 nonce = marketV2.getNonce(user);
        uint256 deadline = block.timestamp - 1; // 已过期
        
        NFTMarketV2.ListingParams memory params = NFTMarketV2.ListingParams({
            tokenId: newTokenId,
            price: PRICE,
            nonce: nonce,
            deadline: deadline
        });
        
        // 生成签名
        bytes32 messageHash = marketV2.getMessageHash(address(nft), params);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // 应该失败
        vm.expectRevert("Signature expired");
        marketV2.permitListNFT(address(nft), params, signature);
        
        console.log("[SUCCESS] Expired signature correctly rejected");
    }
    
    /**
     * @dev 测试无效nonce
     */
    function testPermitListNFTInvalidNonce() public {
        // 先升级到V2
        testUpgradeToV2();
        
        // 铸造新的NFT
        uint256 newTokenId = 4;
        vm.prank(owner);
        nft.mint(user, newTokenId);
        
        vm.prank(user);
        nft.setApprovalForAll(address(marketV2), true);
        
        // 准备错误nonce的签名参数
        uint256 wrongNonce = marketV2.getNonce(user) + 1; // 错误的nonce
        uint256 deadline = block.timestamp + 1 hours;
        
        NFTMarketV2.ListingParams memory params = NFTMarketV2.ListingParams({
            tokenId: newTokenId,
            price: PRICE,
            nonce: wrongNonce,
            deadline: deadline
        });
        
        // 生成签名
        bytes32 messageHash = marketV2.getMessageHash(address(nft), params);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // 应该失败
        vm.expectRevert("Invalid nonce");
        marketV2.permitListNFT(address(nft), params, signature);
        
        console.log("[SUCCESS] Invalid nonce correctly rejected");
    }
    
    /**
     * @dev 测试批量取消过期上架（仅所有者）
     */
    function testBatchCancelExpiredListings() public {
        // 先升级到V2
        testUpgradeToV2();
        
        // 铸造多个NFT并上架
        uint256[] memory tokenIds = new uint256[](3);
        address[] memory nftContracts = new address[](3);
        
        for (uint256 i = 0; i < 3; i++) {
            tokenIds[i] = 10 + i;
            nftContracts[i] = address(nft);
            
            vm.prank(owner);
            nft.mint(seller, tokenIds[i]);
            
            vm.prank(seller);
            marketV2.listNFT(address(nft), tokenIds[i], PRICE);
        }
        
        // 批量取消
        vm.prank(owner);
        marketV2.batchCancelExpiredListings(nftContracts, tokenIds);
        
        // 验证所有上架都被取消
        for (uint256 i = 0; i < 3; i++) {
            (, , , bool isActive) = marketV2.listings(address(nft), tokenIds[i]);
            assertFalse(isActive);
        }
        
        console.log("[SUCCESS] Batch cancel expired listings successful");
    }
    
    /**
     * @dev 测试获取费用计算
     */
    function testGetListingFee() public {
        uint256 fee = marketV1.getListingFee(PRICE);
        uint256 expectedFee = (PRICE * FEE_RATE) / 10000;
        
        assertEq(fee, expectedFee);
        
        console.log("[SUCCESS] Fee calculation correct");
        console.log("  Price:", PRICE);
        console.log("  Fee:", fee);
        console.log("  Fee rate:", FEE_RATE, "basis points");
    }
}