# DelegateCall 演示

这个演示展示了 `delegatecall` 和普通 `call` 的区别，特别是在状态修改方面的不同行为。

## 文件结构

- `ContractA.sol` - 调用方合约，包含两个storage参数
- `ContractB.sol` - 被调用方合约，包含increment方法
- `../test/CallDemo.t.sol` - 测试文件，演示不同调用方式的效果

## 合约说明

### ContractA
- **storage参数1**: `externalContract` - 指向外部合约的地址
- **storage参数2**: `counter` - 计数器
- **delegateCallIncrement()** - 通过delegatecall调用B合约的increment方法
- **normalCallIncrement()** - 通过普通call调用B合约的increment方法

### ContractB
- **storage参数**: `counter` - 计数器
- **increment()** - 让counter自增的方法

## 核心概念

### DelegateCall vs Call

1. **DelegateCall**:
   - 执行被调用合约的代码
   - 但是修改的是**调用方合约**的storage
   - 上下文（msg.sender, msg.value等）保持为原始调用者

2. **Call**:
   - 执行被调用合约的代码
   - 修改的是**被调用合约**的storage
   - 上下文切换到被调用合约

## 演示结果

当ContractA通过`delegatecall`调用ContractB的`increment()`方法时：
- ContractA的`counter`会增加
- ContractB的`counter`保持不变

当ContractA通过普通`call`调用ContractB的`increment()`方法时：
- ContractA的`counter`保持不变
- ContractB的`counter`会增加

## 运行测试

```bash
# 运行所有测试
forge test --match-contract CallDemoTest -vv

# 运行特定测试
forge test --match-test testDelegateCallIncrement -vv
```

## 测试用例

1. **testDelegateCallIncrement** - 测试delegatecall的基本功能
2. **testNormalCallIncrement** - 测试普通call的行为
3. **testMultipleDelegateCalls** - 测试多次delegatecall
4. **testMixedCalls** - 测试混合使用两种调用方式

## 关键学习点

1. **Storage布局一致性**: 
   - delegatecall要求调用方和被调用方的storage布局兼容
   - ContractA的`counter`必须在第一个storage slot，以匹配ContractB的布局
   - 如果布局不匹配，delegatecall会修改错误的storage slot

2. **执行上下文**: delegatecall保持原始调用者的上下文
3. **状态修改位置**: delegatecall修改调用方的状态，call修改被调用方的状态
4. **安全考虑**: delegatecall可能导致意外的状态修改，需要谨慎使用

## 实际应用场景

- **代理模式**: 升级合约逻辑而保持状态
- **库合约**: 复用代码逻辑
- **钻石模式**: 模块化合约架构

## 注意事项

⚠️ **安全警告**: 
- 确保storage布局兼容
- 验证被调用合约的安全性
- 注意权限控制
- 防止重入攻击