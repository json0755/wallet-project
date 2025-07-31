// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ContractA {
    uint256 public counter;           // 参数2：counter (必须放在第一个slot以匹配ContractB)
    address public externalContract;  // 参数1：指向外面合约的地址
    
    constructor(address _externalContract) {
        externalContract = _externalContract;
        counter = 0;
    }
    
    // 通过delegatecall调用B合约的increment方法
    function delegateCallIncrement() public {
        (bool success, ) = externalContract.delegatecall(
            abi.encodeWithSignature("increment()")
        );
        require(success, "Delegatecall failed");
    }
    
    // 获取当前counter值
    function getCounter() public view returns (uint256) {
        return counter;
    }
    
    // 设置外部合约地址
    function setExternalContract(address _externalContract) public {
        externalContract = _externalContract;
    }
    
    // 直接调用外部合约的increment方法（用于对比）
    function normalCallIncrement() public {
        (bool success, ) = externalContract.call(
            abi.encodeWithSignature("increment()")
        );
        require(success, "Call failed");
    }
}