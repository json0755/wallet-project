// Merkle树构建工具
const { keccak256 } = require('ethers');
const { MerkleTree } = require('merkletreejs');

/**
 * @title MerkleTreeBuilder
 * @dev 用于构建白名单Merkle树的工具类
 */
class MerkleTreeBuilder {
    constructor(addresses) {
        this.addresses = addresses;
        this.leaves = addresses.map(addr => keccak256(addr));
        this.tree = new MerkleTree(this.leaves, keccak256, { sortPairs: true });
    }

    /**
     * 获取Merkle根
     * @returns {string} Merkle根的十六进制字符串
     */
    getRoot() {
        return this.tree.getHexRoot();
    }

    /**
     * 获取指定地址的Merkle证明
     * @param {string} address 地址
     * @returns {string[]} Merkle证明数组
     */
    getProof(address) {
        const leaf = keccak256(address);
        return this.tree.getHexProof(leaf);
    }

    /**
     * 验证Merkle证明
     * @param {string} address 地址
     * @param {string[]} proof Merkle证明
     * @returns {boolean} 验证结果
     */
    verify(address, proof) {
        const leaf = keccak256(address);
        return this.tree.verify(proof, leaf, this.getRoot());
    }

    /**
     * 获取所有地址的证明
     * @returns {Object} 地址到证明的映射
     */
    getAllProofs() {
        const proofs = {};
        this.addresses.forEach(address => {
            proofs[address] = this.getProof(address);
        });
        return proofs;
    }

    /**
     * 导出Merkle树信息
     * @returns {Object} 包含根、叶子节点和所有证明的对象
     */
    export() {
        return {
            root: this.getRoot(),
            leaves: this.leaves.map(leaf => leaf),
            proofs: this.getAllProofs(),
            addresses: this.addresses
        };
    }

    /**
     * 从文件加载地址列表并构建Merkle树
     * @param {string} filePath 文件路径
     * @returns {MerkleTreeBuilder} Merkle树构建器实例
     */
    static fromFile(filePath) {
        const fs = require('fs');
        const addresses = JSON.parse(fs.readFileSync(filePath, 'utf8'));
        return new MerkleTreeBuilder(addresses);
    }

    /**
     * 保存Merkle树信息到文件
     * @param {string} filePath 文件路径
     */
    saveToFile(filePath) {
        const fs = require('fs');
        fs.writeFileSync(filePath, JSON.stringify(this.export(), null, 2));
    }
}

// 示例用法
if (require.main === module) {
    // 示例白名单地址
    const whitelistAddresses = [
        '0x1234567890123456789012345678901234567890',
        '0x2345678901234567890123456789012345678901',
        '0x3456789012345678901234567890123456789012',
        '0x4567890123456789012345678901234567890123',
        '0x5678901234567890123456789012345678901234'
    ];

    // 构建Merkle树
    const builder = new MerkleTreeBuilder(whitelistAddresses);
    
    console.log('Merkle Root:', builder.getRoot());
    console.log('\nProofs:');
    whitelistAddresses.forEach(address => {
        const proof = builder.getProof(address);
        console.log(`${address}: [${proof.join(', ')}]`);
    });

    // 验证示例
    const testAddress = whitelistAddresses[0];
    const testProof = builder.getProof(testAddress);
    const isValid = builder.verify(testAddress, testProof);
    console.log(`\nVerification for ${testAddress}: ${isValid}`);

    // 保存到文件
    builder.saveToFile('./merkle_tree_data.json');
    console.log('\nMerkle tree data saved to merkle_tree_data.json');
}

module.exports = MerkleTreeBuilder;