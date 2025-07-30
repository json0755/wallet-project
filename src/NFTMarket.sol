// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseERC20.sol"; // 导入自定义ERC20扩展Token接口
import "./BaseERC721.sol"; // 导入NFT合约接口

//forge test --gas-report --optimize --optimizer-runs 200
//使用 --optimize 参数开启 Solidity 优化器，以获取更接近生产环境的 gas 消耗
// NFTMarket 合约，支持用自定义ERC20扩展Token买卖NFT
contract NFTMarket is ITokenReceiver {
    // 记录NFT的上架信息
    struct Listing {
        address seller; // 卖家地址
        address nftAddress; // NFT合约地址
        uint256 tokenId; // NFT的ID
        uint256 price; // 售价（多少个Token）
        bool active; // 是否仍在售卖
    }

    // NFT唯一标识（nft合约+tokenId）到上架信息的映射
    mapping(address => mapping(uint256 => Listing)) public listings;

    BaseERC20 public immutable paymentToken; // 支付用的ERC20扩展Token

    /**
     * @dev 构造函数，初始化支付Token
     * @param tokenAddress 支付Token合约地址
     */
    constructor(address tokenAddress) {
        paymentToken = BaseERC20(tokenAddress); // 设置支付Token
    }

    /**
     * @dev 上架NFT，设置价格
     * @param nftAddress NFT合约地址
     * @param tokenId NFT的ID
     * @param price 售价（多少个Token）
     */
    function list(address nftAddress, uint256 tokenId, uint256 price) public {
        require(price > 0, "The price must be greater than 0"); // 价格校验
        BaseERC721 nft = BaseERC721(nftAddress); // 实例化NFT合约
        require(nft.ownerOf(tokenId) == msg.sender, "You are not an NFT holder"); // 必须是持有者
        require(
            nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)),
            "The contract is not authorized to transfer the NFT"
        ); // 合约必须有转移权限
        listings[nftAddress][tokenId] = Listing({
            seller: msg.sender,
            nftAddress: nftAddress,
            tokenId: tokenId,
            price: price,
            active: true
        }); // 记录上架信息
    }

    /**
     * @dev 购买NFT，支付Token获得NFT
     * @param nftAddress NFT合约地址
     * @param tokenId NFT的ID
     */
    function buyNFT(address nftAddress, uint256 tokenId) public {
        Listing storage item = listings[nftAddress][tokenId]; // 获取上架信息
        require(item.active, "NFT not available"); // 必须已上架
        require(item.seller != address(0), "Invalid seller");
        require(paymentToken.allowance(msg.sender, address(this)) >= item.price, "Token authorization is insufficient"); // 检查授权
        require(paymentToken.balanceOf(msg.sender) >= item.price, "Token balance is insufficient"); // 检查余额
        // 转账Token给卖家
        require(paymentToken.transferFrom(msg.sender, item.seller, item.price), "Token transfer failed");
        // 转移NFT给买家
        BaseERC721 nft = BaseERC721(nftAddress);
        nft.transferFrom(item.seller, msg.sender, tokenId);
        item.active = false; // 标记为已售出
    }

    /**
     * @dev ERC20扩展Token的回调，支持带data的转账购买NFT
     * @param from 付款人
     * @param amount 支付的Token数量
     * @param data 附加数据，需包含NFT合约地址和tokenId
     */
    function tokensReceived(address from, uint256 amount, bytes calldata data) external {
        require(msg.sender == address(paymentToken), "Only callbacks for specified tokens are accepted"); // 只允许指定Token回调
        require(data.length == 64, "Data parameter format error"); // 地址(32字节)+tokenId(32字节)
        address nftAddress;
        uint256 tokenId;
        // 解析data参数
        assembly {
            nftAddress := calldataload(data.offset)
            tokenId := calldataload(add(data.offset, 32))
        }
        Listing storage item = listings[nftAddress][tokenId]; // 获取上架信息
        require(item.active, "NFT not available");
        require(item.price == amount, "Payment amount does not match");
        // 转账Token给卖家
        require(paymentToken.transfer(item.seller, amount), "Token transfer failed");
        // 转移NFT给买家
        BaseERC721 nft = BaseERC721(nftAddress);
        nft.transferFrom(item.seller, from, tokenId);
        item.active = false; // 标记为已售出
    }

    /**
     * @dev 兼容接口声明的tokensReceived（如果接口只声明了address,uint256）
     */
    function tokensReceived(address, uint256) external pure override {
        // 这里可以留空或revert，防止被误用
        revert("Use tokensReceived(address,uint256,bytes) only");
    }
} 