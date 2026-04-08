// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract LendingPool {
    address public collateralToken;
    address public borrowToken;

    uint256 public collateralPrice;
    uint256 public borrowTokenPrice;

    uint256 public constant LTV = 75;
    uint256 public constant LIQUIDATION_THRESHOLD = 80;
    uint256 public constant INTEREST_RATE_PER_YEAR = 5;
    uint256 public constant SECONDS_IN_YEAR = 365 days;

    struct Position {
        uint256 collateral;
        uint256 debt;
        uint256 lastUpdate;
    }

    mapping(address => Position) public positions;

    address public owner;

    event Deposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Liquidated(address indexed user, address indexed liquidator, uint256 collateral, uint256 debt);

    constructor(address _collateralToken, address _borrowToken, uint256 _collateralPrice, uint256 _borrowPrice) {
        collateralToken = _collateralToken;
        borrowToken = _borrowToken;
        collateralPrice = _collateralPrice;
        borrowTokenPrice = _borrowPrice;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function setCollateralPrice(uint256 newPrice) external onlyOwner {
        collateralPrice = newPrice;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "zero amount");
        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        positions[msg.sender].collateral += amount;
        if (positions[msg.sender].lastUpdate == 0) {
            positions[msg.sender].lastUpdate = block.timestamp;
        }
        emit Deposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "zero amount");
        _accrueInterest(msg.sender);

        uint256 collateralValue = positions[msg.sender].collateral * collateralPrice / 1e18;
        uint256 maxBorrow = collateralValue * LTV / 100;
        uint256 newDebtValue = (positions[msg.sender].debt + amount) * borrowTokenPrice / 1e18;

        require(newDebtValue <= maxBorrow, "exceeds LTV limit");

        positions[msg.sender].debt += amount;

        IERC20(borrowToken).transfer(msg.sender, amount);
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0, "zero amount");
        _accrueInterest(msg.sender);

        uint256 currentDebt = positions[msg.sender].debt;
        if (amount > currentDebt) {
            amount = currentDebt;
        }

        IERC20(borrowToken).transferFrom(msg.sender, address(this), amount);
        positions[msg.sender].debt -= amount;
        emit Repaid(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "zero amount");
        require(positions[msg.sender].collateral >= amount, "not enough collateral");
        _accrueInterest(msg.sender);

        positions[msg.sender].collateral -= amount;

        if (positions[msg.sender].debt > 0) {
            require(getHealthFactor(msg.sender) >= 1e18, "health factor too low");
        }

        IERC20(collateralToken).transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function liquidate(address user) external {
        _accrueInterest(user);
        require(getHealthFactor(user) < 1e18, "position is healthy");

        uint256 debt = positions[user].debt;
        uint256 collateral = positions[user].collateral;

        positions[user].debt = 0;
        positions[user].collateral = 0;

        IERC20(borrowToken).transferFrom(msg.sender, address(this), debt);
        IERC20(collateralToken).transfer(msg.sender, collateral);

        emit Liquidated(user, msg.sender, collateral, debt);
    }

    function _accrueInterest(address user) internal {
        if (positions[user].debt == 0 || positions[user].lastUpdate == 0) {
            positions[user].lastUpdate = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - positions[user].lastUpdate;
        uint256 interest = positions[user].debt * INTEREST_RATE_PER_YEAR * elapsed / (100 * SECONDS_IN_YEAR);
        positions[user].debt += interest;
        positions[user].lastUpdate = block.timestamp;
    }

    function getHealthFactor(address user) public view returns (uint256) {
        if (positions[user].debt == 0) return type(uint256).max;

        uint256 collateralValue = positions[user].collateral * collateralPrice / 1e18;
        uint256 threshold = collateralValue * LIQUIDATION_THRESHOLD / 100;
        uint256 debtValue = positions[user].debt * borrowTokenPrice / 1e18;

        return threshold * 1e18 / debtValue;
    }
}