// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/vesting/TokenVesting.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TestToken
 * @dev 用于测试的简单ERC20代币
 */
contract TestToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("TestToken", "TEST") {
        _mint(msg.sender, initialSupply);
    }
}

/**
 * @title TokenVestingTest
 * @dev TokenVesting合约的测试用例
 */
contract TokenVestingTest is Test {
    TokenVesting public vesting;
    TestToken public token;
    
    address public beneficiary = address(0x1);
    address public deployer = address(this);
    
    // 测试常量
    uint256 public constant TOTAL_SUPPLY = 10_000_000 * 10**18; // 1000万枚代币
    uint256 public constant VESTED_AMOUNT = 1_000_000 * 10**18; // 100万枚代币
    uint256 public constant CLIFF_DURATION = 12 * 30 * 24 * 60 * 60; // 12个月
    uint256 public constant VESTING_DURATION = 24 * 30 * 24 * 60 * 60; // 24个月
    uint256 public constant MONTH_DURATION = 30 * 24 * 60 * 60; // 1个月
    
    function setUp() public {
        // 部署ERC20代币
        token = new TestToken(TOTAL_SUPPLY);
        
        // 计算即将部署的TokenVesting合约地址
        address vestingAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        
        // 授权TokenVesting合约可以转移代币
        token.approve(vestingAddress, VESTED_AMOUNT);
        
        // 部署TokenVesting合约（构造函数会自动转移代币）
        vesting = new TokenVesting(beneficiary, IERC20(address(token)));
        
        // 验证合约初始状态
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.released(), 0);
        assertEq(token.balanceOf(address(vesting)), VESTED_AMOUNT);
    }
    
    /**
     * @dev 测试构造函数
     */
    function testConstructor() public {
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.TOTAL_VESTED_AMOUNT(), VESTED_AMOUNT);
        assertEq(vesting.released(), 0);
        
        // 验证合约持有正确数量的代币
        assertEq(token.balanceOf(address(vesting)), VESTED_AMOUNT);
    }
    
    /**
     * @dev 测试构造函数参数验证
     */
    function testConstructorValidation() public {
        // 测试零地址受益人
        vm.expectRevert("TokenVesting: beneficiary is zero address");
        new TokenVesting(address(0), token);
        
        // 测试零地址代币
        vm.expectRevert("TokenVesting: token is zero address");
        new TokenVesting(beneficiary, IERC20(address(0)));
    }
    
    /**
     * @dev 测试cliff期内无法释放代币
     */
    function testNoReleaseBeforeCliff() public {
        // 在cliff期内尝试释放
        vm.warp(block.timestamp + CLIFF_DURATION - 1);
        
        assertEq(vesting.getReleasableAmount(), 0);
        
        vm.expectRevert("TokenVesting: no tokens to release");
        vesting.release();
    }
    
    /**
     * @dev 测试cliff期结束后立即释放
     */
    function testReleaseAtCliffEnd() public {
        // 跳转到cliff期结束
        vm.warp(block.timestamp + CLIFF_DURATION);
        
        // 此时应该可以释放0个代币（因为线性释放还没开始）
        assertEq(vesting.getReleasableAmount(), 0);
    }
    
    /**
     * @dev 测试第13个月（cliff后第1个月）的释放
     */
    function testReleaseAfterFirstMonth() public {
        // 跳转到第13个月结束
        vm.warp(block.timestamp + CLIFF_DURATION + MONTH_DURATION);
        
        uint256 expectedAmount = VESTED_AMOUNT / 24; // 1/24的代币
        // console.log("expectedAmount", expectedAmount);
        // console.log("vesting.getReleasableAmount()", vesting.getReleasableAmount());
        assertEq(vesting.getReleasableAmount(), expectedAmount);
        
        uint256 beneficiaryBalanceBefore = token.balanceOf(beneficiary);
        // console.log("beneficiaryBalanceBefore", beneficiaryBalanceBefore);
        
        vesting.release();
        // console.log("beneficiaryBalanceAfter", token.balanceOf(beneficiary));
        // console.log("token.balanceOf(beneficiary)", token.balanceOf(address(beneficiary)));
        
        assertEq(token.balanceOf(beneficiary), beneficiaryBalanceBefore + expectedAmount);
        assertEq(vesting.released(), expectedAmount);
        assertEq(vesting.getReleasableAmount(), 0); // 释放后应该为0
    }
    
    /**
     * @dev 测试多次释放
     */
    function testMultipleReleases() public {
        // 第一次释放：第13个月结束
        vm.warp(block.timestamp + CLIFF_DURATION + MONTH_DURATION);
        uint256 expectedFirstTotal = (VESTED_AMOUNT * 1) / 24; // 1个月的释放
        
        vesting.release();
        assertEq(vesting.released(), expectedFirstTotal);
        
        // 第二次释放：第14个月结束
        vm.warp(block.timestamp + MONTH_DURATION);
        uint256 expectedSecondTotal = (VESTED_AMOUNT * 2) / 24; // 2个月的总释放
        uint256 secondReleaseAmount = expectedSecondTotal - expectedFirstTotal;
        
        // console.log("expectedSecondTotal", expectedSecondTotal);
        // console.log("secondReleaseAmount", secondReleaseAmount);
        assertEq(vesting.getReleasableAmount(), secondReleaseAmount);
        vesting.release();
        assertEq(vesting.released(), expectedSecondTotal);
    }
    
    /**
     * @dev 测试12个月后的释放（一半时间）
     */
    function testReleaseAtHalfVesting() public {
        // 跳转到cliff + 12个月（总释放期的一半）
        vm.warp(block.timestamp + CLIFF_DURATION + 12 * MONTH_DURATION);
        
        uint256 expectedAmount = VESTED_AMOUNT / 2; // 应该释放一半
        assertEq(vesting.getReleasableAmount(), expectedAmount);
        
        vesting.release();
        assertEq(vesting.released(), expectedAmount);
        assertEq(token.balanceOf(beneficiary), expectedAmount);
    }
    
    /**
     * @dev 测试完整释放期结束后的释放
     */
    function testReleaseAfterFullVesting() public {
        // 跳转到完整释放期结束
        vm.warp(block.timestamp + CLIFF_DURATION + VESTING_DURATION);
        
        assertEq(vesting.getReleasableAmount(), VESTED_AMOUNT);
        
        vesting.release();
        
        assertEq(vesting.released(), VESTED_AMOUNT);
        assertEq(token.balanceOf(beneficiary), VESTED_AMOUNT);
        assertEq(vesting.getRemainingAmount(), 0);
        assertEq(vesting.getReleasableAmount(), 0);
    }
    
    /**
     * @dev 测试释放期结束后很久的释放
     */
    function testReleaseAfterVestingPeriod() public {
        // 跳转到释放期结束后很久
        vm.warp(block.timestamp + CLIFF_DURATION + VESTING_DURATION + 365 days);
        
        assertEq(vesting.getReleasableAmount(), VESTED_AMOUNT);
        
        vesting.release();
        
        assertEq(vesting.released(), VESTED_AMOUNT);
        assertEq(token.balanceOf(beneficiary), VESTED_AMOUNT);
    }
    
    /**
     * @dev 测试查询函数
     */
    function testViewFunctions() public {
        uint256 startTime = vesting.startTime();
        
        assertEq(vesting.getCliffEndTime(), startTime + CLIFF_DURATION);
        assertEq(vesting.getVestingEndTime(), startTime + CLIFF_DURATION + VESTING_DURATION);
        assertEq(vesting.getRemainingAmount(), VESTED_AMOUNT);
        
        // 释放一部分后再测试
        vm.warp(block.timestamp + CLIFF_DURATION + MONTH_DURATION);
        vesting.release();
        
        uint256 released = VESTED_AMOUNT / 24;
        assertEq(vesting.getRemainingAmount(), VESTED_AMOUNT - released);
    }
    
    /**
     * @dev 测试事件触发
     */
    function testReleaseEvent() public {
        vm.warp(block.timestamp + CLIFF_DURATION + MONTH_DURATION);
        
        uint256 expectedAmount = VESTED_AMOUNT / 24;
        
        vm.expectEmit(true, false, false, true);
        emit TokenVesting.Released(beneficiary, expectedAmount);
        
        vesting.release();
    }
    
    /**
     * @dev 测试任何人都可以调用release函数
     */
    function testAnyoneCanCallRelease() public {
        vm.warp(block.timestamp + CLIFF_DURATION + MONTH_DURATION);
        
        // 使用不同的地址调用release
        address randomCaller = address(0x999);
        vm.prank(randomCaller);
        
        uint256 expectedAmount = VESTED_AMOUNT / 24;
        vesting.release();
        
        // 代币应该转给受益人，而不是调用者
        assertEq(token.balanceOf(beneficiary), expectedAmount);
        assertEq(token.balanceOf(randomCaller), 0);
    }
    
    /**
     * @dev 测试边界情况：cliff期最后一秒
     */
    function testCliffBoundary() public {
        // cliff期最后一秒
        vm.warp(block.timestamp + CLIFF_DURATION - 1);
        assertEq(vesting.getReleasableAmount(), 0);
        
        // cliff期结束的第一秒
        vm.warp(block.timestamp + 1);
        assertEq(vesting.getReleasableAmount(), 0); // 线性释放还没开始
        
        // 第一个月结束
        vm.warp(block.timestamp + MONTH_DURATION);
        assertEq(vesting.getReleasableAmount(), VESTED_AMOUNT / 24);
    }
}