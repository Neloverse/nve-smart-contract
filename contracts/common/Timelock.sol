// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Timelock is ReentrancyGuard {
    using SafeMath for uint256;

    /// @notice GLOBAL CONSTANTS
    uint256 private depositId;
    uint256[] private allDepositIds;
    uint public constant MINIMUM_DELAY = 7;
    uint public constant MAXIMUM_DELAY = 30;

    mapping(uint256 => Items) private lockedToken;
    mapping(address => mapping(uint256 => uint256)) private walletTokenBalance;

    /// @notice EVENTS
    event Deposit(address indexed tokenAddress, address indexed sender, uint256 amount, uint256 unlockTime, uint256 depositId);
    event Withdraw(address indexed tokenAddress, address indexed receiver, uint256 amount);

    /// @notice struct of locked item
    struct Items {
        address tokenAddress;
        uint256 tokenAmount;
        uint256 unlockTime;
        address owner;
        bool withdrawn;
    }

    /// @notice TIMELOCK FUNCTIONS
    /// @notice deposit function
    function deposit(
        address _tokenAddress,
        address _owner,
        uint256 _amount,
        uint256 _unlockTime
    ) external returns (uint256 _id) {
        require(_amount > 0, "Timelock: Tokens amount must be greater than 0.");
        require(_unlockTime >= MINIMUM_DELAY, "Timelock: Unlock time must exceed minimum delay.");
        require(_unlockTime <= MAXIMUM_DELAY, "Timelock: Unlock time must not exceed maximum delay.");

        require(IERC20(_tokenAddress).approve(address(this), _amount), "Timelock: Failed to approve tokens.");
        require(IERC20(_tokenAddress).balanceOf(address(this)) > 0, "Timelock: Don't have tokens to lock.");

        uint256 lockAmount = _amount;

        _id = ++depositId;

        lockedToken[_id].tokenAddress = _tokenAddress;
        lockedToken[_id].tokenAmount = lockAmount;
        lockedToken[_id].unlockTime = endDate(_unlockTime);
        lockedToken[_id].owner = _owner;
        lockedToken[_id].withdrawn = false;

        allDepositIds.push(_id);
        walletTokenBalance[_tokenAddress][_id] = walletTokenBalance[_tokenAddress][_id].add(_amount);

        emit Deposit(_tokenAddress, msg.sender, _amount, _unlockTime, depositId);
    }

    /// @notice withdraw function
    function withdraw(
        uint256 _id,
        uint256 _amount,
        address _withdrawalAddress
    ) external {
        require(block.timestamp >= lockedToken[_id].unlockTime, "Timelock: Tokens have been locked");
        require(!lockedToken[_id].withdrawn, "Timelock: Tokens already withdrawn.");
        require(_withdrawalAddress != address(0), "Timelock: Withdraw cannot be 0.");
        require(lockedToken[_id].owner == msg.sender, "Timelock: You are not the owner.");

        address tokenAddress = lockedToken[_id].tokenAddress;
        lockedToken[_id].tokenAmount = lockedToken[_id].tokenAmount.sub(_amount);

        require(IERC20(tokenAddress).balanceOf(address(this)) > 0, "Timelock: Don't have tokens to withdraw.");
        require(IERC20(tokenAddress).transferFrom(address(this), _withdrawalAddress, _amount), "Timelock: Failed to transfer tokens.");

        if (lockedToken[_id].tokenAmount <= 0) {
            lockedToken[_id].withdrawn = true;
        }

        uint256 previousBalance = walletTokenBalance[tokenAddress][_id];
        walletTokenBalance[tokenAddress][_id] = previousBalance.sub(_amount);

        emit Withdraw(tokenAddress, _withdrawalAddress, _amount);
    }

    /// @notice GETTER FUNCTIONS
    function getTokenBalanceByAddress(address _tokenAddress, uint256 _id) view public returns (uint256) {
        return walletTokenBalance[_tokenAddress][_id];
    }

    function getDepositDetails(uint256 _id) view public returns (address, uint256, uint256, bool) {
        return (lockedToken[_id].tokenAddress, lockedToken[_id].tokenAmount, lockedToken[_id].unlockTime, lockedToken[_id].withdrawn);
    }

    /// @notice HELPER FUNCTIONS
    function endDate(uint256 _days) internal view returns (uint256) {
        return block.timestamp + _days * 1 days;
    }
}