// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EIP2612Token
 * @dev ERC20 Token with EIP2612 permit functionality
 * EIP2612 allows for gasless approvals using signatures
 */
contract EIP2612Token is ERC20, ERC20Permit, Ownable {
    // Token decimals
    uint8 private _decimals;
    
    // Total supply cap (optional)
    uint256 public immutable cap;
    
    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param initialSupply The initial supply of tokens
     * @param tokenDecimals The number of decimals for the token
     * @param supplyCap The maximum supply cap (0 for no cap)
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 tokenDecimals,
        uint256 supplyCap
    ) ERC20(name, symbol) ERC20Permit(name) Ownable(msg.sender) {
        _decimals = tokenDecimals;
        cap = supplyCap;
        
        // Mint initial supply to the deployer
        if (initialSupply > 0) {
            uint256 initialSupplyWei = initialSupply * 10**tokenDecimals;
            require(supplyCap == 0 || initialSupplyWei <= supplyCap, "Initial supply exceeds cap");
            _mint(msg.sender, initialSupplyWei);
        }
    }
    
    /**
     * @dev Returns the number of decimals used to get its user representation.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev Mint new tokens to a specified address.
     * Can only be called by the owner.
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint (in token units, not wei)
     */
    function mint(address to, uint256 amount) public onlyOwner {
        uint256 mintAmount = amount * 10**_decimals;
        
        // Check cap if set
        if (cap > 0) {
            require(totalSupply() + mintAmount <= cap, "EIP2612Token: cap exceeded");
        }
        
        _mint(to, mintAmount);
    }
    
    /**
     * @dev Burn tokens from a specified address.
     * Can only be called by the owner.
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn (in token units, not wei)
     */
    function burn(address from, uint256 amount) public onlyOwner {
        uint256 burnAmount = amount * 10**_decimals;
        _burn(from, burnAmount);
    }
    
    /**
     * @dev Burn tokens from the caller's account.
     * @param amount The amount of tokens to burn (in token units, not wei)
     */
    function burn(uint256 amount) public {
        uint256 burnAmount = amount * 10**_decimals;
        _burn(msg.sender, burnAmount);
    }
    
    /**
     * @dev Transfer ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "EIP2612Token: new owner is the zero address");
        super.transferOwnership(newOwner);
    }
    
    /**
     * @dev Batch transfer tokens to multiple addresses
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to transfer (in token units)
     */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length, "EIP2612Token: arrays length mismatch");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 transferAmount = amounts[i] * 10**_decimals;
            _transfer(msg.sender, recipients[i], transferAmount);
        }
    }
    
    /**
     * @dev Emergency pause functionality (if needed in the future)
     * This is a placeholder for potential pause functionality
     */
    function emergencyPause() external onlyOwner {
        // This could be implemented with OpenZeppelin's Pausable if needed
        // For now, it's just a placeholder
        revert("EIP2612Token: Emergency pause not implemented");
    }
} 