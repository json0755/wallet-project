// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title UpgradeableNFT
 * @dev 可升级的ERC721 NFT合约
 * 使用OpenZeppelin的可升级合约模式
 */
contract UpgradeableNFT is Initializable, ERC721Upgradeable, OwnableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数，替代构造函数
     * @param name NFT集合名称
     * @param symbol NFT集合符号
     * @param owner 合约所有者地址
     */
    function initialize(
        string memory name,
        string memory symbol,
        address owner
    ) public initializer {
        __ERC721_init(name, symbol);
        __Ownable_init(owner);
    }

    /**
     * @dev 铸造NFT函数
     * @param to 接收者地址
     * @param tokenId 代币ID
     */
    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
    }

    /**
     * @dev 批量铸造NFT函数
     * @param to 接收者地址
     * @param tokenIds 代币ID数组
     */
    function batchMint(address to, uint256[] memory tokenIds) public onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _mint(to, tokenIds[i]);
        }
    }

    /**
     * @dev 设置基础URI
     * @param baseURI 基础URI
     */
    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }

    /**
     * @dev 内部函数：设置基础URI
     * @param baseURI 基础URI
     */
    function _setBaseURI(string memory baseURI) internal {
        // 这里可以添加存储baseURI的逻辑
        // 为了简化，我们暂时不实现完整的baseURI功能
    }
}