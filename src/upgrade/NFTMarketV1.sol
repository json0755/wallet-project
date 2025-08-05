// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title NFTMarketV1
 * @dev NFT市场合约V1版本
 * 提供基础的NFT交易功能：上架、购买、取消上架
 */
contract NFTMarketV1 is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, IERC721Receiver {
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

    // NFT合约地址 => tokenId => Listing信息
    mapping(address => mapping(uint256 => Listing)) public listings;
    
    // 平台手续费率（基点，10000 = 100%）
    uint256 public platformFeeRate;
    
    // 平台手续费接收地址
    address public feeRecipient;

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
     * @dev NFT售出事件
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数
     * @param owner 合约所有者
     * @param _feeRecipient 手续费接收地址
     * @param _platformFeeRate 平台手续费率（基点）
     */
    function initialize(
        address owner,
        address _feeRecipient,
        uint256 _platformFeeRate
    ) public initializer {
        __Ownable_init(owner);
        __ReentrancyGuard_init();
        
        require(_feeRecipient != address(0), "Invalid fee recipient");
        require(_platformFeeRate <= 1000, "Fee rate too high"); // 最大10%
        
        feeRecipient = _feeRecipient;
        platformFeeRate = _platformFeeRate;
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
     * @dev 计算上架手续费
     * @param price 价格
     * @return fee 手续费金额
     */
    function getListingFee(uint256 price) external view returns (uint256 fee) {
        return (price * platformFeeRate) / 10000;
    }

    /**
     * @dev 实现IERC721Receiver接口
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
     * @dev 授权升级函数，只有所有者可以升级合约
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}