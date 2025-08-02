// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MerkleProof
 * @dev Merkle树验证库，用于验证白名单
 */
library MerkleProof {
    /**
     * @dev 验证Merkle证明
     * @param proof Merkle证明数组
     * @param root Merkle根
     * @param leaf 要验证的叶子节点
     * @return 验证是否通过
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev 处理Merkle证明，计算根节点
     * @param proof Merkle证明数组
     * @param leaf 叶子节点
     * @return 计算得到的根节点
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev 对两个哈希值进行排序后哈希
     * @param a 第一个哈希值
     * @param b 第二个哈希值
     * @return 排序后的哈希结果
     */
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    /**
     * @dev 计算两个哈希值的组合哈希
     * @param a 第一个哈希值
     * @param b 第二个哈希值
     * @return value 哈希结果
     */
    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    /**
     * @dev 验证多重证明（用于批量验证）
     * @param proofs 多个Merkle证明
     * @param proofFlags 证明标志数组
     * @param root Merkle根
     * @param leaves 要验证的叶子节点数组
     * @return 验证是否通过
     */
    function multiProofVerify(
        bytes32[] memory proofs,
        bool[] memory proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProof(proofs, proofFlags, leaves) == root;
    }

    /**
     * @dev 处理多重证明验证的内部函数
     * @param proofs 证明数组
     * @param proofFlags 证明标志数组
     * @param leaves 叶子节点数组
     * @return merkleRoot 计算得到的根节点
     */
    function processMultiProof(
        bytes32[] memory proofs,
        bool[] memory proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        uint256 leavesLen = leaves.length;
        uint256 totalHashes = proofFlags.length;

        require(leavesLen + proofs.length - 1 == totalHashes, "MerkleProof: invalid multiproof");

        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;

        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i] ? leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++] : proofs[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            return hashes[totalHashes - 1];
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proofs[0];
        }
    }
}