// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./MemeToken.sol";

/**
 * @title MemeFactory Meme代币工厂合约
 * @dev 使用最小代理模式（EIP-1167）创建Meme代币的工厂合约
 * 
 * 核心功能：
 * 1. 使用最小代理模式部署代币，大幅降低部署成本
 * 2. 实现费用分配机制：1%平台费，99%创建者费用
 * 3. 统一管理所有创建的代币信息
 * 4. 提供付费铸造功能，支持代币经济模型
 * 5. 防重入攻击保护和权限管理
 */
contract MemeFactory is Ownable, ReentrancyGuard {
    using Clones for address;
    
    // 用于克隆的模板合约地址（不可变）
    address public immutable memeTokenImplementation;
    
    // 平台费用比例（1% = 100个基点）
    uint256 public constant PLATFORM_FEE_BPS = 100;
    
    // 基点总数（用于百分比计算）
    uint256 public constant BASIS_POINTS = 10000;
    
    // 代币地址到代币信息的映射
    mapping(address => TokenInfo) public tokenInfo;
    
    // 所有已创建代币的地址数组
    address[] public allTokens;
    
    /**
     * @dev 代币信息结构体
     * 存储每个代币的基本信息和配置参数
     */
    struct TokenInfo {
        string symbol;          // 代币符号
        uint256 totalSupply;    // 总供应量上限
        uint256 perMint;        // 每次铸造数量
        uint256 price;          // 每个代币价格（wei）
        address creator;        // 代币创建者地址
        bool exists;            // 代币是否存在的标志
    }
    
    /**
     * @dev 代币部署事件
     * @param tokenAddress 新部署的代币合约地址
     * @param creator 代币创建者地址
     * @param symbol 代币符号
     * @param totalSupply 总供应量
     * @param perMint 每次铸造数量
     * @param price 代币价格
     */
    event MemeDeployed(
        address indexed tokenAddress,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    
    /**
     * @dev 代币铸造事件
     * @param tokenAddress 代币合约地址
     * @param minter 铸造者地址
     * @param amount 铸造的代币数量
     * @param totalPayment 总支付金额
     * @param platformFee 平台费用
     * @param creatorFee 创建者费用
     */
    event MemeMinted(
        address indexed tokenAddress,
        address indexed minter,
        uint256 amount,
        uint256 totalPayment,
        uint256 platformFee,
        uint256 creatorFee
    );
    
    /**
     * @dev 构造函数
     * 部署MemeToken模板合约，用于后续的最小代理克隆
     * 
     * 最小代理模式优势：
     * 1. 大幅降低部署成本（每次部署只需约200 gas）
     * 2. 所有克隆合约共享同一套代码逻辑
     * 3. 通过initialize函数实现个性化配置
     */
    constructor() Ownable(msg.sender) {
        // 部署模板合约实例
        memeTokenImplementation = address(new MemeToken());
    }
    
    /**
     * @dev 使用最小代理模式部署新的Meme代币
     * @param symbol 代币符号
     * @param totalSupply 最大总供应量
     * @param perMint 每次交易铸造的数量
     * @param price 每个代币的价格（以wei为单位）
     * @return tokenAddress 新创建代币的合约地址
     * 
     * 部署流程：
     * 1. 参数验证确保输入有效性
     * 2. 使用EIP-1167标准创建最小代理
     * 3. 初始化克隆合约的状态变量
     * 4. 存储代币信息到工厂合约
     * 5. 发出部署事件通知
     */
    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address tokenAddress) {
        // 参数有效性检查
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(totalSupply > 0, "Total supply must be greater than 0");
        require(perMint > 0, "Per mint must be greater than 0");
        require(perMint <= totalSupply, "Per mint cannot exceed total supply");
        
        // 创建最小代理克隆
        tokenAddress = memeTokenImplementation.clone();
        
        // 初始化克隆的合约实例
        MemeToken(tokenAddress).initialize(
            symbol,
            totalSupply,
            perMint,
            price,
            msg.sender,      // 设置调用者为创建者
            address(this)    // 设置工厂合约为所有者
        );
        
        // 存储代币信息到映射中
        tokenInfo[tokenAddress] = TokenInfo({
            symbol: symbol,
            totalSupply: totalSupply,
            perMint: perMint,
            price: price,
            creator: msg.sender,
            exists: true
        });
        
        // 添加到代币地址数组
        allTokens.push(tokenAddress);
        
        // 发出部署事件
        emit MemeDeployed(
            tokenAddress,
            msg.sender,
            symbol,
            totalSupply,
            perMint,
            price
        );
        
        return tokenAddress;
    }
    
    /**
     * @dev 通过支付所需费用来铸造Meme代币
     * @param tokenAddr 要铸造的代币合约地址
     * 
     * 铸造流程：
     * 1. 验证代币存在性和可铸造性
     * 2. 计算所需支付金额和费用分配
     * 3. 执行代币铸造操作
     * 4. 分配费用给平台和创建者
     * 5. 退还多余的支付金额
     * 
     * 费用分配机制：
     * - 平台费：1%（100基点）
     * - 创建者费：99%（剩余部分）
     */
    function mintMeme(address tokenAddr) external payable nonReentrant {
        require(tokenInfo[tokenAddr].exists, "Token does not exist");
        
        TokenInfo memory info = tokenInfo[tokenAddr];
        MemeToken token = MemeToken(tokenAddr);
        
        // 检查是否还能铸造更多代币
        require(token.canMint(), "Cannot mint more tokens");
        
        // 计算所需支付金额
        uint256 totalPayment = info.perMint * info.price;
        require(msg.value >= totalPayment, "Insufficient payment");
        
        // 计算费用分配
        uint256 platformFee = (totalPayment * PLATFORM_FEE_BPS) / BASIS_POINTS;
        uint256 creatorFee = totalPayment - platformFee;
        
        // 向调用者铸造代币
        token.mint(msg.sender);
        
        // 分配平台费用
        if (platformFee > 0) {
            payable(owner()).transfer(platformFee);
        }
        
        // 分配创建者费用
        if (creatorFee > 0) {
            payable(info.creator).transfer(creatorFee);
        }
        
        // 退还多余的支付金额
        if (msg.value > totalPayment) {
            payable(msg.sender).transfer(msg.value - totalPayment);
        }
        
        // 发出铸造事件
        emit MemeMinted(
            tokenAddr,
            msg.sender,
            info.perMint,
            totalPayment,
            platformFee,
            creatorFee
        );
    }
    
    /**
     * @dev 获取代币的详细信息
     * @param tokenAddr 代币合约地址
     * @return symbol 代币符号
     * @return totalSupply 总供应量上限
     * @return perMint 每次铸造数量
     * @return price 代币价格
     * @return creator 创建者地址
     * @return currentSupply 当前已铸造数量
     * @return canMint 是否还能继续铸造
     * 
     * 此函数结合了工厂存储的静态信息和代币合约的动态状态
     */
    function getTokenInfo(address tokenAddr) external view returns (
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price,
        address creator,
        uint256 currentSupply,
        bool canMint
    ) {
        require(tokenInfo[tokenAddr].exists, "Token does not exist");
        
        TokenInfo memory info = tokenInfo[tokenAddr];
        MemeToken token = MemeToken(tokenAddr);
        
        return (
            info.symbol,
            info.totalSupply,
            info.perMint,
            info.price,
            info.creator,
            token.currentSupply(),    // 从代币合约获取实时数据
            token.canMint()           // 从代币合约获取实时状态
        );
    }
    
    /**
     * @dev 获取已创建代币的总数量
     * @return 代币总数
     * 
     * 用于前端分页显示或统计分析
     */
    function getAllTokensCount() external view returns (uint256) {
        return allTokens.length;
    }
    
    /**
     * @dev 根据索引获取代币地址
     * @param index allTokens数组中的索引
     * @return 对应索引的代币合约地址
     * 
     * 配合getAllTokensCount使用，支持遍历所有代币
     */
    function getTokenByIndex(uint256 index) external view returns (address) {
        require(index < allTokens.length, "Index out of bounds");
        return allTokens[index];
    }
    
    /**
     * @dev 计算铸造代币所需的费用
     * @param tokenAddr 代币合约地址
     * @return totalCost 总费用
     * @return platformFee 平台费用
     * @return creatorFee 创建者费用
     * 
     * 费用计算公式：
     * - 总费用 = 每次铸造数量 × 单价
     * - 平台费 = 总费用 × 1%
     * - 创建者费 = 总费用 - 平台费
     * 
     * 用于前端显示费用明细，提高透明度
     */
    function calculateMintCost(address tokenAddr) external view returns (
        uint256 totalCost,
        uint256 platformFee,
        uint256 creatorFee
    ) {
        require(tokenInfo[tokenAddr].exists, "Token does not exist");
        
        TokenInfo memory info = tokenInfo[tokenAddr];
        totalCost = info.perMint * info.price;
        platformFee = (totalCost * PLATFORM_FEE_BPS) / BASIS_POINTS;
        creatorFee = totalCost - platformFee;
        
        return (totalCost, platformFee, creatorFee);
    }
    
    /**
     * @dev 紧急提取功能，提取合约中滞留的ETH（仅所有者）
     * 
     * 安全机制：
     * 1. 仅合约所有者可调用
     * 2. 提取所有余额到所有者地址
     * 3. 用于处理异常情况下的资金回收
     * 
     * 注意：正常情况下合约不应有余额滞留
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}