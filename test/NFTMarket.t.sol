// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFTMarket.sol";
import "../src/BaseERC20.sol";
import "../src/BaseERC721.sol";

contract NFTMarketTest is Test {
    NFTMarket public market;
    BaseERC20 public token;
    BaseERC721 public nft;
    
    address public seller = address(0x1);
    address public buyer = address(0x2);
    address public owner = address(this);
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant NFT_PRICE = 100 * 10**18;
    uint256 public constant TOKEN_ID = 1;
    
    function setUp() public {
        // 部署合约
        token = new BaseERC20(INITIAL_SUPPLY);
        nft = new BaseERC721("TestNFT", "TNFT", "https://test.com/");
        market = new NFTMarket(address(token));
        
        // 给seller和buyer分配代币
        token.transfer(seller, 500000 * 10**18);
        token.transfer(buyer, 500000 * 10**18);
        
        // 给seller铸造NFT
        vm.prank(seller);
        nft.mint(seller, TOKEN_ID);
        
        // seller授权market合约操作NFT
        vm.prank(seller);
        nft.approve(address(market), TOKEN_ID);
        
        // buyer授权market合约使用代币
        vm.prank(buyer);
        token.approve(address(market), type(uint256).max);
    }
    
    function test_Constructor() public {
        // 测试构造函数gas消耗
        NFTMarket newMarket = new NFTMarket(address(token));
        assertEq(address(newMarket.paymentToken()), address(token));
    }
    
    function test_List() public {
        // 测试上架NFT的gas消耗
        vm.prank(seller);
        market.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        // 验证上架信息
        (address listSeller, address nftAddress, uint256 tokenId, uint256 price, bool active) = 
            market.listings(address(nft), TOKEN_ID);
        
        assertEq(listSeller, seller);
        assertEq(nftAddress, address(nft));
        assertEq(tokenId, TOKEN_ID);
        assertEq(price, NFT_PRICE);
        assertTrue(active);
    }
    
    function test_ListRevertInvalidPrice() public {
        // 测试价格为0时的revert
        vm.prank(seller);
        vm.expectRevert("The price must be greater than 0");
        market.list(address(nft), TOKEN_ID, 0);
    }
    
    function test_ListRevertNotOwner() public {
        // 测试非持有者上架时的revert
        vm.prank(buyer);
        vm.expectRevert("You are not an NFT holder");
        market.list(address(nft), TOKEN_ID, NFT_PRICE);
    }
    
    function test_ListRevertNotApproved() public {
        // 先取消授权
        vm.prank(seller);
        nft.approve(address(0), TOKEN_ID);
        
        // 测试未授权时的revert
        vm.prank(seller);
        vm.expectRevert("The contract is not authorized to transfer the NFT");
        market.list(address(nft), TOKEN_ID, NFT_PRICE);
    }
    
    function test_BuyNFT() public {
        // 先上架NFT
        vm.prank(seller);
        market.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        // 记录购买前的余额
        uint256 buyerTokenBalanceBefore = token.balanceOf(buyer);
        uint256 sellerTokenBalanceBefore = token.balanceOf(seller);
        
        // 测试购买NFT的gas消耗
        vm.prank(buyer);
        market.buyNFT(address(nft), TOKEN_ID);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(TOKEN_ID), buyer);
        
        // 验证代币转移
        assertEq(token.balanceOf(buyer), buyerTokenBalanceBefore - NFT_PRICE);
        assertEq(token.balanceOf(seller), sellerTokenBalanceBefore + NFT_PRICE);
        
        // 验证listing状态
        (, , , , bool active) = market.listings(address(nft), TOKEN_ID);
        assertFalse(active);
    }
    
    function test_BuyNFTRevertNotActive() public {
        // 测试购买未上架NFT时的revert
        vm.prank(buyer);
        vm.expectRevert("NFT not available");
        market.buyNFT(address(nft), TOKEN_ID);
    }
    
    function test_BuyNFTRevertInsufficientAllowance() public {
        // 先上架NFT
        vm.prank(seller);
        market.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        // 取消授权
        vm.prank(buyer);
        token.approve(address(market), 0);
        
        // 测试授权不足时的revert
        vm.prank(buyer);
        vm.expectRevert("Token authorization is insufficient");
        market.buyNFT(address(nft), TOKEN_ID);
    }
    
    function test_TokensReceivedWithData() public {
        // 先上架NFT
        vm.prank(seller);
        market.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        // 准备data参数（nft地址 + tokenId），使用abi.encode确保每个参数32字节
        bytes memory data = abi.encode(address(nft), TOKEN_ID);
        
        // 记录购买前的余额
        uint256 buyerTokenBalanceBefore = token.balanceOf(buyer);
        uint256 sellerTokenBalanceBefore = token.balanceOf(seller);
        
        // 模拟buyer已经把token转给了market合约
        vm.prank(buyer);
        token.transfer(address(market), NFT_PRICE);
        
        // 直接调用tokensReceived（模拟token合约的回调）
        vm.prank(address(token));
        market.tokensReceived(buyer, NFT_PRICE, data);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(TOKEN_ID), buyer);
        
        // 验证listing状态
        (, , , , bool active) = market.listings(address(nft), TOKEN_ID);
        assertFalse(active);
    }
    
    function test_TokensReceivedRevertWrongSender() public {
        bytes memory data = abi.encode(address(nft), TOKEN_ID);
        
        // 测试非指定token合约调用时的revert
        vm.expectRevert("Only callbacks for specified tokens are accepted");
        market.tokensReceived(buyer, NFT_PRICE, data);
    }
    
    function test_TokensReceivedRevertWrongDataLength() public {
        // 先上架NFT
        vm.prank(seller);
        market.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        // 错误的data长度
        bytes memory wrongData = abi.encodePacked(address(nft));
        
        vm.prank(address(token));
        vm.expectRevert("Data parameter format error");
        market.tokensReceived(buyer, NFT_PRICE, wrongData);
    }
    
    function test_TokensReceivedRevertWrongAmount() public {
        // 先上架NFT
        vm.prank(seller);
        market.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        bytes memory data = abi.encode(address(nft), TOKEN_ID);
        
        vm.prank(address(token));
        vm.expectRevert("Payment amount does not match");
        market.tokensReceived(buyer, NFT_PRICE + 1, data);
    }
    
    function test_TokensReceivedTwoParamsRevert() public {
        // 测试两参数版本的tokensReceived
        vm.expectRevert("Use tokensReceived(address,uint256,bytes) only");
        market.tokensReceived(buyer, NFT_PRICE);
    }
    
    // Gas基准测试
    function test_GasBenchmark_List() public {
        vm.prank(seller);
        uint256 gasBefore = gasleft();
        market.list(address(nft), TOKEN_ID, NFT_PRICE);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for list()", gasUsed);
    }
    
    function test_GasBenchmark_BuyNFT() public {
        // 先上架
        vm.prank(seller);
        market.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        vm.prank(buyer);
        uint256 gasBefore = gasleft();
        market.buyNFT(address(nft), TOKEN_ID);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for buyNFT()", gasUsed);
    }
    
    function test_GasBenchmark_TokensReceived() public {
        // 先上架
        vm.prank(seller);
        market.list(address(nft), TOKEN_ID, NFT_PRICE);
        
        bytes memory data = abi.encode(address(nft), TOKEN_ID);
        
        // 模拟buyer已经把token转给了market合约
        vm.prank(buyer);
        token.transfer(address(market), NFT_PRICE);
        
        vm.prank(address(token));
        uint256 gasBefore = gasleft();
        market.tokensReceived(buyer, NFT_PRICE, data);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for tokensReceived()", gasUsed);
    }
}