// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Multicall
 * @dev 支持delegatecall方式的批量调用库
 */
abstract contract Multicall {
    /**
     * @dev 批量调用多个函数（使用delegatecall）
     * @param data 函数调用数据数组
     * @return results 调用结果数组
     */
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results) {
        results = new bytes[](data.length);
        
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            
            if (!success) {
                // 如果调用失败，提取错误信息
                if (result.length < 68) revert("Multicall: call failed");
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }
            
            results[i] = result;
        }
    }
    
    /**
     * @dev 批量调用多个函数，允许部分失败
     * @param data 函数调用数据数组
     * @return successes 成功标志数组
     * @return results 调用结果数组
     */
    function tryMulticall(bytes[] calldata data) 
        external 
        payable 
        returns (bool[] memory successes, bytes[] memory results) 
    {
        successes = new bool[](data.length);
        results = new bytes[](data.length);
        
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            successes[i] = success;
            results[i] = result;
        }
    }
    
    /**
     * @dev 批量调用多个函数，带有gas限制
     * @param data 函数调用数据数组
     * @param gasLimits 每个调用的gas限制数组
     * @return results 调用结果数组
     */
    function multicallWithGasLimit(
        bytes[] calldata data,
        uint256[] calldata gasLimits
    ) external payable returns (bytes[] memory results) {
        require(data.length == gasLimits.length, "Multicall: arrays length mismatch");
        
        results = new bytes[](data.length);
        
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall{gas: gasLimits[i]}(data[i]);
            
            if (!success) {
                if (result.length < 68) revert("Multicall: call failed");
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }
            
            results[i] = result;
        }
    }
    
    /**
     * @dev 获取当前区块时间戳
     * @return timestamp 当前区块时间戳
     */
    function getCurrentBlockTimestamp() external view returns (uint256 timestamp) {
        timestamp = block.timestamp;
    }
    
    /**
     * @dev 获取ETH余额
     * @param addr 地址
     * @return balance ETH余额
     */
    function getEthBalance(address addr) external view returns (uint256 balance) {
        balance = addr.balance;
    }
}