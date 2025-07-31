// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Proxy
 * @dev 代理合约，演示delegatecall的用法
 */
contract Proxy {
    uint256 public value;  // 注意：存储布局必须与Storage合约相同
    address public owner;
    
    address public implementation;  // 实现合约地址
    
    event DelegateCallExecuted(address target, bytes data, bool success);
    
    constructor(address _implementation) {
        implementation = _implementation;
    }
    
    /**
     * @dev 通过delegatecall调用实现合约的setValue函数
     * @param _value 要设置的新值
     */
    function setValueViaDelegateCall(uint256 _value) public {
        // 编码函数调用数据
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", _value);
        
        // 使用delegatecall调用实现合约
        (bool success, ) = implementation.delegatecall(data);
        require(success, "Delegatecall failed");
        
        emit DelegateCallExecuted(implementation, data, success);
    }
    
    /**
     * @dev 通过delegatecall调用实现合约的addValue函数
     * @param _amount 要增加的数量
     */
    function addValueViaDelegateCall(uint256 _amount) public {
        bytes memory data = abi.encodeWithSignature("addValue(uint256)", _amount);
        
        (bool success, ) = implementation.delegatecall(data);
        require(success, "Delegatecall failed");
        
        emit DelegateCallExecuted(implementation, data, success);
    }
    
    /**
     * @dev 通用的delegatecall函数
     * @param data 要执行的函数调用数据
     */
    function delegateCallToImplementation(bytes memory data) public returns (bool success, bytes memory returnData) {
        (success, returnData) = implementation.delegatecall(data);
        emit DelegateCallExecuted(implementation, data, success);
    }
    
    /**
     * @dev 更新实现合约地址
     * @param _newImplementation 新的实现合约地址
     */
    function updateImplementation(address _newImplementation) public {
        require(_newImplementation != address(0), "Invalid implementation address");
        implementation = _newImplementation;
    }
    
    /**
     * @dev 获取当前值（直接从本合约存储读取）
     * @return 当前存储的值
     */
    function getValue() public view returns (uint256) {
        return value;
    }
    
    /**
     * @dev 获取当前所有者（直接从本合约存储读取）
     * @return 当前所有者地址
     */
    function getOwner() public view returns (address) {
        return owner;
    }
}