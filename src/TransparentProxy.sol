// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title StorageSlot 存储槽库
 * @dev 用于管理代理合约中的存储槽，避免存储冲突
 * 通过内联汇编直接操作存储槽，实现精确的存储位置控制
 */
library StorageSlot {
    /**
     * @dev 地址存储槽结构体
     * 用于存储单个地址值
     */
    struct AddressSlot {
        address value;
    }

    /**
     * @dev 获取指定存储槽的地址存储结构
     * @param slot 存储槽的位置（32字节哈希值）
     * @return r 返回指向该存储槽的AddressSlot存储引用
     * 
     * 使用内联汇编直接设置存储槽位置，确保：
     * 1. 避免与代理合约的其他存储变量冲突
     * 2. 实现EIP-1967标准的存储槽布局
     */
    function getAddressSlot(
        bytes32 slot
    ) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot  // 直接设置存储槽位置
        }
    }
}

/**
 * @title Counter 计数器合约（实现合约V1）
 * @dev 这是代理模式中的第一个实现合约
 * 提供基础的计数功能，用于演示代理升级机制
 */
contract Counter {
    uint private counter;  // 计数器状态变量

    /**
     * @dev 构造函数 - 初始化计数器值
     * @param x 初始计数值
     * 注意：在代理模式中，构造函数不会被调用，需要使用init函数
     */
    constructor(uint x) {
        counter = x;
    }

    /**
     * @dev 初始化函数 - 代替构造函数在代理模式中使用
     * @param x 要设置的初始计数值
     * 这个函数在代理合约部署后手动调用，实现初始化逻辑
     */
    function init(uint x) public {
        counter = x;
    }

    /**
     * @dev 增加计数器值
     * @param i 参数未使用，计数器固定增加1
     * 这是V1版本的实现，每次调用只增加1
     */
    function add(uint256 i) public {
        counter += 1;
    }

    /**
     * @dev 获取当前计数器值
     * @return 当前计数器的值
     */
    function get() public view returns(uint) {
        return counter;
    }
}

/**
 * @title CounterV2 计数器合约升级版（实现合约V2）
 * @dev 这是代理模式中的第二个实现合约，演示合约升级
 * 相比V1版本，add函数支持自定义增量
 */
contract CounterV2 {
    uint private counter;  // 计数器状态变量（与V1保持相同的存储布局）

    /**
     * @dev 增加计数器值（升级版）
     * @param i 要增加的数值
     * 这是V2版本的改进：支持按指定数值增加计数器
     */
    function add(uint256 i) public {
        counter += i;
    }

    /**
     * @dev 获取当前计数器值
     * @return 当前计数器的值
     * 与V1版本保持一致的接口
     */
    function get() public view returns(uint) {
        return counter;
    }
}

/**
 * @title TransparentProxy 透明代理合约
 * @dev 实现EIP-1967透明代理模式，支持合约升级功能
 * 
 * 透明代理的核心特性：
 * 1. 管理员调用时执行管理功能（升级合约）
 * 2. 普通用户调用时代理到实现合约
 * 3. 使用标准化存储槽避免存储冲突
 * 4. 支持安全的合约升级机制
 */
contract TransparentProxy  {
    /**
     * @dev EIP-1967标准实现合约存储槽
     * 计算方式：keccak256("eip1967.proxy.implementation") - 1
     * 这个特殊的存储位置确保不会与实现合约的存储变量冲突
     */
    bytes32 private constant IMPLEMENTATION_SLOT =
        bytes32(uint(keccak256("eip1967.proxy.implementation")) - 1);

    /**
     * @dev EIP-1967标准管理员存储槽
     * 计算方式：keccak256("eip1967.proxy.admin") - 1
     * 存储代理合约管理员地址，只有管理员可以升级合约
     */
    bytes32 private constant ADMIN_SLOT =
        bytes32(uint(keccak256("eip1967.proxy.admin")) - 1);
        

    /**
     * @dev 构造函数
     * 透明代理合约的构造函数通常为空
     * 实际的初始化通过设置实现合约和管理员来完成
     */
    constructor() {
        // 可以在这里设置初始的管理员和实现合约
        // 为了演示简单，这里留空
    }

    /**
     * @dev 委托调用核心函数
     * @param _implementation 目标实现合约地址
     * 
     * 使用delegatecall将调用转发到实现合约：
     * 1. 保持当前合约的存储上下文
     * 2. 使用实现合约的代码逻辑
     * 3. msg.sender和msg.value保持不变
     */
    function _delegate(address _implementation) internal virtual {
        assembly {
            // 1. 复制调用数据到内存
            // calldatacopy(destOffset, offset, length)
            calldatacopy(0, 0, calldatasize())
            
            // 2. 执行delegatecall
            // delegatecall(gas, addr, argsOffset, argsLength, retOffset, retLength)
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)
            
            // 3. 复制返回数据到内存
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall失败时返回0
            case 0 {
                // 回滚交易并返回错误数据
                // revert(offset, length) - 结束执行，回滚状态，返回内存数据
                revert(0, returndatasize())
            }
            default {
                // 成功时返回结果数据
                // return(offset, length) - 结束执行，返回内存数据
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev 内部回退函数
     * 将调用委托给当前的实现合约
     * 这是代理模式的核心：所有未匹配的函数调用都会被转发
     */
    function _fallback() private {
        _delegate(_getImplementation());
    }

    /**
     * @dev 回退函数 - 透明代理的核心逻辑
     * 
     * 透明代理的"透明"特性体现在这里：
     * - 如果调用者是管理员：执行管理功能（升级合约）
     * - 如果调用者是普通用户：代理到实现合约
     * 
     * 这种设计避免了函数选择器冲突问题
     */
    fallback() external payable {
        if(msg.sender != _getAdmin()) {
            // 普通用户调用：代理到实现合约
            _fallback();
        } else {
            // 管理员调用：执行升级逻辑
            // 解码调用数据，获取新的实现合约地址和初始化数据
            (address newImplementation, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
            
            // 设置新的实现合约
            _setImplementation(newImplementation);
            
            // 可选：执行初始化调用
            // if (data.length > 0) {
            //     newImplementation.delegatecall(data);
            // }
        }
    }


    /**
     * @dev 接收以太币函数
     * 当合约收到纯以太币转账时（没有调用数据），将调用代理到实现合约
     * 这确保了实现合约可以处理以太币接收逻辑
     */
    receive() external payable {
        _fallback();
    }

    /**
     * @dev 获取当前实现合约地址
     * @return 存储在IMPLEMENTATION_SLOT中的实现合约地址
     * 
     * 从EIP-1967标准存储槽中读取实现合约地址
     */
    function _getImplementation() private view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev 获取代理合约管理员地址
     * @return 存储在ADMIN_SLOT中的管理员地址
     * 
     * 管理员是唯一可以升级实现合约的地址
     */
    function _getAdmin() private view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev 设置新的实现合约地址
     * @param _implementation 新的实现合约地址
     * 
     * 安全检查：
     * 1. 确保新地址是合约（有代码）
     * 2. 更新IMPLEMENTATION_SLOT存储槽
     * 
     * 注意：此函数只能由管理员通过fallback函数调用
     */
    function _setImplementation(address _implementation) private {
        require(_implementation.code.length > 0, "implementation is not contract");
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = _implementation;
    }


}