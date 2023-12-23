//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Bank.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract BankTest is Test {

    error NotFirstPeriod();
    error NotWithdrawPeriod();
    error CantWithdraw();
    error NoDepositFound();
    error NoRewardsLeft();
    error CantRenounceOwnership();

    Bank public bank;
    address admin = address(123);
    address user1 = address(456);
    address user2 = address(789);
    address user3 = address(753);

    IERC20 public token;

    event Deposited(address indexed user, uint256 indexed amount);
    event Withdrawn(address indexed user, uint256 indexed totalAmount, uint256 indexed rewardAmount);
    event OwnerWithdrawn(address indexed adminAddress, uint256 indexed remainingRewards);


    function setUp() public {
        vm.startPrank(admin);
        token = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        deal(address(token), admin, 1000*10**18, true);
        token.approve(computeCreateAddress(admin, 0), 1000*10**18);
        bank = new Bank(1, 0x6B175474E89094C44Da98b954EedeAC495271d0F, 1000*10**18);
        vm.stopPrank();
    }

    function testConstructor() public {
        assertEq(token.balanceOf(address(bank)), 1000*10**18);
        assertEq(bank.timePeriod(), 86400);
        assertEq(bank.tokenAddress(), 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        assertEq(bank.poolR(), 1000*10**18);
        assertEq(bank.startingPoolR2(), 300*10**18);
        assertEq(bank.startingPoolR3(), 500*10**18);
    }

    function testDeposit() public {
        vm.startPrank(user1);

        deal(address(token), user1, 1000*10**18, true);
        token.approve(address(bank), 1000*10**18);

        vm.expectEmit(true, true, false, false);
        emit Deposited(user1, 1000*10**18);

        bank.deposit_ps2(1000*10**18);

        assertEq(bank.totalStaked(), 1000*10**18);
        assertEq(bank.deposits(user1), 1000*10**18);
    }

    function testDepositMulitple() public {
        deal(address(token), user1, 1000*10**18, true);
        deal(address(token), user2, 4000*10**18, true);

        vm.prank(user1);
        token.approve(address(bank), 1000*10**18);

        vm.prank(user1);
        bank.deposit_ps2(1000*10**18);

        vm.prank(user2);
        token.approve(address(bank), 4000*10**18);

        vm.prank(user2);
        bank.deposit_ps2(4000*10**18);

        assertEq(bank.totalStaked(), 5000*10**18);
        assertEq(bank.deposits(user1), 1000*10**18);
        assertEq(bank.deposits(user2), 4000*10**18);
    }

    function testDepositNotFirstPeriod() public {
        vm.startPrank(user1);

        deal(address(token), user1, 1000*10**18, true);
        token.approve(address(bank), 1000*10**18);

        skip(86400);

        vm.expectRevert(NotFirstPeriod.selector);

        bank.deposit_ps2(1000*10**18);
    }

    function testWithdraw() public {
        deal(address(token), user1, 1000*10**18, true);
        deal(address(token), user2, 4000*10**18, true);

        vm.prank(user1);
        token.approve(address(bank), 1000*10**18);

        vm.prank(user1);
        bank.deposit_ps2(1000*10**18);

        vm.prank(user2);
        token.approve(address(bank), 4000*10**18);

        vm.prank(user2);
        bank.deposit_ps2(4000*10**18);

        skip(86400*2);

        vm.expectEmit(true, true, true, false);
        emit Withdrawn(user1, 1040*10**18, 40*10**18);

        vm.prank(user1);
        bank.withdraw();

        assertEq(bank.totalStaked(), 4000*10**18);
        assertEq(bank.deposits(user1), 0);
        assertEq(bank.poolR(), 960*10**18);

        skip(86400);

        vm.expectEmit(true, true, true, false);
        emit Withdrawn(user2, 4460*10**18, 460*10**18);

        vm.prank(user2);
        bank.withdraw();

        assertEq(bank.totalStaked(), 0);
        assertEq(bank.deposits(user2), 0);
        assertEq(bank.poolR(), 500*10**18);
    }

    function testWithdrawAllThreePeriods() public {
        deal(address(token), user1, 1000*10**18, true);
        deal(address(token), user2, 1000*10**18, true);
        deal(address(token), user3, 1000*10**18, true);

        vm.prank(user1);
        token.approve(address(bank), 1000*10**18);

        vm.prank(user1);
        bank.deposit_ps2(1000*10**18);

        vm.prank(user2);
        token.approve(address(bank), 1000*10**18);

        vm.prank(user2);
        bank.deposit_ps2(1000*10**18);

        vm.prank(user3);
        token.approve(address(bank), 1000*10**18);

        vm.prank(user3);
        bank.deposit_ps2(1000*10**18);

        skip(86400*2);

        vm.expectEmit(true, true, true, false);
        emit Withdrawn(user1, 1066*10**18, 66*10**18);

        vm.prank(user1);
        bank.withdraw();

        assertEq(bank.totalStaked(), 2000*10**18);
        assertEq(bank.deposits(user1), 0);
        assertEq(bank.poolR(), 934*10**18);

        skip(86400);

        vm.expectEmit(true, true, true, false);
        emit Withdrawn(user2, 1217*10**18, 217*10**18);

        vm.prank(user2);
        bank.withdraw();

        assertEq(bank.totalStaked(), 1000*10**18);
        assertEq(bank.deposits(user2), 0);
        assertEq(bank.poolR(), 717*10**18);

        skip(86400);

        vm.expectEmit(true, true, true, false);
        emit Withdrawn(user3, 1717*10**18, 717*10**18);

        vm.prank(user3);
        bank.withdraw();

        assertEq(bank.totalStaked(), 0);
        assertEq(bank.deposits(user3), 0);
        assertEq(bank.poolR(), 0);
    }

    function testWithdrawFirstPeriod() public {
        deal(address(token), user1, 1000*10**18, true);

        vm.startPrank(user1);

        token.approve(address(bank), 1000*10**18);
    
        bank.deposit_ps2(1000*10**18);

        skip(86400*2);

        vm.expectEmit(true, true, true, false);
        emit Withdrawn(user1, 1200*10**18, 200*10**18);

        bank.withdraw();   

        assertEq(bank.totalStaked(), 0);
        assertEq(bank.deposits(user1), 0);
        assertEq(bank.poolR(), 800*10**18);     
    }

    function testWithdrawSecondPeriod() public {
        deal(address(token), user1, 1000*10**18, true);

        vm.startPrank(user1);

        token.approve(address(bank), 1000*10**18);
    
        bank.deposit_ps2(1000*10**18);

        skip(86400*3);

        vm.expectEmit(true, true, true, false);
        emit Withdrawn(user1, 1500*10**18, 500*10**18);

        bank.withdraw();  

        assertEq(bank.totalStaked(), 0);
        assertEq(bank.deposits(user1), 0);
        assertEq(bank.poolR(), 500*10**18);      
    }

    function testWithdrawFinalPeriod() public {
        deal(address(token), user1, 1000*10**18, true);

        vm.startPrank(user1);

        token.approve(address(bank), 1000*10**18);
    
        bank.deposit_ps2(1000*10**18);

        skip(86400*4);

        vm.expectEmit(true, true, true, false);
        emit Withdrawn(user1, 2000*10**18, 1000*10**18);

        bank.withdraw();    

        assertEq(bank.totalStaked(), 0);
        assertEq(bank.deposits(user1), 0);
        assertEq(bank.poolR(), 0);
    }

    function testWithdrawNotWithdrawPeriod() public {
        deal(address(token), user1, 1000*10**18, true);

        vm.startPrank(user1);
        token.approve(address(bank), 1000*10**18);
        bank.deposit_ps2(1000*10**18);

        skip(90_000);

        vm.expectRevert(NotWithdrawPeriod.selector);

        bank.withdraw();
    }

    function testWithdrawNoDepositFound() public {
        deal(address(token), user1, 1000*10**18, true);

        vm.startPrank(user1);
        token.approve(address(bank), 1000*10**18);
        bank.deposit_ps2(1000*10**18);
        vm.stopPrank();

        skip(86400*2);

        vm.expectRevert(NoDepositFound.selector);

        vm.prank(user2);
        bank.withdraw();
    }

    function testBankWithdraw() public {
        deal(address(token), user1, 1000*10**18, true);
        deal(address(token), user2, 4000*10**18, true);

        vm.prank(user1);
        token.approve(address(bank), 1000*10**18);

        vm.prank(user1);
        bank.deposit_ps2(1000*10**18);

        vm.prank(user2);
        token.approve(address(bank), 4000*10**18);

        vm.prank(user2);
        bank.deposit_ps2(4000*10**18);

        skip(86400*2);

        vm.prank(user1);
        bank.withdraw();

        skip(86400);

        vm.prank(user2);
        bank.withdraw();

        skip(86400);

        vm.expectEmit(true, true, false, false);
        emit OwnerWithdrawn(admin, 500*10**18);

        vm.prank(admin);
        bank.bankWithdraw();

        assertEq(bank.poolR(), 0);
    }

    function testBankWithdrawCantWithdraw() public {
        deal(address(token), user1, 1000*10**18, true);
        deal(address(token), user2, 4000*10**18, true);

        vm.prank(user1);
        token.approve(address(bank), 1000*10**18);

        vm.prank(user1);
        bank.deposit_ps2(1000*10**18);

        vm.prank(user2);
        token.approve(address(bank), 4000*10**18);

        vm.prank(user2);
        bank.deposit_ps2(4000*10**18);

        skip(86400*2);

        vm.prank(user1);
        bank.withdraw();

        skip(86400);

        vm.prank(user2);
        bank.withdraw();

        vm.expectRevert(CantWithdraw.selector);

        vm.prank(admin);
        bank.bankWithdraw();
    }

    function testBankWithdrawNoRewardsLeft() public {
        deal(address(token), user1, 1000*10**18, true);

        vm.prank(user1);
        token.approve(address(bank), 1000*10**18);

        vm.prank(user1);
        bank.deposit_ps2(1000*10**18);

        skip(86400*4);

        vm.prank(user1);
        bank.withdraw();

        vm.expectRevert(NoRewardsLeft.selector);

        vm.prank(admin);
        bank.bankWithdraw();
    }

    function testRenounceOwnership() public {
        vm.prank(admin);
        vm.expectRevert(CantRenounceOwnership.selector);
        bank.renounceOwnership();
    }
}