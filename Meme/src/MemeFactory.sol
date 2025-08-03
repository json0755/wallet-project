// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./MemeToken.sol";

/**
 * @title MemeFactory
 * @dev Factory contract for creating Meme tokens using minimal proxy pattern (EIP-1167)
 * Implements fee distribution mechanism: 1% to platform, 99% to token creator
 */
contract MemeFactory is Ownable, ReentrancyGuard {
    using Clones for address;
    
    // Template contract for cloning
    address public immutable memeTokenImplementation;
    
    // Platform fee percentage (1% = 100 basis points)
    uint256 public constant PLATFORM_FEE_BPS = 100;
    uint256 public constant BASIS_POINTS = 10000;
    
    // Mapping from token address to token info
    mapping(address => TokenInfo) public tokenInfo;
    
    // Array of all created tokens
    address[] public allTokens;
    
    struct TokenInfo {
        string symbol;
        uint256 totalSupply;
        uint256 perMint;
        uint256 price;
        address creator;
        bool exists;
    }
    
    event MemeDeployed(
        address indexed tokenAddress,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    
    event MemeMinted(
        address indexed tokenAddress,
        address indexed minter,
        uint256 amount,
        uint256 totalPayment,
        uint256 platformFee,
        uint256 creatorFee
    );
    
    constructor() Ownable(msg.sender) {
        // Deploy the implementation contract
        memeTokenImplementation = address(new MemeToken());
    }
    
    /**
     * @dev Deploy a new Meme token using minimal proxy pattern
     * @param symbol Token symbol
     * @param totalSupply Maximum total supply
     * @param perMint Amount minted per transaction
     * @param price Price per token in wei
     * @return tokenAddress Address of the newly created token
     */
    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address tokenAddress) {
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(totalSupply > 0, "Total supply must be greater than 0");
        require(perMint > 0, "Per mint must be greater than 0");
        require(perMint <= totalSupply, "Per mint cannot exceed total supply");
        
        // Create minimal proxy clone
        tokenAddress = memeTokenImplementation.clone();
        
        // Initialize the cloned contract
        MemeToken(tokenAddress).initialize(
            symbol,
            totalSupply,
            perMint,
            price,
            msg.sender,
            address(this)
        );
        
        // Store token information
        tokenInfo[tokenAddress] = TokenInfo({
            symbol: symbol,
            totalSupply: totalSupply,
            perMint: perMint,
            price: price,
            creator: msg.sender,
            exists: true
        });
        
        allTokens.push(tokenAddress);
        
        emit MemeDeployed(
            tokenAddress,
            msg.sender,
            symbol,
            totalSupply,
            perMint,
            price
        );
        
        return tokenAddress;
    }
    
    /**
     * @dev Mint Meme tokens by paying the required fee
     * @param tokenAddr Address of the token to mint
     */
    function mintMeme(address tokenAddr) external payable nonReentrant {
        require(tokenInfo[tokenAddr].exists, "Token does not exist");
        
        TokenInfo memory info = tokenInfo[tokenAddr];
        MemeToken token = MemeToken(tokenAddr);
        
        // Check if more tokens can be minted
        require(token.canMint(), "Cannot mint more tokens");
        
        // Calculate required payment
        uint256 totalPayment = info.perMint * info.price;
        require(msg.value >= totalPayment, "Insufficient payment");
        
        // Calculate fees
        uint256 platformFee = (totalPayment * PLATFORM_FEE_BPS) / BASIS_POINTS;
        uint256 creatorFee = totalPayment - platformFee;
        
        // Mint tokens to the caller
        token.mint(msg.sender);
        
        // Distribute fees
        if (platformFee > 0) {
            payable(owner()).transfer(platformFee);
        }
        
        if (creatorFee > 0) {
            payable(info.creator).transfer(creatorFee);
        }
        
        // Refund excess payment
        if (msg.value > totalPayment) {
            payable(msg.sender).transfer(msg.value - totalPayment);
        }
        
        emit MemeMinted(
            tokenAddr,
            msg.sender,
            info.perMint,
            totalPayment,
            platformFee,
            creatorFee
        );
    }
    
    /**
     * @dev Get information about a token
     * @param tokenAddr Address of the token
     */
    function getTokenInfo(address tokenAddr) external view returns (
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price,
        address creator,
        uint256 currentSupply,
        bool canMint
    ) {
        require(tokenInfo[tokenAddr].exists, "Token does not exist");
        
        TokenInfo memory info = tokenInfo[tokenAddr];
        MemeToken token = MemeToken(tokenAddr);
        
        return (
            info.symbol,
            info.totalSupply,
            info.perMint,
            info.price,
            info.creator,
            token.currentSupply(),
            token.canMint()
        );
    }
    
    /**
     * @dev Get the total number of created tokens
     */
    function getAllTokensCount() external view returns (uint256) {
        return allTokens.length;
    }
    
    /**
     * @dev Get token address by index
     * @param index Index in the allTokens array
     */
    function getTokenByIndex(uint256 index) external view returns (address) {
        require(index < allTokens.length, "Index out of bounds");
        return allTokens[index];
    }
    
    /**
     * @dev Calculate the required payment for minting
     * @param tokenAddr Address of the token
     */
    function calculateMintCost(address tokenAddr) external view returns (
        uint256 totalCost,
        uint256 platformFee,
        uint256 creatorFee
    ) {
        require(tokenInfo[tokenAddr].exists, "Token does not exist");
        
        TokenInfo memory info = tokenInfo[tokenAddr];
        totalCost = info.perMint * info.price;
        platformFee = (totalCost * PLATFORM_FEE_BPS) / BASIS_POINTS;
        creatorFee = totalCost - platformFee;
        
        return (totalCost, platformFee, creatorFee);
    }
    
    /**
     * @dev Emergency function to withdraw stuck ETH (only owner)
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}