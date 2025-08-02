// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MerkleProof.sol";
import "./Multicall.sol";

/**
 * @title AirdopMerkleNFTMarket
 * @dev 基于Merkle树验证的NFT空投市场合约
 */
contract AirdopMerkleNFTMarket is Multicall, ReentrancyGuard, Ownable {
    using MerkleProof for bytes32[];
    
    // 代币和NFT合约
    IERC20Permit public immutable token;
    IERC721 public immutable nft;
    
    // Merkle树根，用于白名单验证
    bytes32 public merkleRoot;
    
    // NFT上架信息
    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
    }
    
    // tokenId => Listing
    mapping(uint256 => Listing) public listings;
    
    // 用户是否已经领取过NFT
    mapping(address => bool) public hasClaimed;
    
    // permit预授权信息
    struct PermitData {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    
    // 临时存储permit数据
    mapping(address => PermitData) private _permitData;
    
    // 事件
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);
    event NFTDelisted(uint256 indexed tokenId, address indexed seller);
    event MerkleRootUpdated(bytes32 newRoot);
    event NFTClaimed(address indexed user, uint256 indexed tokenId, uint256 discountedPrice);
    event PermitPrePaid(address indexed user, uint256 amount);
    
    constructor(
        address _token,
        address _nft,
        bytes32 _merkleRoot
    ) Ownable(msg.sender) {
        token = IERC20Permit(_token);
        nft = IERC721(_nft);
        merkleRoot = _merkleRoot;
    }
    
    /**
     * @dev 更新Merkle根
     * @param _merkleRoot 新的Merkle根
     */
    function updateMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }
    
    /**
     * @dev 上架NFT
     * @param tokenId NFT ID
     * @param price 价格
     */
    function listNFT(uint256 tokenId, uint256 price) external {
        require(nft.ownerOf(tokenId) == msg.sender, "Not NFT owner");
        require(nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)), "NFT not approved");
        require(price > 0, "Price must be greater than 0");
        
        listings[tokenId] = Listing({
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true
        });
        
        emit NFTListed(tokenId, msg.sender, price);
    }
    
    /**
     * @dev 下架NFT
     * @param tokenId NFT ID
     */
    function delistNFT(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.active, "NFT not listed");
        
        listing.active = false;
        
        emit NFTDelisted(tokenId, msg.sender);
    }
    
    /**
     * @dev permit预授权函数
     * @param owner 代币所有者
     * @param spender 被授权者
     * @param value 授权金额
     * @param deadline 截止时间
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     */
    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 调用token的permit函数进行授权
        token.permit(owner, spender, value, deadline, v, r, s);
        
        // 存储permit数据供后续使用
        _permitData[owner] = PermitData({
            owner: owner,
            spender: spender,
            value: value,
            deadline: deadline,
            v: v,
            r: r,
            s: s
        });
        
        emit PermitPrePaid(owner, value);
    }
    
    /**
     * @dev 通过Merkle树验证并购买NFT（白名单用户享受50%折扣）
     * @param tokenId NFT ID
     * @param merkleProof Merkle证明
     */
    function claimNFT(uint256 tokenId, bytes32[] calldata merkleProof) external nonReentrant {
        require(!hasClaimed[msg.sender], "Already claimed");
        
        // 验证Merkle证明
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(merkleProof.verify(merkleRoot, leaf), "Invalid merkle proof");
        
        Listing storage listing = listings[tokenId];
        require(listing.active, "NFT not listed");
        require(nft.ownerOf(tokenId) == listing.seller, "Seller no longer owns NFT");
        
        // 计算折扣价格（50%折扣）
        uint256 discountedPrice = listing.price / 2;
        
        // 检查用户是否有足够的授权额度
        require(IERC20(address(token)).allowance(msg.sender, address(this)) >= discountedPrice, "Insufficient allowance");
        
        // 转移代币
        require(IERC20(address(token)).transferFrom(msg.sender, listing.seller, discountedPrice), "Token transfer failed");
        
        // 转移NFT
        nft.transferFrom(listing.seller, msg.sender, tokenId);
        
        // 标记为已领取
        hasClaimed[msg.sender] = true;
        
        // 下架NFT
        listing.active = false;
        
        emit NFTClaimed(msg.sender, tokenId, discountedPrice);
        emit NFTSold(tokenId, msg.sender, listing.seller, discountedPrice);
    }
    
    /**
     * @dev 普通购买NFT（非白名单用户）
     * @param tokenId NFT ID
     */
    function buyNFT(uint256 tokenId) external nonReentrant {
        Listing storage listing = listings[tokenId];
        require(listing.active, "NFT not listed");
        require(nft.ownerOf(tokenId) == listing.seller, "Seller no longer owns NFT");
        
        // 检查用户是否有足够的授权额度
        require(IERC20(address(token)).allowance(msg.sender, address(this)) >= listing.price, "Insufficient allowance");
        
        // 转移代币
        require(IERC20(address(token)).transferFrom(msg.sender, listing.seller, listing.price), "Token transfer failed");
        
        // 转移NFT
        nft.transferFrom(listing.seller, msg.sender, tokenId);
        
        // 下架NFT
        listing.active = false;
        
        emit NFTSold(tokenId, msg.sender, listing.seller, listing.price);
    }
    
    /**
     * @dev 验证用户是否在白名单中
     * @param user 用户地址
     * @param merkleProof Merkle证明
     * @return 是否在白名单中
     */
    function verifyWhitelist(address user, bytes32[] calldata merkleProof) external view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        return merkleProof.verify(merkleRoot, leaf);
    }
    
    /**
     * @dev 获取NFT上架信息
     * @param tokenId NFT ID
     * @return listing 上架信息
     */
    function getListing(uint256 tokenId) external view returns (Listing memory) {
        return listings[tokenId];
    }
    
    /**
     * @dev 获取白名单用户的折扣价格
     * @param tokenId NFT ID
     * @return 折扣价格
     */
    function getDiscountedPrice(uint256 tokenId) external view returns (uint256) {
        return listings[tokenId].price / 2;
    }
    
    /**
     * @dev 检查用户是否已经领取过NFT
     * @param user 用户地址
     * @return 是否已领取
     */
    function hasUserClaimed(address user) external view returns (bool) {
        return hasClaimed[user];
    }
}