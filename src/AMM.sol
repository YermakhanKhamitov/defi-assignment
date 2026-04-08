// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LPToken} from "./LPToken.sol";
interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract AMM {
    address public tokenA;
    address public tokenB;
    LPToken public lpToken;

    uint256 public reserveA;
    uint256 public reserveB;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpBurned);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        lpToken = new LPToken(address(this));
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 lpAmount) {
        require(amountA > 0 && amountB > 0, "zero amounts");

        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "A fail");
        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountB), "B fail");

        uint256 totalLp = lpToken.totalSupply();

        if (totalLp == 0) {
            lpAmount = _sqrt(amountA * amountB);
        } else {
            uint256 lpFromA = (amountA * totalLp) / reserveA;
            uint256 lpFromB = (amountB * totalLp) / reserveB;
            lpAmount = lpFromA < lpFromB ? lpFromA : lpFromB;
        }

        require(lpAmount > 0, "zero lp");
        reserveA += amountA;
        reserveB += amountB;

        lpToken.mint(msg.sender, lpAmount);
        emit LiquidityAdded(msg.sender, amountA, amountB, lpAmount);
    }

    function removeLiquidity(uint256 lpAmount) external returns (uint256 amountA, uint256 amountB) {
        require(lpAmount > 0, "zero lp");

        uint256 totalLp = lpToken.totalSupply();
        amountA = (lpAmount * reserveA) / totalLp;
        amountB = (lpAmount * reserveB) / totalLp;

        require(amountA > 0 && amountB > 0, "zero amounts out");

        lpToken.burn(msg.sender, lpAmount);
        reserveA -= amountA;
        reserveB -= amountB;

        require(IERC20(tokenA).transfer(msg.sender, amountA), "A out fail");
        require(IERC20(tokenB).transfer(msg.sender, amountB), "B out fail");

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "zero amount");
        require(reserveIn > 0 && reserveOut > 0, "empty reserves");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        require(tokenIn == tokenA || tokenIn == tokenB, "invalid token");
        
        bool isA = tokenIn == tokenA;
        (uint256 rIn, uint256 rOut) = isA ? (reserveA, reserveB) : (reserveB, reserveA);
        address tOut = isA ? tokenB : tokenA;

        amountOut = getAmountOut(amountIn, rIn, rOut);
        require(amountOut >= minAmountOut, "slippage: too little received");

        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "In fail");
        require(IERC20(tOut).transfer(msg.sender, amountOut), "Out fail");

        if (isA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}