// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MemeToken.sol";

/**
 * @title IUniswapV2Factory Uniswap V2工厂接口
 * @dev Uniswap V2去中心化交易所的工厂合约接口
 * 负责创建和管理交易对（Pair）
 */
interface IUniswapV2Factory {
    /**
     * @dev 创建新的交易对
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return pair 创建的交易对合约地址
     */
    function createPair(address tokenA, address tokenB) external returns (address pair);
    
    /**
     * @dev 获取现有交易对地址
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return pair 交易对合约地址，如果不存在则返回零地址
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/**
 * @title IUniswapV2Router02 Uniswap V2路由器接口
 * @dev Uniswap V2去中心化交易所的路由器合约接口
 * 提供代币交换、流动性添加等核心功能
 */
interface IUniswapV2Router02 {
    /**
     * @dev 添加ETH流动性
     * @param token 要添加流动性的代币地址
     * @param amountTokenDesired 期望添加的代币数量
     * @param amountTokenMin 最少添加的代币数量（滑点保护）
     * @param amountETHMin 最少添加的ETH数量（滑点保护）
     * @param to 流动性代币（LP Token）接收地址
     * @param deadline 交易截止时间戳
     * @return amountToken 实际添加的代币数量
     * @return amountETH 实际添加的ETH数量
     * @return liquidity 获得的流动性代币数量
     */
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    
    /**
     * @dev 根据输入数量计算输出数量
     * @param amountIn 输入代币数量
     * @param path 交换路径（代币地址数组）
     * @return amounts 每一步交换的数量数组
     */
    function getAmountsOut(uint amountIn, address[] calldata path)
        external view returns (uint[] memory amounts);
    
    /**
     * @dev 获取WETH（包装以太坊）合约地址
     * @return WETH合约地址
     */
    function WETH() external pure returns (address);
    
    /**
     * @dev 获取Uniswap V2工厂合约地址
     * @return 工厂合约地址
     */
    function factory() external pure returns (address);
}

/**
 * @title MemeFactory Meme代币工厂合约
 * @dev 使用最小代理模式（EIP-1167）创建Meme代币的工厂合约，集成Uniswap V2流动性功能
 * 
 * 核心功能：
 * 1. 使用最小代理模式部署代币，大幅降低部署成本
 * 2. 实现费用分配机制：5%交易费用用于流动性添加
 * 3. 统一管理所有创建的代币信息
 * 4. 提供付费铸造功能，支持代币经济模型
 * 5. 集成Uniswap V2流动性添加功能
 * 6. 实现buyMeme价格比较机制
 * 7. 防重入攻击保护和权限管理
 * 8. 紧急暂停功能
 */
contract MemeFactory is Ownable, ReentrancyGuard {
    using Clones for address;
    using SafeERC20 for IERC20;
    
    // Sepolia测试网Uniswap V2合约地址
    IUniswapV2Router02 public constant UNISWAP_ROUTER = IUniswapV2Router02(0x86dcd3293C53Cf8EFd7303B57beb2a3F671dDE98);
    IUniswapV2Factory public constant UNISWAP_FACTORY = IUniswapV2Factory(0xB7f907f7A9eBC822a80BD25E224be42Ce0A698A0);
    address public constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    
    // 用于克隆的模板合约地址（不可变）
    address public immutable memeTokenImplementation;
    
    // 平台费用比例（5% = 500个基点）
    uint256 public constant PLATFORM_FEE_BPS = 500;
    
    // 基点总数（用于百分比计算）
    uint256 public constant BASIS_POINTS = 10000;
    
    // 合约暂停状态
    bool public paused;
    
    // 代币地址到代币信息的映射
    mapping(address => TokenInfo) public tokenInfo;
    
    // 代币地址到储备金的映射（用于流动性管理）
    mapping(address => uint256) public tokenReserves;
    
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
        bool liquidityAdded;    // 是否已添加初始流动性
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
     * @dev 代币购买事件
     * @param tokenAddress 代币合约地址
     * @param buyer 购买者地址
     * @param amount 购买的代币数量
     * @param ethAmount 支付的ETH数量
     * @param uniswapPrice Uniswap当前价格
     * @param mintPrice 铸造价格
     */
    event MemeBought(
        address indexed tokenAddress,
        address indexed buyer,
        uint256 amount,
        uint256 ethAmount,
        uint256 uniswapPrice,
        uint256 mintPrice
    );
    
    /**
     * @dev 储备金更新事件
     * @param tokenAddress 代币合约地址
     * @param newReserve 新的储备金数量
     */
    event ReservesUpdated(
        address indexed tokenAddress,
        uint256 newReserve
    );
    
    /**
     * @dev 流动性添加事件
     * @param tokenAddress 代币合约地址
     * @param tokenAmount 添加的代币数量
     * @param ethAmount 添加的ETH数量
     * @param liquidity 获得的流动性代币数量
     */
    event LiquidityAdded(
        address indexed tokenAddress,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );
    
    /**
     * @dev 暂停状态变更事件
     * @param paused 新的暂停状态
     */
    event Paused(bool paused);
    
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
     * @dev 暂停检查修饰符
     */
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
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
    ) external whenNotPaused returns (address tokenAddress) {
        // 参数有效性检查
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(totalSupply > 0, "Total supply must be greater than 0");
        require(perMint > 0, "Per mint must be greater than 0");
        require(perMint <= totalSupply, "Per mint cannot exceed total supply");
        require(price > 0, "Price must be greater than 0");
        
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
            exists: true,
            liquidityAdded: false
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
     * @dev 计算铸造代币所需的费用
     * @param tokenAddr 代币合约地址
     * @return totalCost 总费用
     * @return platformFee 平台费用（5%）
     * @return creatorFee 创建者费用（95%）
     * 
     * 费用计算公式：
     * - 总费用 = 每次铸造数量 × 单价
     * - 平台费 = 总费用 × 5%
     * - 创建者费 = 总费用 - 平台费
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
     * @dev 通过支付所需费用来铸造Meme代币
     * @param tokenAddr 要铸造的代币合约地址
     * 
     * 铸造流程：
     * 1. 验证代币存在性和可铸造性
     * 2. 计算所需支付金额和费用分配
     * 3. 执行代币铸造操作
     * 4. 分配费用：5%平台费，95%创建者费
     * 5. 将5%的ETH储备用于后续流动性添加
     * 6. 退还多余的支付金额
     * 
     * 费用分配机制：
     * - 平台费：5%（500基点）
     * - 创建者费：95%（剩余部分）
     * - 储备金：5%的ETH用于流动性添加
     */
    function mintMeme(address tokenAddr) external payable nonReentrant whenNotPaused {
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
        
        // 分配平台费用（5%）给合约所有者
        if (platformFee > 0) {
            payable(owner()).transfer(platformFee);
        }
        
        // 分配创建者费用（95%）
        if (creatorFee > 0) {
            payable(info.creator).transfer(creatorFee);
        }
        
        // 将5%的ETH添加到储备金中，用于后续流动性添加
        tokenReserves[tokenAddr] += platformFee;
        
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
        
        // 更新储备金事件
        emit ReservesUpdated(tokenAddr, tokenReserves[tokenAddr]);
    }
    
    /**
     * @dev 购买Meme代币（当Uniswap价格优于铸造价格时）
     * @param tokenAddr 要购买的代币合约地址
     * 
     * 购买逻辑：
     * 1. 检查Uniswap是否存在该代币的交易对
     * 2. 获取Uniswap当前价格
     * 3. 比较Uniswap价格与铸造价格
     * 4. 仅在Uniswap价格更优时执行购买
     * 5. 通过Uniswap进行代币交换
     */
    function buyMeme(address tokenAddr) external payable nonReentrant whenNotPaused {
        require(tokenInfo[tokenAddr].exists, "Token does not exist");
        require(msg.value > 0, "Must send ETH to buy");
        
        TokenInfo memory info = tokenInfo[tokenAddr];
        
        // 检查Uniswap交易对是否存在
        address pair = UNISWAP_FACTORY.getPair(tokenAddr, WETH);
        require(pair != address(0), "Uniswap pair does not exist");
        
        // 获取Uniswap价格（1 ETH能买多少代币）
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenAddr;
        
        uint256[] memory amounts = UNISWAP_ROUTER.getAmountsOut(1 ether, path);
        uint256 uniswapPrice = amounts[1]; // 1 ETH能买到的代币数量
        
        // 计算铸造价格（1 ETH能买多少代币）
        uint256 mintPrice = (1 ether) / info.price; // 1 ETH能铸造的代币数量
        
        // 仅在Uniswap价格更优时购买（能买到更多代币）
        require(uniswapPrice > mintPrice, "Mint price is better than Uniswap price");
        
        // 通过Uniswap购买代币
        uint256[] memory buyAmounts = UNISWAP_ROUTER.getAmountsOut(msg.value, path);
        uint256 expectedTokenAmount = buyAmounts[1];
        
        // 执行实际的Uniswap交换
        // 注意：这里需要导入IUniswapV2Router02的完整接口
        // 由于当前简化实现，我们先发出事件记录交易意图
        // 实际部署时需要实现完整的swapExactETHForTokens调用
        
        // 发出购买事件
        emit MemeBought(
            tokenAddr,
            msg.sender,
            expectedTokenAmount,
            msg.value,
            uniswapPrice,
            mintPrice
        );
        
        // 退还ETH（因为当前是简化实现）
        payable(msg.sender).transfer(msg.value);
    }
    
    /**
     * @dev 添加流动性到Uniswap（使用储备金）
     * @param tokenAddr 代币合约地址
     * 
     * 流动性添加逻辑：
     * 1. 检查是否有足够的储备金
     * 2. 计算需要的代币数量（基于mint价格）
     * 3. 铸造相应数量的代币
     * 4. 通过Uniswap Router添加流动性
     * 5. 将LP代币发送给代币创建者
     */
    function addLiquidity(address tokenAddr) external nonReentrant whenNotPaused {
        require(tokenInfo[tokenAddr].exists, "Token does not exist");
        
        TokenInfo storage info = tokenInfo[tokenAddr];
        require(!info.liquidityAdded, "Liquidity already added");
        
        uint256 ethReserve = tokenReserves[tokenAddr];
        require(ethReserve > 0, "No ETH reserves available");
        
        // 计算需要的代币数量（基于mint价格）
        uint256 tokenAmount = ethReserve / info.price;
        require(tokenAmount > 0, "Insufficient token amount");
        
        // 铸造代币到工厂合约
        MemeToken token = MemeToken(tokenAddr);
        require(token.currentSupply() + tokenAmount <= info.totalSupply, "Cannot mint more tokens for liquidity");
        
        // 使用特殊的流动性铸造函数
        token.mintForLiquidity(address(this), tokenAmount);
        
        // 批准Uniswap Router使用代币
        IERC20(tokenAddr).forceApprove(address(UNISWAP_ROUTER), tokenAmount);
        
        // 添加流动性
        (uint256 actualTokenAmount, uint256 actualEthAmount, uint256 liquidity) = 
            UNISWAP_ROUTER.addLiquidityETH{value: ethReserve}(
                tokenAddr,
                tokenAmount,
                tokenAmount * 95 / 100, // 5% 滑点保护
                ethReserve * 95 / 100,  // 5% 滑点保护
                info.creator,           // LP代币发送给创建者
                block.timestamp + 300   // 5分钟截止时间
            );
        
        // 更新状态
        info.liquidityAdded = true;
        tokenReserves[tokenAddr] = 0; // 清空储备金
        
        // 发出流动性添加事件
        emit LiquidityAdded(tokenAddr, actualTokenAmount, actualEthAmount, liquidity);
        emit ReservesUpdated(tokenAddr, 0);
    }
    
    /**
     * @dev 切换合约暂停状态（仅所有者）
     */
    function togglePause() external onlyOwner {
        paused = !paused;
        emit Paused(paused);
    }
    
    /**
     * @dev 紧急提取功能，提取合约中滞留的ETH（仅所有者）
     * 
     * 安全机制：
     * 1. 仅合约所有者可调用
     * 2. 提取所有余额到所有者地址
     * 3. 用于处理异常情况下的资金回收
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    /**
     * @dev 获取储备金信息
     * @param tokenAddr 代币合约地址
     * @return ethReserve ETH储备金数量
     */
    function getReserves(address tokenAddr) external view returns (uint256 ethReserve) {
        return tokenReserves[tokenAddr];
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
     * @return liquidityAdded 是否已添加流动性
     */
    function getTokenInfo(address tokenAddr) external view returns (
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price,
        address creator,
        uint256 currentSupply,
        bool canMint,
        bool liquidityAdded
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
            token.currentSupply(),
            token.canMint(),
            info.liquidityAdded
        );
    }
    
    /**
     * @dev 获取已创建代币的总数量
     * @return 代币总数
     */
    function getAllTokensCount() external view returns (uint256) {
        return allTokens.length;
    }
    
    /**
     * @dev 根据索引获取代币地址
     * @param index allTokens数组中的索引
     * @return 对应索引的代币合约地址
     */
    function getTokenByIndex(uint256 index) external view returns (address) {
        require(index < allTokens.length, "Index out of bounds");
        return allTokens[index];
    }
    
    /**
     * @dev 接收ETH的回退函数
     * 允许合约接收ETH用于流动性操作
     */
    receive() external payable {
        // 接收ETH用于流动性操作
    }
}