// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Delegate
 * @dev 支持EIP7702的批量执行合约
 * @notice 该合约可以被EOA账户指定，用于批量执行多个合约调用
 */
contract Delegate {
    // 调用结构体
    struct Call {
        address target;   // 目标合约地址
        uint256 value;    // 发送的ETH数量
        bytes data;       // 调用数据
    }

    // 事件定义
    event Initialized(address indexed account);
    event BatchExecuted(address indexed executor, uint256 callCount);
    event CallExecuted(address indexed target, uint256 value, bool success);
    event CallFailed(address indexed target, uint256 value, bytes reason);

    // 状态变量
    bool public initialized;
    address public owner;
    
    // 错误定义
    error AlreadyInitialized();
    error NotInitialized();
    error BatchCallFailed(uint256 index, bytes reason);
    error InsufficientBalance();
    error InvalidCall();

    /**
     * @dev 初始化函数，用于EIP7702合约指定后的初始化
     * @notice 只能调用一次，设置合约所有者
     */
    function initialize() external payable {
        if (initialized) {
            revert AlreadyInitialized();
        }
        
        initialized = true;
        owner = msg.sender;
        
        emit Initialized(msg.sender);
    }

    /**
     * @dev 批量执行多个合约调用
     * @param calls 要执行的调用数组
     * @notice 所有调用必须成功，否则整个交易回滚
     */
    function batchExecute(Call[] calldata calls) external payable {
        if (!initialized) {
            revert NotInitialized();
        }
        
        uint256 totalValue = 0;
        uint256 callCount = calls.length;
        
        // 计算总的ETH需求
        for (uint256 i = 0; i < callCount; i++) {
            totalValue += calls[i].value;
        }
        
        // 检查余额是否足够
        if (address(this).balance < totalValue) {
            revert InsufficientBalance();
        }
        
        // 执行所有调用
        for (uint256 i = 0; i < callCount; i++) {
            Call calldata call = calls[i];
            
            // 验证调用参数
            if (call.target == address(0)) {
                revert InvalidCall();
            }
            
            // 执行调用
            (bool success, bytes memory result) = call.target.call{value: call.value}(call.data);
            
            if (success) {
                emit CallExecuted(call.target, call.value, true);
            } else {
                emit CallFailed(call.target, call.value, result);
                revert BatchCallFailed(i, result);
            }
        }
        
        emit BatchExecuted(msg.sender, callCount);
    }

    /**
     * @dev 仅所有者可执行的批量调用（额外的权限控制）
     * @param calls 要执行的调用数组
     */
    function batchExecuteOwnerOnly(Call[] calldata calls) external payable {
        if (!initialized) {
            revert NotInitialized();
        }
        
        require(msg.sender == owner, "Only owner can execute");
        
        uint256 totalValue = 0;
        uint256 callCount = calls.length;
        
        // 计算总的ETH需求
        for (uint256 i = 0; i < callCount; i++) {
            totalValue += calls[i].value;
        }
        
        // 检查余额是否足够
        if (address(this).balance < totalValue) {
            revert InsufficientBalance();
        }
        
        // 执行所有调用
        for (uint256 i = 0; i < callCount; i++) {
            Call calldata call = calls[i];
            
            // 验证调用参数
            if (call.target == address(0)) {
                revert InvalidCall();
            }
            
            // 执行调用
            (bool success, bytes memory result) = call.target.call{value: call.value}(call.data);
            
            if (success) {
                emit CallExecuted(call.target, call.value, true);
            } else {
                emit CallFailed(call.target, call.value, result);
                revert BatchCallFailed(i, result);
            }
        }
        
        emit BatchExecuted(msg.sender, callCount);
    }

    /**
     * @dev 获取合约状态信息
     * @return _initialized 是否已初始化
     * @return _owner 所有者地址
     * @return _balance 合约ETH余额
     */
    function getInfo() external view returns (bool _initialized, address _owner, uint256 _balance) {
        return (initialized, owner, address(this).balance);
    }

    /**
     * @dev 接收ETH
     */
    receive() external payable {}
    
    /**
     * @dev 回退函数
     */
    fallback() external payable {}
}