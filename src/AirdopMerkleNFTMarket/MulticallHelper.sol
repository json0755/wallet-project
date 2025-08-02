// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AirdopMerkleNFTMarket.sol";

/**
 * @title MulticallHelper
 * @dev 用于封装multicall调用的辅助合约
 */
contract MulticallHelper {
    /**
     * @dev 编码permitPrePay函数调用数据
     * @param owner 代币所有者
     * @param spender 被授权者
     * @param value 授权金额
     * @param deadline 截止时间
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     * @return 编码后的调用数据
     */
    function encodePermitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external pure returns (bytes memory) {
        return abi.encodeWithSignature(
            "permitPrePay(address,address,uint256,uint256,uint8,bytes32,bytes32)",
            owner,
            spender,
            value,
            deadline,
            v,
            r,
            s
        );
    }
    
    /**
     * @dev 编码claimNFT函数调用数据
     * @param tokenId NFT ID
     * @param merkleProof Merkle证明
     * @return 编码后的调用数据
     */
    function encodeClaimNFT(
        uint256 tokenId,
        bytes32[] calldata merkleProof
    ) external pure returns (bytes memory) {
        return abi.encodeWithSignature(
            "claimNFT(uint256,bytes32[])",
            tokenId,
            merkleProof
        );
    }
    
    /**
     * @dev 编码buyNFT函数调用数据
     * @param tokenId NFT ID
     * @return 编码后的调用数据
     */
    function encodeBuyNFT(uint256 tokenId) external pure returns (bytes memory) {
        return abi.encodeWithSignature("buyNFT(uint256)", tokenId);
    }
    
    /**
     * @dev 编码listNFT函数调用数据
     * @param tokenId NFT ID
     * @param price 价格
     * @return 编码后的调用数据
     */
    function encodeListNFT(uint256 tokenId, uint256 price) external pure returns (bytes memory) {
        return abi.encodeWithSignature("listNFT(uint256,uint256)", tokenId, price);
    }
    
    /**
     * @dev 创建permit + claimNFT的multicall数据
     * @param permitData permit授权数据
     * @param tokenId NFT ID
     * @param merkleProof Merkle证明
     * @return 编码后的multicall数据数组
     */
    function createPermitAndClaimData(
        PermitData calldata permitData,
        uint256 tokenId,
        bytes32[] calldata merkleProof
    ) external pure returns (bytes[] memory) {
        bytes[] memory calls = new bytes[](2);
        
        // 第一个调用：permitPrePay
        calls[0] = abi.encodeWithSignature(
            "permitPrePay(address,address,uint256,uint256,uint8,bytes32,bytes32)",
            permitData.owner,
            permitData.spender,
            permitData.value,
            permitData.deadline,
            permitData.v,
            permitData.r,
            permitData.s
        );
        
        // 第二个调用：claimNFT
        calls[1] = abi.encodeWithSignature(
            "claimNFT(uint256,bytes32[])",
            tokenId,
            merkleProof
        );
        
        return calls;
    }
    
    /**
     * @dev 创建permit + buyNFT的multicall数据
     * @param permitData permit授权数据
     * @param tokenId NFT ID
     * @return 编码后的multicall数据数组
     */
    function createPermitAndBuyData(
        PermitData calldata permitData,
        uint256 tokenId
    ) external pure returns (bytes[] memory) {
        bytes[] memory calls = new bytes[](2);
        
        // 第一个调用：permitPrePay
        calls[0] = abi.encodeWithSignature(
            "permitPrePay(address,address,uint256,uint256,uint8,bytes32,bytes32)",
            permitData.owner,
            permitData.spender,
            permitData.value,
            permitData.deadline,
            permitData.v,
            permitData.r,
            permitData.s
        );
        
        // 第二个调用：buyNFT
        calls[1] = abi.encodeWithSignature("buyNFT(uint256)", tokenId);
        
        return calls;
    }
    
    /**
     * @dev Permit数据结构
     */
    struct PermitData {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
}