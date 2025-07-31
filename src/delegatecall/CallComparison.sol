// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CallComparison
 * @dev 对比call和delegatecall的区别
 */
contract CallComparison {
    uint256 public value;
    address public owner;
    address public lastCaller;
    
    address public targetContract;
    
    event CallExecuted(string callType, address target, bool success);
    event StateChanged(uint256 newValue, address newOwner, address caller);
    
    constructor(address _targetContract) {
        targetContract = _targetContract;
    }
    
    /**
     * @dev 使用普通call调用目标合约
     * @param _value 要设置的值
     */
    function useCall(uint256 _value) public {
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", _value);
        
        (bool success, ) = targetContract.call(data);
        require(success, "Call failed");
        
        lastCaller = msg.sender;
        emit CallExecuted("call", targetContract, success);
        emit StateChanged(value, owner, msg.sender);
    }
    
    /**
     * @dev 使用delegatecall调用目标合约
     * @param _value 要设置的值
     */
    function useDelegateCall(uint256 _value) public {
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", _value);
        
        (bool success, ) = targetContract.delegatecall(data);
        require(success, "Delegatecall failed");
        
        lastCaller = msg.sender;
        emit CallExecuted("delegatecall", targetContract, success);
        emit StateChanged(value, owner, msg.sender);
    }
    
    /**
     * @dev 获取当前状态
     * @return _value 当前值
     * @return _owner 当前所有者
     * @return _lastCaller 最后调用者
     */
    function getCurrentState() public view returns (uint256 _value, address _owner, address _lastCaller) {
        return (value, owner, lastCaller);
    }
    
    /**
     * @dev 重置状态
     */
    function resetState() public {
        value = 0;
        owner = address(0);
        lastCaller = address(0);
    }
}