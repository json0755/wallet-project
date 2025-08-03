#!/bin/bash
set -e
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1
echo "🚀 开始初始化 EIP2612 TokenBank 测试环境..."

# 设置anvil账户地址变量
export ADMIN_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
export USER1_ADDRESS="0x70997970c51812dc3a010c7d01b50e0d17dc79c8"
export USER2_ADDRESS="0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc"
export USER3_ADDRESS="0x90f79bf6eb2c4f870365e785982e1f101e93b906"

# 设置anvil默认私钥
export ADMIN_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" #pragma: allowlist secret
export USER1_PRIVATE_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" #pragma: allowlist secret
export USER2_PRIVATE_KEY="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" #pragma: allowlist secret
export USER3_PRIVATE_KEY="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6" #pragma: allowlist secret

echo "📋 账户信息:"
echo "  Admin: $ADMIN_ADDRESS"
echo "  User1: $USER1_ADDRESS"
echo "  User2: $USER2_ADDRESS"
echo "  User3: $USER3_ADDRESS"

# 1. 检查anvil是否运行
echo "🔧 检查anvil是否运行..."
if ! pgrep -f anvil > /dev/null; then
    echo "⚠️  Anvil未运行，请先启动anvil:"
    echo "   anvil --host 0.0.0.0 --port 8545"
    exit 1
fi
echo "✅ Anvil已运行"

# 2. 编译合约
echo "🔨 编译合约..."
forge build
if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi
echo "✅ 编译成功"

# 3. 部署合约
echo "📦 部署Permit2合约..."
PERMIT2_BYTECODE=$(forge inspect src/tokenbank/Permit2.sol:Permit2 bytecode)
echo "🔧 执行部署命令..."
PERMIT2_OUTPUT=$(cast send --rpc-url http://127.0.0.1:8545 \
    --private-key $ADMIN_PRIVATE_KEY \
    --create $PERMIT2_BYTECODE 2>&1 | tee /dev/stderr)
export PERMIT2_ADDRESS=$(echo "$PERMIT2_OUTPUT" | grep "contractAddress" | awk '{print $2}')
echo "✅ Permit2合约部署到: $PERMIT2_ADDRESS"

echo "📦 部署EIP2612Token合约..."
TOKEN_BYTECODE=$(forge inspect src/tokenbank/EIP2612Token.sol:EIP2612Token bytecode)
TOKEN_CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(string,string,uint256,uint8,uint256)" "EIP2612 Test Token" "E2612" 1000000 18 0)
echo "🔧 执行部署命令..."
TOKEN_OUTPUT=$(cast send --rpc-url http://127.0.0.1:8545 \
    --private-key $ADMIN_PRIVATE_KEY \
    --create ${TOKEN_BYTECODE}${TOKEN_CONSTRUCTOR_ARGS:2} 2>&1 | tee /dev/stderr)
export TOKEN_ADDRESS=$(echo "$TOKEN_OUTPUT" | grep "contractAddress" | awk '{print $2}')
echo "✅ EIP2612Token合约部署到: $TOKEN_ADDRESS"

echo "🏦 部署EIP2612TokenBank合约..."
TOKENBANK_BYTECODE=$(forge inspect src/tokenbank/EIP2612TokenBank.sol:EIP2612TokenBank bytecode)
TOKENBANK_CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,address)" $TOKEN_ADDRESS $PERMIT2_ADDRESS)
echo "🔧 执行部署命令..."
TOKENBANK_OUTPUT=$(cast send --rpc-url http://127.0.0.1:8545 \
    --private-key $ADMIN_PRIVATE_KEY \
    --create ${TOKENBANK_BYTECODE}${TOKENBANK_CONSTRUCTOR_ARGS:2} 2>&1 | tee /dev/stderr)
export TOKENBANK_ADDRESS=$(echo "$TOKENBANK_OUTPUT" | grep "contractAddress" | awk '{print $2}')
echo "✅ EIP2612TokenBank合约部署到: $TOKENBANK_ADDRESS"

# 4. 代币分发
echo "💸 Admin给用户分发代币..."

# 给User1转账10000个token
cast send --rpc-url http://127.0.0.1:8545 \
    --private-key $ADMIN_PRIVATE_KEY \
    $TOKEN_ADDRESS \
    "transfer(address,uint256)" \
    $USER1_ADDRESS \
    "10000000000000000000000"
echo "✅ User1获得10000个token"

# 给User2转账5000个token
cast send --rpc-url http://127.0.0.1:8545 \
    --private-key $ADMIN_PRIVATE_KEY \
    $TOKEN_ADDRESS \
    "transfer(address,uint256)" \
    $USER2_ADDRESS \
    "5000000000000000000000"
echo "✅ User2获得5000个token"

# 给User3转账2000个token
cast send --rpc-url http://127.0.0.1:8545 \
    --private-key $ADMIN_PRIVATE_KEY \
    $TOKEN_ADDRESS \
    "transfer(address,uint256)" \
    $USER3_ADDRESS \
    "2000000000000000000000"
echo "✅ User3获得2000个token"

# 5. 基本测试
echo "🔍 测试基本vault操作..."

# User1存入1000个token到vault
cast send --rpc-url http://127.0.0.1:8545 \
    --private-key $USER1_PRIVATE_KEY \
    $TOKEN_ADDRESS \
    "approve(address,uint256)" \
    $TOKENBANK_ADDRESS \
    "1000000000000000000000"
echo "✅ User1授权TokenBank 1000个token"

cast send --rpc-url http://127.0.0.1:8545 \
    --private-key $USER1_PRIVATE_KEY \
    $TOKENBANK_ADDRESS \
    "deposit(uint256,address)" \
    "1000000000000000000000" \
    $USER1_ADDRESS
echo "✅ User1存入1000个token到vault"

# User2授权Permit2合约
cast send --rpc-url http://127.0.0.1:8545 \
    --private-key $USER2_PRIVATE_KEY \
    $TOKEN_ADDRESS \
    "approve(address,uint256)" \
    $PERMIT2_ADDRESS \
    "1000000000000000000000"
echo "✅ User2授权Permit2合约 1000个token"

# 6. 签名生成函数
generate_eip2612_permit() {
    local token_address=$1
    local owner_private_key=$2
    local spender_address=$3
    local value=$4
    local deadline=${5:-$(($(date +%s) + 3600))}
    
    echo "📝 生成EIP2612 permit签名参数..."
    local owner_address=$(cast wallet address --private-key $owner_private_key)
    local nonce=$(cast call --rpc-url http://127.0.0.1:8545 \
        $token_address \
        "nonces(address)(uint256)" \
        $owner_address)
    
    echo "  Token: $token_address"
    echo "  Owner: $owner_address"
    echo "  Spender: $spender_address"
    echo "  Value: $value"
    echo "  Nonce: $nonce"
    echo "  Deadline: $deadline"
    echo "  Domain: {name: 'EIP2612 Test Token', version: '1', chainId: 31337, verifyingContract: '$token_address'}"
}

generate_permit2_signature() {
    local permit2_address=$1
    local owner_private_key=$2
    local token_address=$3
    local amount=$4
    local spender_address=$5
    local deadline=${6:-$(($(date +%s) + 3600))}
    
    echo "📝 生成Permit2签名参数..."
    local owner_address=$(cast wallet address --private-key $owner_private_key)
    
    echo "  Permit2: $permit2_address"
    echo "  Token: $token_address"
    echo "  Owner: $owner_address"
    echo "  Amount: $amount"
    echo "  Spender: $spender_address"
    echo "  Deadline: $deadline"
    echo "  Domain: {name: 'Permit2', version: '1', chainId: 31337, verifyingContract: '$permit2_address'}"
}

# 7. 演示签名生成
echo ""
echo "🧪 演示签名生成..."
echo "示例1: User2授权User3转移1000个token (EIP2612)"
generate_eip2612_permit $TOKEN_ADDRESS $USER2_PRIVATE_KEY $USER3_ADDRESS "1000000000000000000000"

echo ""
echo "示例2: User2通过Permit2转移800个token给User3"
generate_permit2_signature $PERMIT2_ADDRESS $USER2_PRIVATE_KEY $TOKEN_ADDRESS "800000000000000000000" $USER3_ADDRESS

# 8. 验证最终状态
echo ""
echo "🔍 验证最终状态..."
echo "📊 Token余额:"
for user in "ADMIN" "USER1" "USER2" "USER3"; do
    user_addr_var="${user}_ADDRESS"
    user_addr=${!user_addr_var}
    balance=$(cast call --rpc-url http://127.0.0.1:8545 \
        $TOKEN_ADDRESS \
        "balanceOf(address)(uint256)" \
        $user_addr)
    echo "  $user: $balance"
done

echo ""
echo "🎉 EIP2612 TokenBank 完整测试环境部署完成！"
echo ""
echo "📋 合约地址:"
echo "  Permit2: $PERMIT2_ADDRESS"
echo "  EIP2612Token: $TOKEN_ADDRESS"
echo "  EIP2612TokenBank: $TOKENBANK_ADDRESS"
echo ""
echo "💡 可用函数:"
echo "  generate_eip2612_permit <token> <owner_key> <spender> <value> [deadline]"
echo "  generate_permit2_signature <permit2> <owner_key> <token> <amount> <spender> [deadline]"
echo ""
echo "📚 使用示例:"
echo "  generate_eip2612_permit $TOKEN_ADDRESS $USER2_PRIVATE_KEY $USER3_ADDRESS 1000000000000000000000"
echo "  generate_permit2_signature $PERMIT2_ADDRESS $USER2_PRIVATE_KEY $TOKEN_ADDRESS 800000000000000000000 $USER3_ADDRESS"