// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";
import "../src/MemeTWAP.sol";

/**
 * @title MemeTWAPTest TWAP价格合约测试
 * @dev 测试Meme代币的时间加权平均价格计算功能
 * 
 * 测试场景：
 * 1. 基本价格更新和查询
 * 2. TWAP价格计算
 * 3. 多时间点价格变化模拟
 * 4. 边界条件测试
 */
contract MemeTWAPTest is Test {
    MemeFactory public factory;
    MemeTWAP public twapContract;
    address public memeToken;
    
    address public owner;
    address public creator;
    address public user1;
    address public user2;
    
    // 测试参数
    string constant SYMBOL = "TWAP";
    uint256 constant TOTAL_SUPPLY = 1000000 * 10**18;
    uint256 constant PER_MINT = 1000 * 10**18;
    uint256 constant INITIAL_PRICE = 1000; // 1000 wei per token
    
    // 时间常量
    uint256 constant HOUR = 3600;
    uint256 constant DAY = 24 * HOUR;
    
    event PriceUpdated(
        address indexed token,
        uint256 price,
        uint256 timestamp
    );
    
    event TWAPCalculated(
        address indexed token,
        uint256 twapPrice,
        uint256 startTime,
        uint256 endTime
    );
    
    function setUp() public {
        owner = address(this);
        creator = makeAddr("creator");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 部署MemeFactory
        factory = new MemeFactory();
        
        // 部署TWAP合约
        twapContract = new MemeTWAP(address(factory));
        
        // 部署测试代币
        memeToken = factory.deployMeme(
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            INITIAL_PRICE
        );
        
        // 为测试用户提供ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(creator, 100 ether);
    }
    
    /**
     * @dev 测试基本价格更新功能
     */
    function testBasicPriceUpdate() public {
        uint256 newPrice = 1500; // 1500 wei per token
        
        // 等待足够的时间间隔
        vm.warp(block.timestamp + 61);
        
        // 更新价格
        twapContract.updatePrice(memeToken, newPrice);
        
        // 验证价格更新
        (uint256 currentPrice, uint256 timestamp) = twapContract.getCurrentPrice(memeToken);
        assertEq(currentPrice, newPrice);
        assertEq(timestamp, block.timestamp);
        
        // 验证历史记录数量
        uint256 historyLength = twapContract.getPriceHistoryLength(memeToken);
        assertEq(historyLength, 1);
    }
    
    /**
     * @dev 测试从工厂初始化价格
     */
    function testInitializePriceFromFactory() public {
        // 从工厂初始化价格
        twapContract.initializePriceFromFactory(memeToken);
        
        // 验证价格初始化
        (uint256 currentPrice,) = twapContract.getCurrentPrice(memeToken);
        assertEq(currentPrice, INITIAL_PRICE);
    }
    
    /**
     * @dev 测试频繁更新限制
     */
    function testUpdateFrequencyLimit() public {
        uint256 price1 = 1000;
        uint256 price2 = 1500;
        
        // 等待足够的时间间隔
        vm.warp(block.timestamp + 61);
        
        // 第一次更新
        twapContract.updatePrice(memeToken, price1);
        
        // 立即尝试第二次更新（应该失败）
        vm.expectRevert("Update too frequent");
        twapContract.updatePrice(memeToken, price2);
        
        // 等待足够时间后再次更新（应该成功）
        vm.warp(block.timestamp + 61); // 等待61秒
        twapContract.updatePrice(memeToken, price2);
        
        (uint256 currentPrice,) = twapContract.getCurrentPrice(memeToken);
        assertEq(currentPrice, price2);
    }
    
    /**
     * @dev 测试多时间点价格变化和TWAP计算
     * 模拟一天内的价格变化：
     * - 0小时: 1000 wei
     * - 6小时: 1500 wei  
     * - 12小时: 2000 wei
     * - 18小时: 1200 wei
     * - 24小时: 1800 wei
     */
    function testMultipleTimePointsTWAP() public {
        uint256 startTime = block.timestamp;
        
        // 等待足够的时间间隔
        vm.warp(startTime + 61);
        
        // 时间点0: 价格1000
        twapContract.updatePrice(memeToken, 1000);
        
        // 时间点6小时: 价格1500
        vm.warp(startTime + 6 * HOUR);
        twapContract.updatePrice(memeToken, 1500);
        
        // 时间点12小时: 价格2000
        vm.warp(startTime + 12 * HOUR);
        twapContract.updatePrice(memeToken, 2000);
        
        // 时间点18小时: 价格1200
        vm.warp(startTime + 18 * HOUR);
        twapContract.updatePrice(memeToken, 1200);
        
        // 时间点24小时: 价格1800
        vm.warp(startTime + 24 * HOUR);
        twapContract.updatePrice(memeToken, 1800);
        
        // 计算前12小时的TWAP
        // 期望值: (1000 * 6 + 1500 * 6) / 12 = 1250
        uint256 twap12h = twapContract.calculateTWAP(
            memeToken,
            startTime,
            startTime + 12 * HOUR
        );
        assertEq(twap12h, 1250);
        
        // 计算全天24小时的TWAP
        // 期望值: (1000 * 6 + 1500 * 6 + 2000 * 6 + 1200 * 6) / 24 = 1425
        uint256 twap24h = twapContract.calculateTWAP(
            memeToken,
            startTime,
            startTime + 24 * HOUR
        );
        assertEq(twap24h, 1425);
        
        // 验证历史记录数量
        uint256 historyLength = twapContract.getPriceHistoryLength(memeToken);
        assertEq(historyLength, 5);
    }
    
    /**
     * @dev 测试最近时间段TWAP计算
     */
    function testRecentTWAP() public {
        uint256 startTime = block.timestamp;
        
        // 等待足够的时间间隔
        vm.warp(startTime + 61);
        
        // 添加一些价格历史
        twapContract.updatePrice(memeToken, 1000);
        
        vm.warp(startTime + 2 * HOUR);
        twapContract.updatePrice(memeToken, 1500);
        
        vm.warp(startTime + 4 * HOUR);
        twapContract.updatePrice(memeToken, 2000);
        
        // 计算最近2小时的TWAP
        uint256 recentTWAP = twapContract.calculateRecentTWAP(memeToken, 2 * HOUR);
        
        // 最近2小时应该只包含价格1500和2000的加权平均
        // 由于价格1500持续了2小时，价格2000是当前价格
        assertEq(recentTWAP, 1500);
    }
    
    /**
     * @dev 测试批量价格更新
     */
    function testBatchPriceUpdate() public {
        // 部署第二个测试代币
        address memeToken2 = factory.deployMeme(
            "BATCH",
            TOTAL_SUPPLY,
            PER_MINT,
            INITIAL_PRICE
        );
        
        address[] memory tokens = new address[](2);
        uint256[] memory prices = new uint256[](2);
        
        tokens[0] = memeToken;
        tokens[1] = memeToken2;
        prices[0] = 1500;
        prices[1] = 2000;
        
        // 等待足够的时间间隔
        vm.warp(block.timestamp + 61);
        
        // 批量更新价格
        twapContract.batchUpdatePrices(tokens, prices);
        
        // 验证两个代币的价格都已更新
        (uint256 price1,) = twapContract.getCurrentPrice(memeToken);
        (uint256 price2,) = twapContract.getCurrentPrice(memeToken2);
        
        assertEq(price1, 1500);
        assertEq(price2, 2000);
    }
    
    /**
     * @dev 测试边界条件：无效时间范围
     */
    function testInvalidTimeRange() public {
        // 等待足够的时间间隔
        vm.warp(block.timestamp + 61);
        
        twapContract.updatePrice(memeToken, 1000);
        
        uint256 currentTime = block.timestamp;
        
        // 测试结束时间早于开始时间
        vm.expectRevert("Invalid time range");
        twapContract.calculateTWAP(
            memeToken,
            currentTime,
            currentTime - 1
        );
        
        // 测试结束时间在未来
        vm.expectRevert("End time in future");
        twapContract.calculateTWAP(
            memeToken,
            currentTime,
            currentTime + 1000
        );
    }
    
    /**
     * @dev 测试无价格历史的情况
     */
    function testNoPriceHistory() public {
        // 部署新代币但不添加价格历史
        address newToken = factory.deployMeme(
            "EMPTY",
            TOTAL_SUPPLY,
            PER_MINT,
            INITIAL_PRICE
        );
        
        // 尝试获取当前价格（应该失败）
        vm.expectRevert("No price history");
        twapContract.getCurrentPrice(newToken);
    }
    
    /**
     * @dev 测试无价格历史时计算TWAP的情况
     */
    function testNoPriceHistoryTWAP() public {
        // 部署新代币但不添加价格历史
        address newToken = factory.deployMeme(
            "EMPTY2",
            TOTAL_SUPPLY,
            PER_MINT,
            INITIAL_PRICE
        );
        
        // 尝试计算TWAP（应该失败）
        uint256 currentTime = block.timestamp;
        uint256 startTime = currentTime > 1000 ? currentTime - 1000 : 0;
        
        try twapContract.calculateTWAP(
            newToken,
            startTime,
            currentTime
        ) {
            // 如果没有revert，测试失败
            assertTrue(false, "Expected revert but call succeeded");
        } catch Error(string memory reason) {
            // 验证revert原因
            assertEq(reason, "No price history");
        }
    }
    
    /**
     * @dev 测试复杂的交易场景模拟
     * 模拟一个交易日的价格波动
     */
    function testComplexTradingScenario() public {
        uint256 startTime = block.timestamp;
        
        // 等待足够的时间间隔
        vm.warp(startTime + 61);
        
        // 模拟开盘价格
        twapContract.updatePrice(memeToken, 1000); // 9:00 AM
        
        // 模拟早盘上涨
        vm.warp(startTime + 1 * HOUR);
        twapContract.updatePrice(memeToken, 1200); // 10:00 AM
        
        vm.warp(startTime + 2 * HOUR);
        twapContract.updatePrice(memeToken, 1400); // 11:00 AM
        
        // 模拟午盘回调
        vm.warp(startTime + 4 * HOUR);
        twapContract.updatePrice(memeToken, 1100); // 1:00 PM
        
        // 模拟下午反弹
        vm.warp(startTime + 6 * HOUR);
        twapContract.updatePrice(memeToken, 1300); // 3:00 PM
        
        vm.warp(startTime + 7 * HOUR);
        twapContract.updatePrice(memeToken, 1500); // 4:00 PM
        
        // 模拟收盘
        vm.warp(startTime + 8 * HOUR);
        twapContract.updatePrice(memeToken, 1450); // 5:00 PM
        
        // 计算全天TWAP
        uint256 dailyTWAP = twapContract.calculateTWAP(
            memeToken,
            startTime,
            startTime + 8 * HOUR
        );
        
        // 验证TWAP在合理范围内（应该在1000-1500之间）
        assertGt(dailyTWAP, 1000);
        assertLt(dailyTWAP, 1500);
        
        // 计算上午时段TWAP（前4小时）
        uint256 morningTWAP = twapContract.calculateTWAP(
            memeToken,
            startTime,
            startTime + 4 * HOUR
        );
        
        // 计算下午时段TWAP（后4小时）
        uint256 afternoonTWAP = twapContract.calculateTWAP(
            memeToken,
            startTime + 4 * HOUR,
            startTime + 8 * HOUR
        );
        
        // 验证时段TWAP
        assertGt(morningTWAP, 1000);
        assertGt(afternoonTWAP, 1100);
        
        console.log("Daily TWAP:", dailyTWAP);
        console.log("Morning TWAP:", morningTWAP);
        console.log("Afternoon TWAP:", afternoonTWAP);
    }
    
    /**
     * @dev 测试获取价格记录详情
     */
    function testGetPriceRecord() public {
        uint256 testPrice = 1500;
        
        // 等待足够的时间间隔
        vm.warp(block.timestamp + 61);
        uint256 testTime = block.timestamp;
        
        twapContract.updatePrice(memeToken, testPrice);
        
        // 获取第一条记录
        (uint256 price, uint256 timestamp, uint256 cumulativePrice) = 
            twapContract.getPriceRecord(memeToken, 0);
        
        assertEq(price, testPrice);
        assertEq(timestamp, testTime);
        assertEq(cumulativePrice, 0); // 第一条记录的累积价格为0
    }
    
    /**
     * @dev 测试数组长度不匹配的批量更新
     */
    function testBatchUpdateArrayMismatch() public {
        address[] memory tokens = new address[](2);
        uint256[] memory prices = new uint256[](1); // 长度不匹配
        
        tokens[0] = memeToken;
        tokens[1] = memeToken;
        prices[0] = 1500;
        
        vm.expectRevert("Arrays length mismatch");
        twapContract.batchUpdatePrices(tokens, prices);
    }
    
    /**
     * @dev 测试索引越界
     */
    function testIndexOutOfBounds() public {
        // 等待足够的时间间隔
        vm.warp(block.timestamp + 61);
        
        twapContract.updatePrice(memeToken, 1000);
        
        // 尝试访问不存在的索引
        vm.expectRevert("Index out of bounds");
        twapContract.getPriceRecord(memeToken, 1);
    }
}