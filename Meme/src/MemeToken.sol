// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MemeToken is ERC20, Ownable {
    string private _tokenSymbol;
    uint256 public totalSupplyCap;
    uint256 public perMint;
    uint256 public price;
    address public creator;
    address public factory;
    uint256 public currentSupply;
    
    event TokenMinted(address indexed to, uint256 amount);
    
    constructor() ERC20("MemeToken", "MEME") Ownable(msg.sender) {}
    
    function initialize(
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address _creator,
        address _factory
    ) external {
        require(factory == address(0), "Already initialized");
        require(_totalSupply > 0, "Total supply must be greater than 0");
        require(_perMint > 0, "Per mint must be greater than 0");
        require(_perMint <= _totalSupply, "Per mint cannot exceed total supply");
        require(_creator != address(0), "Creator cannot be zero address");
        require(_factory != address(0), "Factory cannot be zero address");
        
        _tokenSymbol = _symbol;
        totalSupplyCap = _totalSupply;
        perMint = _perMint;
        price = _price;
        creator = _creator;
        factory = _factory;
        currentSupply = 0;
        
        _transferOwnership(_factory);
    }
    
    function mint(address to) external onlyOwner {
        require(to != address(0), "Cannot mint to zero address");
        require(currentSupply + perMint <= totalSupplyCap, "Cannot mint more tokens");
        
        currentSupply += perMint;
        _mint(to, perMint);
        
        emit TokenMinted(to, perMint);
    }
    
    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }
    
    function canMint() external view returns (bool) {
        return currentSupply + perMint <= totalSupplyCap;
    }
    
    function remainingSupply() external view returns (uint256) {
        return totalSupplyCap - currentSupply;
    }
}