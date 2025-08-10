// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; // 指定Solidity编译器版本为0.8.0及以上

import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // 引入OpenZeppelin的ERC20实现（用于LP代币）
import "@openzeppelin/contracts/utils/math/Math.sol"; // 引入数学工具库（用于最小值计算）
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // 引入ERC20接口（用于与外部代币交互）

// fork from https://github.com/monokh/looneyswap // 源代码参考：LooneySwap 的简单AMM示例

// Tom：1  MSP  // 示例：Tom持有1个LP代币（MSP）
// Bob: 2 MSP  // 示例：Bob持有2个LP代币（MSP）
// Alice: 3 MSP  // 示例：Alice持有3个LP代币（MSP）


// 10100 reserve0  Token0 // 示例：Token0的储备为10100
// 6060  reserve1  Token1 // 示例：Token1的储备为6060

contract MiniSwapPool is ERC20 { // 定义MiniSwapPool合约，继承ERC20用于发行LP代币
    address public token0; // 代币0的合约地址
    address public token1; // 代币1的合约地址

    // Reserve of token 0 // token0的储备量
    uint public reserve0; // 储备量：token0

    // Reserve of token 1 // token1的储备量
    uint public reserve1; // 储备量：token1

    uint public constant INITIAL_SUPPLY = 10**5; // 初始LP总量常量（首次添加流动性时铸造给提供者）

    constructor(address _token0, address _token1, string memory name, string memory symbol) ERC20(name, symbol) { // 构造函数：初始化代币地址与LP代币名称和符号
        token0 = _token0; // 设置token0地址
        token1 = _token1; // 设置token1地址
    }

    /**
    * Adds liquidity to the pool. // 添加流动性到资金池
    * 1. Transfer tokens to pool // 1. 将两种代币从用户转入池子
    * 2. Emit LP tokens // 2. 给用户铸造LP代币
    * 3. Update reserves // 3. 更新储备量
    */
    function addLiquidity(uint amount0, uint amount1) public { // 添加流动性函数：传入两种代币的数量
        assert(IERC20(token0).transferFrom(msg.sender, address(this), amount0)); // 从调用者转入amount0数量的token0
        assert(IERC20(token1).transferFrom(msg.sender, address(this), amount1)); // 从调用者转入amount1数量的token1

        uint reserve0After = reserve0 + amount0; // 计算添加后的token0储备
        uint reserve1After = reserve1 + amount1; // 计算添加后的token1储备

        if (reserve0 == 0 && reserve1 == 0) { // 如果是第一次添加流动性（储备为0）
            _mint(msg.sender, INITIAL_SUPPLY); // 铸造初始LP代币给提供者
        } else { // 否则为增量添加流动性
            uint currentSupply = totalSupply(); // 当前LP代币总量

            uint newSupplyGivenReserve0Ratio = reserve0After * currentSupply / reserve0; // 基于token0比例推导的新LP总量
            uint newSupplyGivenReserve1Ratio = reserve1After * currentSupply / reserve1; // 基于token1比例推导的新LP总量
            uint newSupply = Math.min(newSupplyGivenReserve0Ratio, newSupplyGivenReserve1Ratio); // 取两者较小值，防止不等比例注入导致套利
            _mint(msg.sender, newSupply - currentSupply); // 给提供者铸造新增LP份额（差值）
        }

        reserve0 = reserve0After; // 更新token0储备
        reserve1 = reserve1After; // 更新token1储备
    }

    /**
    * Removes liquidity from the pool. // 从池子中移除流动性
    * 1. Transfer LP tokens to pool // 1. 将LP代币转到池子合约
    * 2. Burn the LP tokens // 2. 销毁LP代币
    * 3. Update reserves // 3. 更新储备并把对应代币退还给用户
    */
    function remove(uint liquidity) public { // 移除流动性函数：传入要赎回的LP数量
        assert(transfer(address(this), liquidity)); // 将liquidity数量的LP代币从用户转到合约自身

        uint currentSupply = totalSupply(); // 当前LP总量

        // 10 lp token  ; total 100; // 示例：10个LP，总量100，按比例计算赎回量
        uint amount0 = liquidity * reserve0 / currentSupply; // 按比例计算可赎回的token0数量
        uint amount1 = liquidity * reserve1 / currentSupply; // 按比例计算可赎回的token1数量

        _burn(address(this), liquidity);    //  1 MSP // 销毁从用户转入的LP代币

        assert(IERC20(token0).transfer(msg.sender, amount0)); // 将token0退还给用户
        assert(IERC20(token1).transfer(msg.sender, amount1)); // 将token1退还给用户
        reserve0 = reserve0 - amount0; // 更新token0储备
        reserve1 = reserve1 - amount1; // 更新token1储备
    }

    /**
    * Uses x * y = k formula to calculate output amount. // 使用常积公式x*y=k计算输出数量
    * 1. Calculate new reserve on both sides // 1. 计算输入后的新储备
    * 2. Derive output amount // 2. 得到输出数量
    */
    function getAmountOut (uint amountIn, address fromToken) public view returns (uint amountOut, uint _reserve0, uint _reserve1) { // 视图函数：根据输入数量与方向计算可得的输出与新储备
        uint newReserve0; // 交换后的token0新储备
        uint newReserve1; // 交换后的token1新储备
        uint k = reserve0 * reserve1; // 常数乘积k（不含手续费的理想模型）

        // x (reserve0) * y (reserve1) = k (constant) // x*y=k常数乘积模型
        // (reserve0 + amountIn) * (reserve1 - amountOut) = k // 输入后仍需满足常积不变
        // (reserve1 - amountOut) = k / (reserve0 + amount) // 推导输出侧新储备
        // newReserve1 = k / (newReserve0) // 根据一侧新储备推导另一侧新储备
        // amountOut = newReserve1 - reserve1 // 计算输出量（注意方向符号）

        if (fromToken == token0) { // 如果输入的是token0
            newReserve0 = amountIn + reserve0; // 输入后token0储备增加
            newReserve1 = k / newReserve0; // 由常积推导token1的新储备
            amountOut = reserve1 - newReserve1; // 可输出的token1数量
        } else { // 否则输入的是token1
            newReserve1 = amountIn + reserve1; // 输入后token1储备增加
            newReserve0 = k / newReserve1; // 由常积推导token0的新储备
            amountOut = reserve0 - newReserve0; // 可输出的token0数量
        }

        _reserve0 = newReserve0; // 返回新储备0
        _reserve1 = newReserve1; // 返回新储备1
    }

    /**
    * Swap to a minimum of `minAmountOut` // 进行交换并保证至少得到minAmountOut
    * 1. Calculate new reserve on both sides // 1. 计算新储备与输出量
    * 2. Derive output amount // 2. 根据常积关系推导输出
    * 3. Check output against minimum requested // 3. 检查滑点（最小输出）
    * 4. Update reserves // 4. 完成交互并更新储备
    */
    function swap(uint amountIn, uint minAmountOut, address fromToken, address toToken, address to) public { // 交换函数：从fromToken换到toToken
        require(amountIn > 0 && minAmountOut > 0, "Amount invalid"); // 校验输入与最小输出必须大于0
        require(fromToken == token0 || fromToken == token1, "From token invalid"); // 校验输入代币必须是池子支持的其中之一
        require(toToken == token0 || toToken == token1, "To token invalid"); // 校验输出代币必须是池子支持的其中之一
        require(fromToken != toToken, "From and to tokens should not match"); // fromToken与toToken不能相同

        (uint amountOut, uint newReserve0, uint newReserve1) = getAmountOut(amountIn, fromToken); // 调用定价函数计算输出与新储备

        require(amountOut >= minAmountOut, "Slipped... on a banana"); // 滑点保护：若实际输出小于最小期望则回退

        assert(IERC20(fromToken).transferFrom(msg.sender, address(this), amountIn)); // 从用户转入输入代币
        assert(IERC20(toToken).transfer(to, amountOut)); // 将输出代币转给接收地址

        reserve0 = newReserve0; // 更新token0储备
        reserve1 = newReserve1; // 更新token1储备
    }
}
