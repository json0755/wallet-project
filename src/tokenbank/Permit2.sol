// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title Permit2
 * @notice 简化版的Permit2合约，实现核心的签名转账功能
 */
contract Permit2 {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // EIP-712 域分隔符相关
    string public constant name = "Permit2";
    string public constant version = "1";
    bytes32 private immutable _DOMAIN_SEPARATOR;

    // TypeHash常量
    bytes32 public constant PERMIT_TRANSFER_FROM_TYPEHASH = 
        keccak256("PermitTransferFrom(TokenPermissions permitted,uint256 nonce,uint256 deadline)");
    
    bytes32 public constant TOKEN_PERMISSIONS_TYPEHASH = 
        keccak256("TokenPermissions(address token,uint256 amount)");

    // Nonce管理 - 使用bitmap来高效管理nonce
    mapping(address => mapping(uint256 => uint256)) public nonceBitmap;

    // 结构体定义
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    // 事件
    event PermitTransfer(
        address indexed owner,
        address indexed to,
        address indexed token,
        uint256 amount,
        uint256 nonce
    );

    // 错误定义
    error SignatureExpired();
    error InvalidSignature();
    error InvalidNonce();
    error TransferFailed();

    constructor() {
        _DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            block.chainid,
            address(this)
        ));
    }

    /**
     * @notice 获取域分隔符
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }

    /**
     * @notice 检查nonce是否已使用
     */
    function isNonceUsed(address owner, uint256 nonce) external view returns (bool) {
        uint256 word = nonce >> 8; // nonce / 256
        uint256 bit = nonce & 0xff; // nonce % 256
        uint256 bitmap = nonceBitmap[owner][word];
        return (bitmap >> bit) & 1 == 1;
    }

    /**
     * @notice 使Nonce失效
     */
    function _useNonce(address owner, uint256 nonce) internal {
        uint256 word = nonce >> 8; // nonce / 256
        uint256 bit = nonce & 0xff; // nonce % 256
        uint256 bitmap = nonceBitmap[owner][word];
        
        if ((bitmap >> bit) & 1 == 1) {
            revert InvalidNonce();
        }
        
        nonceBitmap[owner][word] = bitmap | (1 << bit);
    }

    /**
     * @notice 核心函数：使用签名进行转账
     */
    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails memory transferDetails,
        address owner,
        bytes memory signature
    ) external {
        // 检查截止时间
        if (block.timestamp > permit.deadline) {
            revert SignatureExpired();
        }

        // 验证签名
        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TRANSFER_FROM_TYPEHASH,
            keccak256(abi.encode(
                TOKEN_PERMISSIONS_TYPEHASH,
                permit.permitted.token,
                permit.permitted.amount
            )),
            permit.nonce,
            permit.deadline
        ));

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", _DOMAIN_SEPARATOR, structHash));
        
        address signer = hash.recover(signature);
        if (signer != owner) {
            revert InvalidSignature();
        }

        // 使用nonce
        _useNonce(owner, permit.nonce);

        // 执行转账
        bool success = IERC20(permit.permitted.token).transferFrom(
            owner,
            transferDetails.to,
            transferDetails.requestedAmount
        );

        if (!success) {
            revert TransferFailed();
        }

        // 发出事件
        emit PermitTransfer(
            owner,
            transferDetails.to,
            permit.permitted.token,
            transferDetails.requestedAmount,
            permit.nonce
        );
    }

    /**
     * @notice 批量使nonce失效（管理功能）
     */
    function invalidateNonces(uint256[] calldata nonces) external {
        for (uint256 i = 0; i < nonces.length; i++) {
            _useNonce(msg.sender, nonces[i]);
        }
    }
} 