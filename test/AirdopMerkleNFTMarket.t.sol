// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";
import "../src/AirdopMerkleNFTMarket/AirdopMerkleNFTMarket.sol";
import "../src/AirdopMerkleNFTMarket/PermitToken.sol";
import "../src/AirdopMerkleNFTMarket/AirdropNFT.sol";
import "../src/AirdopMerkleNFTMarket/MulticallHelper.sol";

contract AirdopMerkleNFTMarketTest is Test {
    AirdopMerkleNFTMarket public market;
    PermitToken public token;
    AirdropNFT public nft;
    MulticallHelper public helper;
    
    address public owner;
    address public seller;
    address public whitelistUser;
    address public normalUser;
    
    // 测试用的Merkle树数据
    bytes32 public merkleRoot;
    bytes32[] public whitelistProof;
    bytes32[] public invalidProof;
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant NFT_PRICE = 100 * 10**18;
    uint256 public tokenId1;
    uint256 public tokenId2;
    
    function setUp() public {
        owner = address(this);
        seller = makeAddr("seller");
        whitelistUser = makeAddr("whitelistUser");
        normalUser = makeAddr("normalUser");
        
        // 部署合约
        token = new PermitToken("Test Token", "TT", INITIAL_SUPPLY);
        nft = new AirdropNFT("Test NFT", "TNFT");
        
        // 构建测试用的Merkle树
        // 白名单：whitelistUser
        // Merkle树：[whitelistUser] -> root
        bytes32 leaf = keccak256(abi.encodePacked(whitelistUser));
        merkleRoot = leaf; // 只有一个叶子节点时，根就是叶子本身
        whitelistProof = new bytes32[](0); // 空证明
        
        // 无效证明
        invalidProof = new bytes32[](1);
        invalidProof[0] = keccak256("invalid");
        
        // 部署市场合约
        market = new AirdopMerkleNFTMarket(address(token), address(nft), merkleRoot);
        helper = new MulticallHelper();
        
        // 设置NFT市场合约地址
        nft.setMarketContract(address(market));
        
        // 铸造NFT给seller
        tokenId1 = nft.mint(seller, "ipfs://test1");
        tokenId2 = nft.mint(seller, "ipfs://test2");
        
        // 给用户分发代币
        token.mint(whitelistUser, 1000 * 10**18);
        token.mint(normalUser, 1000 * 10**18);
        token.mint(seller, 1000 * 10**18);
        
        // seller授权NFT给市场
        vm.startPrank(seller);
        nft.setApprovalForAll(address(market), true);
        vm.stopPrank();
    }
    
    function testDeployment() public {
        assertEq(address(market.token()), address(token));
        assertEq(address(market.nft()), address(nft));
        assertEq(market.merkleRoot(), merkleRoot);
    }
    
    function testListNFT() public {
        vm.startPrank(seller);
        
        market.listNFT(tokenId1, NFT_PRICE);
        
        AirdopMerkleNFTMarket.Listing memory listing = market.getListing(tokenId1);
        assertEq(listing.tokenId, tokenId1);
        assertEq(listing.seller, seller);
        assertEq(listing.price, NFT_PRICE);
        assertTrue(listing.active);
        
        vm.stopPrank();
    }
    
    function testDelistNFT() public {
        vm.startPrank(seller);
        
        market.listNFT(tokenId1, NFT_PRICE);
        market.delistNFT(tokenId1);
        
        AirdopMerkleNFTMarket.Listing memory listing = market.getListing(tokenId1);
        assertFalse(listing.active);
        
        vm.stopPrank();
    }
    
    function testVerifyWhitelist() public {
        // 验证白名单用户
        assertTrue(market.verifyWhitelist(whitelistUser, whitelistProof));
        
        // 验证非白名单用户
        assertFalse(market.verifyWhitelist(normalUser, whitelistProof));
        
        // 验证无效证明
        assertFalse(market.verifyWhitelist(whitelistUser, invalidProof));
    }
    
    function testPermitPrePay() public {
        uint256 amount = NFT_PRICE / 2;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 创建permit签名
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            whitelistUser,
            address(market),
            amount,
            deadline
        );
        
        vm.startPrank(whitelistUser);
        
        // 调用permitPrePay
        market.permitPrePay(
            whitelistUser,
            address(market),
            amount,
            deadline,
            v,
            r,
            s
        );
        
        // 验证授权
        assertEq(token.allowance(whitelistUser, address(market)), amount);
        
        vm.stopPrank();
    }
    
    function testClaimNFTWithWhitelist() public {
        // 上架NFT
        vm.startPrank(seller);
        market.listNFT(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        uint256 discountedPrice = NFT_PRICE / 2;
        
        vm.startPrank(whitelistUser);
        
        // 授权代币
        token.approve(address(market), discountedPrice);
        
        // 白名单用户领取NFT
        market.claimNFT(tokenId1, whitelistProof);
        
        // 验证NFT转移
        assertEq(nft.ownerOf(tokenId1), whitelistUser);
        
        // 验证代币转移
        assertEq(token.balanceOf(seller), 1000 * 10**18 + discountedPrice);
        
        // 验证已领取状态
        assertTrue(market.hasUserClaimed(whitelistUser));
        
        // 验证NFT已下架
        AirdopMerkleNFTMarket.Listing memory listing = market.getListing(tokenId1);
        assertFalse(listing.active);
        
        vm.stopPrank();
    }
    
    function testBuyNFTNormal() public {
        // 上架NFT
        vm.startPrank(seller);
        market.listNFT(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        vm.startPrank(normalUser);
        
        // 授权代币
        token.approve(address(market), NFT_PRICE);
        
        // 普通用户购买NFT
        market.buyNFT(tokenId1);
        
        // 验证NFT转移
        assertEq(nft.ownerOf(tokenId1), normalUser);
        
        // 验证代币转移
        assertEq(token.balanceOf(seller), 1000 * 10**18 + NFT_PRICE);
        
        vm.stopPrank();
    }
    
    function testMulticallPermitAndClaim() public {
        // 上架NFT
        vm.startPrank(seller);
        market.listNFT(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        uint256 amount = NFT_PRICE / 2;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 创建permit签名
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            whitelistUser,
            address(market),
            amount,
            deadline
        );
        
        // 创建multicall数据
        MulticallHelper.PermitData memory permitData = MulticallHelper.PermitData({
            owner: whitelistUser,
            spender: address(market),
            value: amount,
            deadline: deadline,
            v: v,
            r: r,
            s: s
        });
        
        bytes[] memory calls = helper.createPermitAndClaimData(
            permitData,
            tokenId1,
            whitelistProof
        );
        
        vm.startPrank(whitelistUser);
        
        // 执行multicall
        market.multicall(calls);
        
        // 验证结果
        assertEq(nft.ownerOf(tokenId1), whitelistUser);
        assertTrue(market.hasUserClaimed(whitelistUser));
        
        vm.stopPrank();
    }
    
    function test_RevertWhen_ClaimTwice() public {
        // 上架NFT
        vm.startPrank(seller);
        market.listNFT(tokenId1, NFT_PRICE);
        market.listNFT(tokenId2, NFT_PRICE);
        vm.stopPrank();
        
        uint256 discountedPrice = NFT_PRICE / 2;
        
        vm.startPrank(whitelistUser);
        
        // 授权足够的代币
        token.approve(address(market), discountedPrice * 2);
        
        // 第一次领取
        market.claimNFT(tokenId1, whitelistProof);
        
        // 第二次领取应该失败
        vm.expectRevert("Already claimed");
        market.claimNFT(tokenId2, whitelistProof);
        
        vm.stopPrank();
    }
    
    function test_RevertWhen_ClaimWithInvalidProof() public {
        // 上架NFT
        vm.startPrank(seller);
        market.listNFT(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        vm.startPrank(normalUser);
        
        // 使用无效证明应该失败
        vm.expectRevert("Invalid merkle proof");
        market.claimNFT(tokenId1, invalidProof);
        
        vm.stopPrank();
    }
    
    function testGetDiscountedPrice() public {
        vm.startPrank(seller);
        market.listNFT(tokenId1, NFT_PRICE);
        vm.stopPrank();
        
        uint256 discountedPrice = market.getDiscountedPrice(tokenId1);
        assertEq(discountedPrice, NFT_PRICE / 2);
    }
    
    function testUpdateMerkleRoot() public {
        bytes32 newRoot = keccak256("new root");
        
        market.updateMerkleRoot(newRoot);
        
        assertEq(market.merkleRoot(), newRoot);
    }
    
    // 辅助函数：创建permit签名
    function _createPermitSignature(
        address _owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        // 获取对应地址的私钥
        uint256 privateKey;
        if (_owner == whitelistUser) {
            privateKey = uint256(keccak256(abi.encodePacked("whitelistUser")));
        } else if (_owner == normalUser) {
            privateKey = uint256(keccak256(abi.encodePacked("normalUser")));
        } else if (_owner == seller) {
            privateKey = uint256(keccak256(abi.encodePacked("seller")));
        } else {
            privateKey = uint256(keccak256(abi.encodePacked(_owner)));
        }
        
        // 构建permit消息
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                _owner,
                spender,
                value,
                token.nonces(_owner),
                deadline
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                structHash
            )
        );
        
        // 签名
        (v, r, s) = vm.sign(privateKey, digest);
    }
}