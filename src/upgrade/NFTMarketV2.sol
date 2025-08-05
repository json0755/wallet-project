// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title NFTMarketV2
 * @dev NFT市场合约V2版本
 * 在V1基础上添加了签名验证功能，支持离线签名上架
 */
contract NFTMarketV2 is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, IERC721Receiver {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /**
     * @dev NFT上架信息结构体
     * @param tokenId NFT代币ID
     * @param price 价格（以wei为单位）
     * @param seller 卖家地址
     * @param isActive 是否活跃状态
     */
    struct Listing {
        uint256 tokenId;
        uint256 price;
        address seller;
        bool isActive;
    }

    /**
     * @dev 签名上架参数结构体
     * @param tokenId NFT代币ID
     * @param price 价格
     * @param nonce 防重放攻击的随机数
     * @param deadline 签名过期时间
     */
    struct ListingParams {
        uint256 tokenId;
        uint256 price;
        uint256 nonce;
        uint256 deadline;
    }

    // NFT合约地址 => tokenId => Listing信息
    mapping(address => mapping(uint256 => Listing)) public listings;
    
    // 平台手续费率（基点，10000 = 100%）
    uint256 public platformFeeRate;
    
    // 平台手续费接收地址
    address public feeRecipient;
    
    // 用户nonce映射，防止重放攻击
    mapping(address => uint256) public nonces;
    
    // 域分隔符，用于EIP-712签名
    bytes32 public DOMAIN_SEPARATOR;
    
    // ListingParams类型哈希（包含NFT合约地址）
    bytes32 public constant LISTING_PARAMS_TYPEHASH = keccak256(
        "ListingParams(address nftContract,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)"
    );

    /**
     * @dev NFT上架事件
     * @param nftContract NFT合约地址
     * @param tokenId 代币ID
     * @param price 价格
     * @param seller 卖家地址
     */
    event NFTListed(
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price,
        address indexed seller
    );

    /**
     * @dev NFT购买事件
     * @param nftContract NFT合约地址
     * @param tokenId 代币ID
     * @param price 价格
     * @param seller 卖家地址
     * @param buyer 买家地址
     */
    event NFTSold(
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price,
        address indexed seller,
        address buyer
    );

    /**
     * @dev 上架取消事件
     * @param nftContract NFT合约地址
     * @param tokenId 代币ID
     * @param seller 卖家地址
     */
    event ListingCancelled(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller
    );

    /**
     * @dev 签名上架事件
     * @param nftContract NFT合约地址
     * @param tokenId 代币ID
     * @param price 价格
     * @param seller 卖家地址
     * @param nonce 使用的nonce
     */
    event NFTListedWithSignature(
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price,
        address indexed seller,
        uint256 nonce
    );

    /**
     * @dev 初始化函数（部署时调用）
     * @param _platformFeeRate 平台手续费率（基点）
     * @param _feeRecipient 手续费接收地址
     */
    function initialize(
        uint256 _platformFeeRate,
        address _feeRecipient
    ) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        
        require(_platformFeeRate <= 1000, "Fee rate too high"); // 最大10%
        require(_feeRecipient != address(0), "Invalid fee recipient");
        
        platformFeeRate = _platformFeeRate;
        feeRecipient = _feeRecipient;
        
        // 设置EIP-712域分隔符
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("NFTMarketV2")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    /**
      * @dev 初始化V2版本（升级时调用）
      */
     function initializeV2() public reinitializer(2) {
         // 设置EIP-712域分隔符
         DOMAIN_SEPARATOR = keccak256(
             abi.encode(
                 keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                 keccak256(bytes("NFTMarketV2")),
                 keccak256(bytes("1")),
                 block.chainid,
                 address(this)
             )
         );
     }

     /**
      * @dev 上架NFT
      * @param nftContract NFT合约地址
      * @param tokenId 代币ID
      * @param price 价格
      */
     function listNFT(
         address nftContract,
         uint256 tokenId,
         uint256 price
     ) external {
         require(price > 0, "Price must be greater than 0");
         require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not token owner");
         require(
             IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) ||
             IERC721(nftContract).getApproved(tokenId) == address(this),
             "Contract not approved"
         );
         require(!listings[nftContract][tokenId].isActive, "Already listed");

         listings[nftContract][tokenId] = Listing({
             tokenId: tokenId,
             price: price,
             seller: msg.sender,
             isActive: true
         });

         emit NFTListed(nftContract, tokenId, price, msg.sender);
     }

     /**
      * @dev 购买NFT
      * @param nftContract NFT合约地址
      * @param tokenId 代币ID
      */
     function buyNFT(address nftContract, uint256 tokenId) external payable nonReentrant {
         Listing storage listing = listings[nftContract][tokenId];
         require(listing.isActive, "Not listed");
         require(msg.value >= listing.price, "Insufficient payment");
         require(msg.sender != listing.seller, "Cannot buy own NFT");

         address seller = listing.seller;
         uint256 price = listing.price;
         
         // 标记为非活跃状态
         listing.isActive = false;

         // 计算手续费
         uint256 platformFee = (price * platformFeeRate) / 10000;
         uint256 sellerAmount = price - platformFee;

         // 转移NFT
         IERC721(nftContract).safeTransferFrom(seller, msg.sender, tokenId);

         // 转移资金
         if (platformFee > 0) {
             payable(feeRecipient).transfer(platformFee);
         }
         payable(seller).transfer(sellerAmount);

         // 退还多余的ETH
         if (msg.value > price) {
             payable(msg.sender).transfer(msg.value - price);
         }

         emit NFTSold(nftContract, tokenId, price, seller, msg.sender);
     }

     /**
      * @dev 取消上架
      * @param nftContract NFT合约地址
      * @param tokenId 代币ID
      */
     function cancelListing(address nftContract, uint256 tokenId) external {
         Listing storage listing = listings[nftContract][tokenId];
         require(listing.isActive, "Not listed");
         require(listing.seller == msg.sender, "Not seller");

         listing.isActive = false;

         emit ListingCancelled(nftContract, tokenId, msg.sender);
     }

     /**
      * @dev 获取上架信息
      * @param nftContract NFT合约地址
      * @param tokenId 代币ID
      * @return listing 上架信息
      */
     function getListing(address nftContract, uint256 tokenId) 
         external 
         view 
         returns (Listing memory listing) 
     {
         return listings[nftContract][tokenId];
     }

     /**
      * @dev 设置平台手续费率（仅所有者）
      * @param _platformFeeRate 新的手续费率
      */
     function setPlatformFeeRate(uint256 _platformFeeRate) external onlyOwner {
         require(_platformFeeRate <= 1000, "Fee rate too high"); // 最大10%
         platformFeeRate = _platformFeeRate;
     }

     /**
      * @dev 设置手续费接收地址（仅所有者）
      * @param _feeRecipient 新的手续费接收地址
      */
     function setFeeRecipient(address _feeRecipient) external onlyOwner {
         require(_feeRecipient != address(0), "Invalid fee recipient");
         feeRecipient = _feeRecipient;
     }

    /**
     * @dev 通过签名上架NFT
     * @param nftContract NFT合约地址
     * @param params 上架参数
     * @param signature 签名数据
     */
    function permitListNFT(
        address nftContract,
        ListingParams calldata params,
        bytes calldata signature
    ) external {
        require(block.timestamp <= params.deadline, "Signature expired");
        require(params.price > 0, "Price must be greater than 0");
        require(!listings[nftContract][params.tokenId].isActive, "Already listed");

        // 验证签名
        address signer = _verifySignature(nftContract, params, signature);
        require(IERC721(nftContract).ownerOf(params.tokenId) == signer, "Signer not token owner");
        
        // 完整的授权验证：检查全局授权或特定代币授权
        IERC721 nft = IERC721(nftContract);
        require(
            nft.isApprovedForAll(signer, address(this)) ||
            nft.getApproved(params.tokenId) == address(this),
            "Contract not approved to transfer this NFT"
        );
        
        require(nonces[signer] == params.nonce, "Invalid nonce");

        // 增加nonce
        nonces[signer]++;

        // 创建上架信息
        listings[nftContract][params.tokenId] = Listing({
            tokenId: params.tokenId,
            price: params.price,
            seller: signer,
            isActive: true
        });

        emit NFTListed(nftContract, params.tokenId, params.price, signer);
        emit NFTListedWithSignature(nftContract, params.tokenId, params.price, signer, params.nonce);
    }

    /**
     * @dev 验证签名
     * @param nftContract NFT合约地址
     * @param params 上架参数
     * @param signature 签名数据
     * @return signer 签名者地址
     */
    function _verifySignature(
        address nftContract,
        ListingParams calldata params,
        bytes calldata signature
    ) internal view returns (address signer) {
        // 构建结构化数据哈希（包含NFT合约地址）
        bytes32 structHash = keccak256(
            abi.encode(
                LISTING_PARAMS_TYPEHASH,
                nftContract,
                params.tokenId,
                params.price,
                params.nonce,
                params.deadline
            )
        );

        // 构建完整的消息哈希
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                structHash
            )
        );

        // 恢复签名者地址
        signer = messageHash.recover(signature);
        require(signer != address(0), "Invalid signature");
        
        return signer;
    }

    /**
     * @dev 获取用户当前nonce
     * @param user 用户地址
     * @return 当前nonce值
     */
    function getNonce(address user) external view returns (uint256) {
        return nonces[user];
    }

    /**
     * @dev 获取签名消息哈希（用于前端生成签名）
     * @param nftContract NFT合约地址
     * @param params 上架参数
     * @return messageHash 消息哈希
     */
    function getMessageHash(
        address nftContract,
        ListingParams calldata params
    ) external view returns (bytes32 messageHash) {
        bytes32 structHash = keccak256(
            abi.encode(
                LISTING_PARAMS_TYPEHASH,
                nftContract,
                params.tokenId,
                params.price,
                params.nonce,
                params.deadline
            )
        );

        messageHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                structHash
            )
        );
        
        return messageHash;
    }

    /**
     * @dev 批量取消过期的上架（仅所有者）
     * @param nftContracts NFT合约地址数组
     * @param tokenIds 代币ID数组
     */
    function batchCancelExpiredListings(
        address[] calldata nftContracts,
        uint256[] calldata tokenIds
    ) external onlyOwner {
        require(nftContracts.length == tokenIds.length, "Array length mismatch");
        
        for (uint256 i = 0; i < nftContracts.length; i++) {
            Listing storage listing = listings[nftContracts[i]][tokenIds[i]];
            if (listing.isActive) {
                listing.isActive = false;
                emit ListingCancelled(nftContracts[i], tokenIds[i], listing.seller);
            }
        }
    }

    /**
     * @dev 接收ERC721代币
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @dev 授权升级函数（仅所有者）
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}