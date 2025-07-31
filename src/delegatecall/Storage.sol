// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Storage
 * @dev 存储合约，包含基本的存储逻辑
 */
contract Storage {
    uint256 public value;
    address public owner;
    
    event ValueChanged(uint256 newValue, address changedBy);
    
    /**
     * @dev 设置值
     * @param _value 要设置的新值
     */
    function setValue(uint256 _value) public {
        value = _value;
        owner = msg.sender;
        emit ValueChanged(_value, msg.sender);
    }
    
    /**
     * @dev 获取当前值
     * @return 当前存储的值
     */
    function getValue() public view returns (uint256) {
        return value;
    }
    
    /**
     * @dev 增加值
     * @param _amount 要增加的数量
     */
    function addValue(uint256 _amount) public {
        value += _amount;
        owner = msg.sender;
        emit ValueChanged(value, msg.sender);
    }
}