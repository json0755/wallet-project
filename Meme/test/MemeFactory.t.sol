// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;
    
    address public owner;
    address public creator;
    address public user1;
    address public user2;
    
    // Test parameters
    string constant SYMBOL = "PEPE";
    uint256 constant TOTAL_SUPPLY = 1000000 * 10**18;
    uint256 constant PER_MINT = 1000 * 10**18;
    uint256 constant PRICE = 1; // Price per wei of token (1 wei per wei, so 1000 tokens cost 1000 * 10^18 wei = 1 ether)
    
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
    
    event MemeTokenMinted(
        address indexed tokenAddress,
        address indexed minter,
        uint256 amount,
        uint256 platformFee,
        uint256 creatorFee
    );
    
    function setUp() public {
        owner = address(this);
        creator = makeAddr("creator");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy factory
        factory = new MemeFactory();
        
        // Give users some ETH
        vm.deal(owner, 10000 ether);  // Give owner (test contract) some ETH
        vm.deal(creator, 10000 ether);
        vm.deal(user1, 10000 ether);
        vm.deal(user2, 10000 ether);
    }
    
    // Allow the test contract to receive ETH
    receive() external payable {}
    
    function testDeployMeme() public {
        vm.startPrank(creator);
        
        // Test successful deployment
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // Verify token was created
        assertTrue(tokenAddr != address(0));
        
        // Verify token info
        (
            string memory symbol,
            uint256 totalSupply,
            uint256 perMint,
            uint256 price,
            address tokenCreator,
            uint256 currentSupply,
            bool canMint,
            bool liquidityAdded
        ) = factory.getTokenInfo(tokenAddr);
        
        assertEq(symbol, SYMBOL);
        assertEq(totalSupply, TOTAL_SUPPLY);
        assertEq(perMint, PER_MINT);
        assertEq(price, PRICE);
        assertEq(tokenCreator, creator);
        assertEq(currentSupply, 0);
        assertTrue(canMint);
        
        // Verify factory state
        assertEq(factory.getAllTokensCount(), 1);
        assertEq(factory.getTokenByIndex(0), tokenAddr);
        
        vm.stopPrank();
    }
    
    function testDeployMemeInvalidParameters() public {
        vm.startPrank(creator);
        
        // Test empty symbol
        vm.expectRevert("Symbol cannot be empty");
        factory.deployMeme("", TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // Test zero total supply
        vm.expectRevert("Total supply must be greater than 0");
        factory.deployMeme(SYMBOL, 0, PER_MINT, PRICE);
        
        // Test zero per mint
        vm.expectRevert("Per mint must be greater than 0");
        factory.deployMeme(SYMBOL, TOTAL_SUPPLY, 0, PRICE);
        
        // Test per mint exceeds total supply
        vm.expectRevert("Per mint cannot exceed total supply");
        factory.deployMeme(SYMBOL, 100, 200, PRICE);
        
        vm.stopPrank();
    }
    
    function testMintMeme() public {
        // Deploy a token first
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // Calculate expected costs
        (uint256 totalCost, uint256 platformFee, uint256 creatorFee) = factory.calculateMintCost(tokenAddr);
        
        // Record initial balances
        uint256 ownerInitialBalance = address(owner).balance;
        uint256 creatorInitialBalance = address(creator).balance;
        uint256 user1InitialBalance = address(user1).balance;
        
        // Test successful minting
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, false, true);
        emit MemeMinted(tokenAddr, user1, PER_MINT, totalCost, platformFee, creatorFee);
        
        factory.mintMeme{value: totalCost}(tokenAddr);
        
        // Verify token balance
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.balanceOf(user1), PER_MINT);
        assertEq(token.currentSupply(), PER_MINT);
        
        // Verify fee distribution
        assertEq(address(owner).balance, ownerInitialBalance + platformFee);
        assertEq(address(creator).balance, creatorInitialBalance + creatorFee);
        assertEq(address(user1).balance, user1InitialBalance - totalCost);
        
        vm.stopPrank();
    }
    
    function testMintMemeWithExcessPayment() public {
        // Deploy a token first
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        (uint256 totalCost,,) = factory.calculateMintCost(tokenAddr);
        uint256 excessPayment = 0.5 ether;
        uint256 totalPayment = totalCost + excessPayment;
        
        uint256 user1InitialBalance = address(user1).balance;
        
        // Test minting with excess payment
        vm.prank(user1);
        factory.mintMeme{value: totalPayment}(tokenAddr);
        
        // Verify refund
        assertEq(address(user1).balance, user1InitialBalance - totalCost);
    }
    
    function testMintMemeInsufficientPayment() public {
        // Deploy a token first
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        (uint256 totalCost,,) = factory.calculateMintCost(tokenAddr);
        uint256 insufficientPayment = totalCost - 1;
        
        // Test insufficient payment
        vm.prank(user1);
        vm.expectRevert("Insufficient payment");
        factory.mintMeme{value: insufficientPayment}(tokenAddr);
    }
    
    function testMintMemeNonexistentToken() public {
        address fakeToken = makeAddr("fakeToken");
        
        vm.prank(user1);
        vm.expectRevert("Token does not exist");
        factory.mintMeme{value: 1 ether}(fakeToken);
    }
    
    function testMintMemeExceedsTotalSupply() public {
        // Deploy a token with small total supply
        uint256 smallTotalSupply = PER_MINT * 2; // Only allow 2 mints
        
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, smallTotalSupply, PER_MINT, PRICE);
        
        (uint256 totalCost,,) = factory.calculateMintCost(tokenAddr);
        
        // First mint - should succeed
        vm.prank(user1);
        factory.mintMeme{value: totalCost}(tokenAddr);
        
        // Second mint - should succeed
        vm.prank(user2);
        factory.mintMeme{value: totalCost}(tokenAddr);
        
        // Third mint - should fail
        vm.prank(user1);
        vm.expectRevert("Cannot mint more tokens");
        factory.mintMeme{value: totalCost}(tokenAddr);
    }
    
    function testFeeDistribution() public {
        // Deploy a token
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // Calculate expected fees
        (uint256 expectedTotalCost, uint256 expectedPlatformFee, uint256 expectedCreatorFee) = 
            factory.calculateMintCost(tokenAddr);
        
        // Verify 5% platform fee
        uint256 expectedPlatformFeeCalculated = (expectedTotalCost * 500) / 10000;
        assertEq(expectedPlatformFee, expectedPlatformFeeCalculated);
        
        // Verify 95% creator fee
        uint256 expectedCreatorFeeCalculated = expectedTotalCost - expectedPlatformFeeCalculated;
        assertEq(expectedCreatorFee, expectedCreatorFeeCalculated);
    }
    
    function testMultipleTokensAndMints() public {
        // Deploy multiple tokens
        vm.startPrank(creator);
        address token1 = factory.deployMeme("TOKEN1", TOTAL_SUPPLY, PER_MINT, PRICE);
        address token2 = factory.deployMeme("TOKEN2", TOTAL_SUPPLY * 2, PER_MINT * 2, PRICE * 2);
        vm.stopPrank();
        
        // Verify factory state
        assertEq(factory.getAllTokensCount(), 2);
        assertEq(factory.getTokenByIndex(0), token1);
        assertEq(factory.getTokenByIndex(1), token2);
        
        // Mint from both tokens
        (uint256 cost1,,) = factory.calculateMintCost(token1);
        (uint256 cost2,,) = factory.calculateMintCost(token2);
        
        vm.prank(user1);
        factory.mintMeme{value: cost1}(token1);
        
        vm.prank(user2);
        factory.mintMeme{value: cost2}(token2);
        
        // Verify balances
        assertEq(MemeToken(token1).balanceOf(user1), PER_MINT);
        assertEq(MemeToken(token2).balanceOf(user2), PER_MINT * 2);
    }
    
    function testTokenInfo() public {
        // Deploy a token
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // Test token info before minting
        (
            string memory symbol,
            uint256 totalSupply,
            uint256 perMint,
            uint256 price,
            address tokenCreator,
            uint256 currentSupply,
            bool canMint,
            bool liquidityAdded
        ) = factory.getTokenInfo(tokenAddr);
        
        assertEq(symbol, SYMBOL);
        assertEq(totalSupply, TOTAL_SUPPLY);
        assertEq(perMint, PER_MINT);
        assertEq(price, PRICE);
        assertEq(tokenCreator, creator);
        assertEq(currentSupply, 0);
        assertTrue(canMint);
        
        // Mint some tokens
        vm.prank(user1);
        factory.mintMeme{value: PER_MINT * PRICE}(tokenAddr);
        
        // Test token info after minting
        (, , , , , currentSupply, canMint, ) = factory.getTokenInfo(tokenAddr);
        assertEq(currentSupply, PER_MINT);
        assertTrue(canMint);
    }
    
    function testEmergencyWithdraw() public {
        // Send some ETH to the factory (simulating stuck funds)
        vm.deal(address(factory), 1 ether);
        
        uint256 ownerInitialBalance = address(owner).balance;
        uint256 factoryBalance = address(factory).balance;
        
        // Only owner can call emergency withdraw
        vm.prank(user1);
        vm.expectRevert();
        factory.emergencyWithdraw();
        
        // Owner calls emergency withdraw
        factory.emergencyWithdraw();
        
        // Verify funds transferred
        assertEq(address(factory).balance, 0);
        assertEq(address(owner).balance, ownerInitialBalance + factoryBalance);
    }
    
    function testGetTokenByIndexOutOfBounds() public {
        // Test with no tokens deployed
        vm.expectRevert("Index out of bounds");
        factory.getTokenByIndex(0);
        
        // Deploy one token
        vm.prank(creator);
        factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        // Test valid index
        address token = factory.getTokenByIndex(0);
        assertTrue(token != address(0));
        
        // Test invalid index
        vm.expectRevert("Index out of bounds");
        factory.getTokenByIndex(1);
    }
    
    function testMemeTokenDirectAccess() public {
        // Deploy a token
        vm.prank(creator);
        address tokenAddr = factory.deployMeme(SYMBOL, TOTAL_SUPPLY, PER_MINT, PRICE);
        
        MemeToken token = MemeToken(tokenAddr);
        
        // Test token properties
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.totalSupplyCap(), TOTAL_SUPPLY);
        assertEq(token.perMint(), PER_MINT);
        assertEq(token.price(), PRICE);
        assertEq(token.creator(), creator);
        assertEq(token.factory(), address(factory));
        assertEq(token.currentSupply(), 0);
        assertTrue(token.canMint());
        assertEq(token.remainingSupply(), TOTAL_SUPPLY);
        
        // Test that only factory can mint
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user1);
    }
}