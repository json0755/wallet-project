// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AirdropNFT
 * @dev 用于空投市场的NFT合约
 */
contract AirdropNFT is ERC721, ERC721URIStorage, Ownable {
    uint256 private _tokenIdCounter;
    address public marketContract;  // NFT市场合约地址，用于授权
    
    constructor(string memory name, string memory symbol) 
        ERC721(name, symbol) 
        Ownable(msg.sender) 
    {
        // 从tokenId 1开始
        _tokenIdCounter = 1;
    }
    
    /**
     * @dev 设置市场合约地址
     * @param _marketContract 市场合约地址
     */
    function setMarketContract(address _marketContract) external onlyOwner {
        marketContract = _marketContract;
    }
    
    /**
     * @dev 铸造NFT
     * @param to 接收地址
     * @param uri 元数据URI
     * @return tokenId 新铸造的tokenId
     */
    function mint(address to, string memory uri) public onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        return tokenId;
    }
    
    /**
     * @dev 批量铸造NFT
     * @param to 接收地址
     * @param uris 元数据URI数组
     * @return tokenIds 新铸造的tokenId数组
     */
    function batchMint(address to, string[] memory uris) external onlyOwner returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](uris.length);
        
        for (uint256 i = 0; i < uris.length; i++) {
            uint256 tokenId = _tokenIdCounter;
            _tokenIdCounter++;
            
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, uris[i]);
            
            tokenIds[i] = tokenId;
        }
        
        return tokenIds;
    }
    
    /**
     * @dev 获取下一个tokenId
     */
    function getNextTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }
    
    /**
     * @dev 重写approve函数，自动授权给市场合约
     */
    function approve(address to, uint256 tokenId) public override(ERC721, IERC721) {
        super.approve(to, tokenId);
    }
    
    /**
     * @dev 检查是否已授权给市场合约
     */
    function isApprovedForMarket(uint256 tokenId) external view returns (bool) {
        return getApproved(tokenId) == marketContract || isApprovedForAll(ownerOf(tokenId), marketContract);
    }
    
    // 重写必要的函数
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}