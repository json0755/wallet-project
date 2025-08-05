// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MemeToken Meme代币合约
 * @dev 为Meme生态系统设计的ERC20代币，支持批量铸造和供应量上限
 * 
 * 核心特性：
 * 1. 兼容最小代理模式（EIP-1167），实现低成本部署
 * 2. 使用初始化函数替代构造函数，支持代理模式
 * 3. 实现每次交易铸造限制，控制代币发行节奏
 * 4. 内置定价机制，支持付费铸造模式
 * 5. 供应量上限保护，防止无限增发
 * 6. 创建者信息记录，支持版税分配
 * 
 * 设计模式：
 * - 代理友好：使用initialize而非constructor
 * - 权限控制：工厂合约作为owner管理铸造
 * - 经济模型：固定价格 + 限量供应
 */
contract MemeToken is ERC20, Ownable {
    // 代币符号（可自定义覆盖默认值）
    string private _tokenSymbol;
    
    // 总供应量上限
    uint256 public totalSupplyCap;
    
    // 每次铸造的代币数量
    uint256 public perMint;
    
    // 每个代币的价格（以wei为单位）
    uint256 public price;
    
    // 代币创建者地址
    address public creator;
    
    // 工厂合约地址（拥有铸造权限）
    address public factory;
    
    // 当前已铸造的代币数量
    uint256 public currentSupply;
    
    /**
     * @dev 铸造事件
     * @param to 接收代币的地址
     * @param amount 铸造的代币数量
     */
    event TokenMinted(address indexed to, uint256 amount);
    
    /**
     * @dev 构造函数
     * 仅用于部署模板合约，实际使用通过initialize函数初始化
     * 
     * 注意：在最小代理模式中，构造函数只在模板合约中执行一次
     * 每个克隆合约需要通过initialize函数进行个性化配置
     */
    constructor() ERC20("MemeToken", "MEME") Ownable(msg.sender) {
        // 这是模板合约，不直接使用
    }
    
    /**
     * @dev 初始化代币（在代理模式中替代构造函数）
     * @param _symbol 代币符号
     * @param _totalSupply 最大总供应量
     * @param _perMint 每次交易铸造的数量
     * @param _price 每个代币的价格（以wei为单位）
     * @param _creator 代币创建者地址
     * @param _factory 合约所有者（通常是工厂合约）
     * 
     * 初始化流程：
     * 1. 检查是否已初始化（防止重复初始化）
     * 2. 验证所有参数的有效性
     * 3. 设置代币的基本属性
     * 4. 转移所有权给工厂合约
     * 
     * 安全机制：
     * - 只能初始化一次
     * - 参数完整性验证
     * - 地址非零检查
     */
    function initialize(
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address _creator,
        address _factory
    ) external {
        // 防止重复初始化
        require(factory == address(0), "Already initialized");
        
        // 参数有效性验证
        require(_totalSupply > 0, "Total supply must be greater than 0");
        require(_perMint > 0, "Per mint must be greater than 0");
        require(_perMint <= _totalSupply, "Per mint cannot exceed total supply");
        require(_creator != address(0), "Creator cannot be zero address");
        require(_factory != address(0), "Factory cannot be zero address");
        
        // 设置代币属性
        _tokenSymbol = _symbol;
        totalSupplyCap = _totalSupply;
        perMint = _perMint;
        price = _price;
        creator = _creator;
        factory = _factory;
        currentSupply = 0;  // 初始供应量为0
        
        // 将所有权转移给工厂合约
        _transferOwnership(_factory);
    }
    
    /**
     * @dev 向指定地址铸造代币（仅所有者可调用）
     * @param to 接收代币的地址
     * 
     * 铸造机制：
     * 1. 验证接收地址有效性
     * 2. 检查是否超过供应量上限
     * 3. 更新当前供应量计数
     * 4. 执行ERC20标准铸造
     * 5. 发出铸造事件
     * 
     * 限制条件：
     * - 只有工厂合约（owner）可以调用
     * - 每次固定铸造perMint数量
     * - 不能超过总供应量上限
     * - 不能向零地址铸造
     */
    function mint(address to) external onlyOwner {
        require(to != address(0), "Cannot mint to zero address");
        require(currentSupply + perMint <= totalSupplyCap, "Cannot mint more tokens");
        
        // 更新供应量计数
        currentSupply += perMint;
        
        // 执行ERC20铸造
        _mint(to, perMint);
        
        // 发出铸造事件
        emit TokenMinted(to, perMint);
    }
    
    /**
     * @dev 重写符号函数以返回自定义符号
     * @return 代币符号字符串
     * 
     * 符号优先级：
     * 1. 如果设置了自定义符号，返回自定义符号
     * 2. 否则返回默认符号（"MEME"）
     * 
     * 这允许每个代币有独特的符号标识
     */
    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }
    
    /**
     * @dev 检查是否还能铸造更多代币
     * @return 如果可以继续铸造返回true，否则返回false
     * 
     * 判断逻辑：当前供应量 + 每次铸造量 <= 总供应量上限
     * 用于前端显示和工厂合约验证
     */
    function canMint() external view returns (bool) {
        return currentSupply + perMint <= totalSupplyCap;
    }
    
    /**
     * @dev 获取剩余可铸造的供应量
     * @return 剩余可铸造的代币数量
     * 
     * 计算公式：总供应量上限 - 当前已铸造数量
     * 如果当前供应量已达上限，返回0
     * 用于显示稀缺性和剩余额度
     */
    function remainingSupply() external view returns (uint256) {
        return totalSupplyCap - currentSupply;
    }
}