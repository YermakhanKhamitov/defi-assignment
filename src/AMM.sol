// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LPToken.sol";

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

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        uint256 totalLP = lpToken.totalSupply();

        if (totalLP == 0) {
            lpAmount = _sqrt(amountA * amountB);
        } else {
            uint256 lpFromA = (amountA * totalLP) / reserveA;
            uint256 lpFromB = (amountB * totalLP) / reserveB;
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

        uint256 totalLP = lpToken.totalSupply();
        amountA = (lpAmount * reserveA) / totalLP;
        amountB = (lpAmount * reserveB) / totalLP;

        require(amountA > 0 && amountB > 0, "zero amounts out");

        lpToken.burn(msg.sender, lpAmount);
        reserveA -= amountA;
        reserveB -= amountB;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

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
        require(amountIn > 0, "zero amount");

        bool isA = tokenIn == tokenA;
        (uint256 reserveIn, uint256 reserveOut) = isA ? (reserveA, reserveB) : (reserveB, reserveA);
        address tokenOut = isA ? tokenB : tokenA;

        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= minAmountOut, "slippage: too little received");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

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