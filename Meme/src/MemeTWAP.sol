// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MemeFactory.sol";
import "./MemeToken.sol";

/**
 * @title MemeTWAP Meme代币时间加权平均价格合约
 * @dev 用于计算LaunchPad发行的Meme代币的TWAP价格
 * 
 * 核心功能：
 * 1. 记录代币价格历史数据
 * 2. 计算指定时间窗口的TWAP价格
 * 3. 支持多个代币的价格跟踪
 * 4. 提供价格更新和查询接口
 * 
 * TWAP计算原理：
 * TWAP = Σ(价格 × 时间权重) / 总时间
 * 时间权重 = 该价格持续的时间长度
 */
contract MemeTWAP {
    // 价格记录结构体
    struct PriceRecord {
        uint256 price;          // 价格（wei per token）
        uint256 timestamp;      // 记录时间戳
        uint256 cumulativePrice; // 累积价格（用于TWAP计算）
    }
    
    // 代币价格历史记录
    mapping(address => PriceRecord[]) public priceHistory;
    
    // MemeFactory合约引用
    MemeFactory public immutable memeFactory;
    
    // 最小更新间隔（防止频繁更新）
    uint256 public constant MIN_UPDATE_INTERVAL = 60; // 1分钟
    
    // 最后更新时间
    mapping(address => uint256) public lastUpdateTime;
    
    /**
     * @dev 价格更新事件
     * @param token 代币地址
     * @param price 新价格
     * @param timestamp 更新时间戳
     */
    event PriceUpdated(
        address indexed token,
        uint256 price,
        uint256 timestamp
    );
    
    /**
     * @dev TWAP计算事件
     * @param token 代币地址
     * @param twapPrice TWAP价格
     * @param startTime 开始时间
     * @param endTime 结束时间
     */
    event TWAPCalculated(
        address indexed token,
        uint256 twapPrice,
        uint256 startTime,
        uint256 endTime
    );
    
    /**
     * @dev 构造函数
     * @param _memeFactory MemeFactory合约地址
     */
    constructor(address _memeFactory) {
        require(_memeFactory != address(0), "Invalid factory address");
        memeFactory = MemeFactory(payable(_memeFactory));
    }
    
    /**
     * @dev 更新代币价格
     * @param token 代币地址
     * @param newPrice 新价格（wei per token）
     * 
     * 更新逻辑：
     * 1. 验证代币存在性
     * 2. 检查更新间隔
     * 3. 计算累积价格
     * 4. 添加新的价格记录
     */
    function updatePrice(address token, uint256 newPrice) external {
        // 验证代币是否存在于MemeFactory中
        (string memory symbol,,,,,,,) = memeFactory.getTokenInfo(token);
        require(bytes(symbol).length > 0, "Token does not exist");
        
        // 检查更新间隔
        require(
            block.timestamp >= lastUpdateTime[token] + MIN_UPDATE_INTERVAL,
            "Update too frequent"
        );
        
        PriceRecord[] storage history = priceHistory[token];
        uint256 currentTime = block.timestamp;
        
        // 计算累积价格
        uint256 cumulativePrice = 0;
        if (history.length > 0) {
            PriceRecord memory lastRecord = history[history.length - 1];
            uint256 timeDelta = currentTime - lastRecord.timestamp;
            cumulativePrice = lastRecord.cumulativePrice + (lastRecord.price * timeDelta);
        }
        
        // 添加新的价格记录
        history.push(PriceRecord({
            price: newPrice,
            timestamp: currentTime,
            cumulativePrice: cumulativePrice
        }));
        
        lastUpdateTime[token] = currentTime;
        
        emit PriceUpdated(token, newPrice, currentTime);
    }
    
    /**
     * @dev 获取代币的当前价格（最新记录）
     * @param token 代币地址
     * @return price 当前价格
     * @return timestamp 价格记录时间
     */
    function getCurrentPrice(address token) external view returns (uint256 price, uint256 timestamp) {
        PriceRecord[] storage history = priceHistory[token];
        require(history.length > 0, "No price history");
        
        PriceRecord memory latestRecord = history[history.length - 1];
        return (latestRecord.price, latestRecord.timestamp);
    }
    
    /**
     * @dev 计算指定时间窗口的TWAP价格
     * @param token 代币地址
     * @param startTime 开始时间戳
     * @param endTime 结束时间戳
     * @return twapPrice 时间加权平均价格
     * 
     * TWAP计算步骤：
     * 1. 找到时间窗口内的所有价格记录
     * 2. 计算每个价格的时间权重
     * 3. 计算加权平均价格
     */
    function calculateTWAP(
        address token,
        uint256 startTime,
        uint256 endTime
    ) external view returns (uint256 twapPrice) {
        require(endTime > startTime, "Invalid time range");
        require(endTime <= block.timestamp, "End time in future");
        
        PriceRecord[] storage history = priceHistory[token];
        require(history.length > 0, "No price history");
        
        uint256 totalWeightedPrice = 0;
        uint256 totalTime = 0;
        
        // 遍历价格历史记录
        for (uint256 i = 0; i < history.length; i++) {
            PriceRecord memory record = history[i];
            
            // 跳过时间窗口之前的记录
            if (record.timestamp < startTime) {
                continue;
            }
            
            // 计算该记录的有效时间范围
            uint256 recordStartTime = record.timestamp < startTime ? startTime : record.timestamp;
            uint256 recordEndTime;
            
            if (i == history.length - 1) {
                // 最后一条记录，使用endTime作为结束时间
                recordEndTime = endTime;
            } else {
                // 使用下一条记录的时间戳作为结束时间
                uint256 nextTimestamp = history[i + 1].timestamp;
                recordEndTime = nextTimestamp > endTime ? endTime : nextTimestamp;
            }
            
            // 如果记录开始时间已经超过窗口结束时间，停止计算
            if (recordStartTime >= endTime) {
                break;
            }
            
            // 计算时间权重
            uint256 timeWeight = recordEndTime - recordStartTime;
            if (timeWeight > 0) {
                totalWeightedPrice += record.price * timeWeight;
                totalTime += timeWeight;
            }
        }
        
        require(totalTime > 0, "No valid price data in time range");
        
        twapPrice = totalWeightedPrice / totalTime;
        
        return twapPrice;
    }
    
    /**
     * @dev 计算最近N秒的TWAP价格
     * @param token 代币地址
     * @param duration 时间长度（秒）
     * @return twapPrice TWAP价格
     */
    function calculateRecentTWAP(
        address token,
        uint256 duration
    ) external view returns (uint256 twapPrice) {
        require(duration <= block.timestamp, "Duration too large");
        
        uint256 endTime = block.timestamp;
        uint256 startTime = endTime - duration;
        
        return this.calculateTWAP(token, startTime, endTime);
    }
    
    /**
     * @dev 获取代币的价格历史记录数量
     * @param token 代币地址
     * @return count 记录数量
     */
    function getPriceHistoryLength(address token) external view returns (uint256 count) {
        return priceHistory[token].length;
    }
    
    /**
     * @dev 获取指定索引的价格记录
     * @param token 代币地址
     * @param index 记录索引
     * @return price 价格
     * @return timestamp 时间戳
     * @return cumulativePrice 累积价格
     */
    function getPriceRecord(
        address token,
        uint256 index
    ) external view returns (
        uint256 price,
        uint256 timestamp,
        uint256 cumulativePrice
    ) {
        require(index < priceHistory[token].length, "Index out of bounds");
        
        PriceRecord memory record = priceHistory[token][index];
        return (record.price, record.timestamp, record.cumulativePrice);
    }
    
    /**
     * @dev 批量更新多个代币的价格
     * @param tokens 代币地址数组
     * @param prices 对应的价格数组
     */
    function batchUpdatePrices(
        address[] calldata tokens,
        uint256[] calldata prices
    ) external {
        require(tokens.length == prices.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < tokens.length; i++) {
            // 检查更新间隔
            if (block.timestamp >= lastUpdateTime[tokens[i]] + MIN_UPDATE_INTERVAL) {
                this.updatePrice(tokens[i], prices[i]);
            }
        }
    }
    
    /**
     * @dev 从MemeFactory获取代币的初始价格并记录
     * @param token 代币地址
     */
    function initializePriceFromFactory(address token) external {
        // 从MemeFactory获取代币信息
        (, , , uint256 tokenPrice, , , , bool liquidityAdded) = memeFactory.getTokenInfo(token);
        require(tokenPrice > 0, "Token does not exist in factory");
        
        // 如果还没有价格记录，则初始化
        if (priceHistory[token].length == 0) {
            priceHistory[token].push(PriceRecord({
                price: tokenPrice,
                timestamp: block.timestamp,
                cumulativePrice: 0
            }));
            
            lastUpdateTime[token] = block.timestamp;
            
            emit PriceUpdated(token, tokenPrice, block.timestamp);
        }
    }
}