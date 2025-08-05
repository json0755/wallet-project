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
 * @title Counter 计数器合约（UUPS实现合约V1）
 * @dev 这是UUPS代理模式中的第一个实现合约
 * 与透明代理不同，UUPS模式将升级逻辑放在实现合约中
 * 提供基础的计数功能和自升级能力
 */
contract Counter {
    uint private counter;  // 计数器状态变量

    /**
     * @dev EIP-1967标准实现合约存储槽
     * 计算方式：keccak256("eip1967.proxy.implementation") - 1
     * 这个特殊的存储位置确保不会与实现合约的存储变量冲突
     */
    bytes32 private constant IMPLEMENTATION_SLOT =
        bytes32(uint(keccak256("eip1967.proxy.implementation")) - 1);

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

    /**
     * @dev 设置新的实现合约地址（内部函数）
     * @param _implementation 新的实现合约地址
     * 
     * 安全检查：
     * 1. 确保新地址是合约（有代码）
     * 2. 更新IMPLEMENTATION_SLOT存储槽
     */
    function _setImplementation(address _implementation) private {
        require(_implementation.code.length > 0, "implementation is not contract");
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = _implementation;
    }

    /**
     * @dev 升级到新的实现合约（UUPS核心功能）
     * @param _implementation 新的实现合约地址
     * 
     * UUPS模式的关键特性：升级逻辑在实现合约中
     * 这使得每个实现合约都可以控制自己的升级权限
     * 注意：实际应用中应该添加权限控制（如onlyOwner修饰符）
     */
    function upgradeTo(address _implementation) external {
        // 实际应用中应该添加权限检查
        // if (msg.sender != admin) revert();
        _setImplementation(_implementation);
    }
}

/**
 * @title CounterV2 计数器合约升级版（UUPS实现合约V2）
 * @dev 这是UUPS代理模式中的第二个实现合约，演示合约升级
 * 相比V1版本，add函数支持自定义增量
 * 注意：V2版本没有upgradeTo函数，这意味着升级到V2后无法再次升级
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

    // 注意：V2版本故意没有包含upgradeTo函数
    // 这演示了UUPS模式的一个重要特性：
    // 如果新的实现合约没有升级函数，合约将无法再次升级
}

/**
 * @title UUPSProxy UUPS代理合约
 * @dev 实现EIP-1967 UUPS（Universal Upgradeable Proxy Standard）代理模式
 * 
 * UUPS代理的核心特性：
 * 1. 代理合约只负责委托调用和存储实现合约地址
 * 2. 升级逻辑位于实现合约中，而不是代理合约中
 * 3. 比透明代理更节省gas，因为没有管理员检查逻辑
 * 4. 实现合约必须包含升级函数才能支持升级
 */
contract UUPSProxy  {
    /**
     * @dev EIP-1967标准实现合约存储槽
     * 计算方式：keccak256("eip1967.proxy.implementation") - 1
     * 这个特殊的存储位置确保不会与实现合约的存储变量冲突
     */
    bytes32 private constant IMPLEMENTATION_SLOT =
        bytes32(uint(keccak256("eip1967.proxy.implementation")) - 1);

    /**
     * @dev 构造函数 - 初始化代理合约
     * @param impl 初始实现合约地址
     * 
     * 在部署时设置第一个实现合约地址
     * 后续升级将通过实现合约的upgradeTo函数进行
     */
    constructor(address impl) {
        _setImplementation(impl);
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
     * @dev 回退函数 - UUPS代理的核心逻辑
     * 
     * 与透明代理不同，UUPS代理的fallback函数非常简单：
     * - 所有调用都直接代理到实现合约
     * - 没有管理员检查逻辑，因此gas消耗更低
     * - 升级逻辑由实现合约自己处理
     */
    fallback() external payable {
        _fallback();
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
     * @dev 设置新的实现合约地址
     * @param _implementation 新的实现合约地址
     * 
     * 安全检查：
     * 1. 确保新地址是合约（有代码）
     * 2. 更新IMPLEMENTATION_SLOT存储槽
     * 
     * 注意：在UUPS模式中，这个函数只在构造函数中调用
     * 后续的升级通过实现合约的upgradeTo函数进行
     */
    function _setImplementation(address _implementation) private {
        require(_implementation.code.length > 0, "implementation is not contract");
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = _implementation;
    }
}