// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";
import "../src/MyToken.sol";

contract LendingPoolTest is Test {
    LendingPool pool;
    MyToken collateral;
    MyToken borrow;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        collateral = new MyToken("Collateral", "COL", 1000000);
        borrow = new MyToken("Borrow", "BRW", 1000000);

        pool = new LendingPool(address(collateral), address(borrow), 1e18, 1e18);

        borrow.transfer(address(pool), 100000 * 10 ** 18);

        collateral.transfer(alice, 10000 * 10 ** 18);
        borrow.transfer(alice, 10000 * 10 ** 18);
        collateral.transfer(bob, 10000 * 10 ** 18);
        borrow.transfer(bob, 10000 * 10 ** 18);
    }

    function test_Deposit() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 10 ** 18);
        pool.deposit(1000 * 10 ** 18);
        vm.stopPrank();

        (uint256 dep,,) = pool.positions(alice);
        assertEq(dep, 1000 * 10 ** 18);
    }

    function test_BorrowWithinLTV() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 10 ** 18);
        pool.deposit(1000 * 10 ** 18);

        uint256 balanceBefore = borrow.balanceOf(alice);
        pool.borrow(700 * 10 ** 18);
        vm.stopPrank();

        assertEq(borrow.balanceOf(alice) - balanceBefore, 700 * 10 ** 18);
    }

    function test_BorrowExceedsLTVReverts() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 10 ** 18);
        pool.deposit(1000 * 10 ** 18);

        vm.expectRevert("exceeds LTV limit");
        pool.borrow(800 * 10 ** 18);
        vm.stopPrank();
    }

    function test_RepayPartial() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 10 ** 18);
        pool.deposit(1000 * 10 ** 18);
        pool.borrow(700 * 10 ** 18);

        borrow.approve(address(pool), 300 * 10 ** 18);
        pool.repay(300 * 10 ** 18);
        vm.stopPrank();

        (, uint256 debt,) = pool.positions(alice);
        assertEq(debt, 400 * 10 ** 18);
    }

    function test_RepayFull() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 10 ** 18);
        pool.deposit(1000 * 10 ** 18);
        pool.borrow(700 * 10 ** 18);

        borrow.approve(address(pool), 700 * 10 ** 18);
        pool.repay(700 * 10 ** 18);
        vm.stopPrank();

        (, uint256 debt,) = pool.positions(alice);
        assertEq(debt, 0);
    }

    function test_WithdrawAfterRepay() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 10 ** 18);
        pool.deposit(1000 * 10 ** 18);
        pool.borrow(700 * 10 ** 18);

        borrow.approve(address(pool), 700 * 10 ** 18);
        pool.repay(700 * 10 ** 18);

        uint256 balanceBefore = collateral.balanceOf(alice);
        pool.withdraw(1000 * 10 ** 18);
        vm.stopPrank();

        assertGt(collateral.balanceOf(alice), balanceBefore);
    }

    function test_WithdrawWithDebtRevertsIfHealthFactorLow() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 10 ** 18);
        pool.deposit(1000 * 10 ** 18);
        pool.borrow(700 * 10 ** 18);

        vm.expectRevert("health factor too low");
        pool.withdraw(500 * 10 ** 18);
        vm.stopPrank();
    }

    function test_LiquidateUndercollateralizedPosition() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 10 ** 18);
        pool.deposit(1000 * 10 ** 18);
        pool.borrow(700 * 10 ** 18);
        vm.stopPrank();

        pool.setCollateralPrice(0.5e18);

        uint256 hf = pool.getHealthFactor(alice);
        assertLt(hf, 1e18);

        uint256 bobCollateralBefore = collateral.balanceOf(bob);

        vm.startPrank(bob);
        borrow.approve(address(pool), 700 * 10 ** 18);
        pool.liquidate(alice);
        vm.stopPrank();

        assertGt(collateral.balanceOf(bob), bobCollateralBefore);

        (, uint256 debt,) = pool.positions(alice);
        assertEq(debt, 0);
    }

    function test_InterestAccrualOverTime() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 10 ** 18);
        pool.deposit(1000 * 10 ** 18);
        pool.borrow(700 * 10 ** 18);
        vm.stopPrank();

        (, uint256 debtBefore,) = pool.positions(alice);

        vm.warp(block.timestamp + 365 days);

        vm.startPrank(alice);
        borrow.approve(address(pool), 1 * 10 ** 18);
        pool.repay(1 * 10 ** 18);
        vm.stopPrank();

        (, uint256 debtAfter,) = pool.positions(alice);
        assertGt(debtAfter, debtBefore - 1 * 10 ** 18);
    }

    function test_BorrowWithZeroCollateralReverts() public {
        vm.startPrank(alice);
        vm.expectRevert("exceeds LTV limit");
        pool.borrow(100 * 10 ** 18);
        vm.stopPrank();
    }
}