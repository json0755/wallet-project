// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";



// 1.编写一个 Vesting 合约（可参考 OpenZepplin Vesting 相关合约）， 相关的参数有：
// beneficiary： 受益人
// 锁定的 ERC20 地址
// Cliff：12 个月
// 2.线性释放：接下来的 24 个月，从 第 13 个月起开始每月解锁 1/24 的 ERC20
// 3.Vesting 合约包含的方法 release() 用来释放当前解锁的 ERC20 给受益人，Vesting 合约部署后，开始计算 Cliff ，并转入 100 万 ERC20 资产。

/**
 * @title TokenVesting
 * @dev 代币线性释放合约
 * @notice 该合约实现了12个月cliff期 + 24个月线性释放的代币锁定机制
 */
contract TokenVesting {
    // ============ 事件定义 ============
    event Released(address indexed beneficiary, uint256 amount);
    
    // ============ 状态变量 ============
    // 受益人地址（不可变）
    address public immutable beneficiary;
    
    // 锁定的ERC20代币地址（不可变）
    IERC20 public immutable token;
    
    // 合约部署时间，作为cliff和释放周期的起始点（不可变）
    uint256 public immutable startTime;
    
    // 已释放给受益人的代币总量
    uint256 public released;
    
    // ============ 常量定义 ============
    // 总锁定代币数量：100万枚（假设代币有18位小数）
    uint256 public constant TOTAL_VESTED_AMOUNT = 1_000_000 * 10**18;
    
    // Cliff期：12个月（按每月30天计算）
    uint256 public constant CLIFF_DURATION = 12 * 30 * 24 * 60 * 60;
    
    // 线性释放期：24个月
    uint256 public constant VESTING_DURATION = 24 * 30 * 24 * 60 * 60;
    
    // 释放开始延迟：等于cliff期（第13个月开始释放）
    uint256 public constant VESTING_START_DELAY = CLIFF_DURATION;
    
    // 每月解锁比例：1/24
    uint256 public constant MONTHLY_UNLOCK_FRACTION = 24;
    
    // 每月时长（秒）
    uint256 public constant MONTH_DURATION = 30 * 24 * 60 * 60;
    
    // ============ 构造函数 ============
    /**
     * @dev 构造函数
     * @param _beneficiary 受益人地址
     * @param _token 锁定的ERC20代币地址
     * @notice 部署时需要确保部署者已经授权足够的代币给合约
     */
    constructor(address _beneficiary, IERC20 _token) {
        require(_beneficiary != address(0), "TokenVesting: beneficiary is zero address");
        require(address(_token) != address(0), "TokenVesting: token is zero address");
        
        beneficiary = _beneficiary;
        token = _token;
        startTime = block.timestamp;
        
        // 从部署者转入100万枚代币到合约
        bool success = _token.transferFrom(msg.sender, address(this), TOTAL_VESTED_AMOUNT);
        require(success, "TokenVesting: token transfer failed");
    }
    
    // ============ 外部函数 ============
    /**
     * @dev 释放当前可解锁的代币给受益人
     * @notice 任何人都可以调用此函数来触发代币释放
     */
    function release() external {
        uint256 totalReleasable = _calculateReleasable();
        uint256 amountToRelease = totalReleasable - released;
        
        require(amountToRelease > 0, "TokenVesting: no tokens to release");
        
        // 更新已释放数量
        released = totalReleasable;
        
        // 转账给受益人
        bool success = token.transfer(beneficiary, amountToRelease);
        require(success, "TokenVesting: token transfer failed");
        
        // 触发事件
        emit Released(beneficiary, amountToRelease);
    }
    
    // ============ 查询函数 ============
    /**
     * @dev 查询当前可释放的代币数量（未扣除已释放部分）
     * @return 当前累计可释放的代币总量
     */
    function getReleasableAmount() external view returns (uint256) {
        return _calculateReleasable() - released;
    }
    
    /**
     * @dev 查询剩余锁定的代币数量
     * @return 剩余锁定的代币数量
     */
    function getRemainingAmount() external view returns (uint256) {
        return TOTAL_VESTED_AMOUNT - released;
    }
    
    /**
     * @dev 查询cliff结束时间
     * @return cliff结束的时间戳
     */
    function getCliffEndTime() external view returns (uint256) {
        return startTime + CLIFF_DURATION;
    }
    
    /**
     * @dev 查询完全释放时间
     * @return 所有代币释放完毕的时间戳
     */
    function getVestingEndTime() external view returns (uint256) {
        return startTime + CLIFF_DURATION + VESTING_DURATION;
    }
    
    // ============ 内部函数 ============
    /**
     * @dev 计算当前累计可释放的代币总量
     * @return 当前累计可释放的代币数量
     */
    function _calculateReleasable() internal view returns (uint256) {
        uint256 currentTime = block.timestamp;
        
        // 如果还在cliff期内，无法释放任何代币
        if (currentTime < startTime + CLIFF_DURATION) {
            return 0;
        }
        
        // 如果已经过了完整的释放期，释放全部代币
        if (currentTime >= startTime + CLIFF_DURATION + VESTING_DURATION) {
            return TOTAL_VESTED_AMOUNT;
        }
        
        // 计算从cliff结束到当前时间的时长
        uint256 timeFromCliffEnd = currentTime - (startTime + CLIFF_DURATION);
        
        // 计算已过的完整月数
        uint256 monthsPassed = timeFromCliffEnd / MONTH_DURATION;
        
        // 确保不超过24个月
        if (monthsPassed > MONTHLY_UNLOCK_FRACTION) {
            monthsPassed = MONTHLY_UNLOCK_FRACTION;
        }
        
        // 计算可释放金额：已过月数 / 24 * 总金额
        return (TOTAL_VESTED_AMOUNT * monthsPassed) / MONTHLY_UNLOCK_FRACTION;
    }
}