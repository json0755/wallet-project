// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IPermit2 {
    struct PermitSingle {
        PermitDetails details;
        address spender;
        uint256 sigDeadline;
    }

    struct PermitDetails {
        address token;
        uint160 amount;
        uint48 expiration;
        uint48 nonce;
    }

    function permit(
        address owner,
        PermitSingle memory permitSingle,
        bytes calldata signature
    ) external;

    function transferFrom(
        address from,
        address to,
        uint160 amount,
        address token
    ) external;

    function allowance(
        address user,
        address token,
        address spender
    ) external view returns (uint160 amount, uint48 expiration, uint48 nonce);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// ERC4626 is an implementation for a tokenized vault
contract EIP2612TokenBank is ERC4626, Ownable, ReentrancyGuard {
    // Permit2 合约地址
    IPermit2 public immutable PERMIT2;
    
    constructor(IERC20 _asset, address _permit2)
        ERC4626(_asset)
        ERC20("Token Bank", "TBANK")
        Ownable(msg.sender)
    {
        PERMIT2 = IPermit2(_permit2);
    }

    // 原始的 permit 版本（适用于支持 EIP-2612 的代币）
    function permitDeposit(
        uint256 assets, 
        address receiver, 
        uint256 deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) external nonReentrant returns (uint256 shares) {
        // 使用原生 permit 授权
        IERC20Permit(address(asset())).permit(
            msg.sender, 
            address(this), 
            assets, 
            deadline, 
            v, 
            r, 
            s
        );
        // 统一调用 deposit
        return deposit(assets, receiver);
    }

    // 使用 Permit2 Allowance 模式
    function permitDeposit2(
        uint256 assets,
        address receiver,
        uint160 amount,
        uint48 expiration,
        uint48 nonce,
        uint256 sigDeadline,
        bytes calldata signature
    ) external nonReentrant returns (uint256 shares) {
        // 使用 Permit2 授权
        IPermit2.PermitSingle memory permitSingle = IPermit2.PermitSingle({
            details: IPermit2.PermitDetails({
                token: address(asset()),
                amount: amount,
                expiration: expiration,
                nonce: nonce
            }),
            spender: address(this),
            sigDeadline: sigDeadline
        });

        // 1. 先设置 Permit2 授权
        PERMIT2.permit(msg.sender, permitSingle, signature);

        // 2. 直接使用 Permit2 transferFrom，而不是调用 deposit()
        shares = previewDeposit(assets);
        
        // 3. 使用 Permit2 转移代币
        PERMIT2.transferFrom(msg.sender, address(this), uint160(assets), address(asset()));
        
        // 4. 铸造份额
        _mint(receiver, shares);
        
        // 5. 发出事件
        emit Deposit(msg.sender, receiver, assets, shares);
        
        return shares;
    }

    // 获取 Permit2 合约地址
    function getPermit2Address() external view returns (address) {
        return address(PERMIT2);
    }

    // 检查 Permit2 授权状态
    function getPermit2Allowance(address owner) external view returns (uint160 amount, uint48 expiration, uint48 nonce) {
        return PERMIT2.allowance(owner, address(asset()), address(this));
        // owner:0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        // asset: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
        // this: 0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690
        // cast call 0x000000000022D473030F116dDEE9F6B43aC78BA3 "allowance(address,address,address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690
        // 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 0x000000000022D473030F116dDEE9F6B43aC78BA3
    }
}