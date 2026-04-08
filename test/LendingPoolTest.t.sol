// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {MyToken} from "../src/MyToken.sol";

contract LendingPoolTest is Test {
    LendingPool pool;
    MyToken collateral;
    MyToken borrow;

    address alice = makeAddr("alice");
    address liquidator = makeAddr("liquidator");

    function setUp() public {
        collateral = new MyToken("Collateral", "COL", 1_000_000);
        borrow = new MyToken("Borrow", "BRW", 1_000_000);
        pool = new LendingPool(address(collateral), address(borrow), 1e18, 1e18);

        require(borrow.transfer(address(pool), 500_000 * 1e18));
        require(collateral.transfer(alice, 10_000 * 1e18));
        require(borrow.transfer(liquidator, 50_000 * 1e18));
    }

    function test_DepositAndWithdraw() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 1e18);
        pool.deposit(1000 * 1e18);
        pool.withdraw(1000 * 1e18);
        vm.stopPrank();
        assertEq(collateral.balanceOf(alice), 10_000 * 1e18);
    }

    function test_BorrowExceedsLTVReverts() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 1e18);
        pool.deposit(1000 * 1e18);
        vm.expectRevert("exceeds LTV limit");
        pool.borrow(751 * 1e18);
        vm.stopPrank();
    }

    function test_LiquidationScenario() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 1e18);
        pool.deposit(1000 * 1e18);
        pool.borrow(750 * 1e18);
        vm.stopPrank();

        pool.setCollateralPrice(0.8e18);
        assertLt(pool.getHealthFactor(alice), 1e18);

        vm.startPrank(liquidator);
        borrow.approve(address(pool), 800 * 1e18);
        pool.liquidate(alice);
        vm.stopPrank();

        (uint256 col, uint256 debt, ) = pool.positions(alice);
        assertEq(debt, 0);
        assertEq(col, 0);
    }

    function test_InterestAccrualOverTime() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 1e18);
        pool.deposit(1000 * 1e18);
        pool.borrow(100 * 1e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);
        vm.prank(alice);
        pool.getHealthFactor(alice);

        (, uint256 debt, ) = pool.positions(alice);
        
        if (debt == 100 * 1e18) {
            vm.prank(alice);
            pool.borrow(0);
            (, debt, ) = pool.positions(alice);
        }

        assertEq(debt, 105 * 1e18);
    }

    function test_RepayFull() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 * 1e18);
        pool.deposit(1000 * 1e18);
        pool.borrow(100 * 1e18);
        
        borrow.approve(address(pool), 200 * 1e18);
        
        (, uint256 currentDebt, ) = pool.positions(alice);
        pool.repay(currentDebt);
        
        (, uint256 finalDebt, ) = pool.positions(alice);
        assertEq(finalDebt, 0);
        vm.stopPrank();
    }
}