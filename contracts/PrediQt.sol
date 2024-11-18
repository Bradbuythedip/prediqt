// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title PrediQt
 * @notice Prediction markets for Quai Network metrics
 */
contract PrediQt is Ownable, ReentrancyGuard {
    struct Market {
        string title;           // Market title
        string description;     // Market details
        uint256 endTime;        // When predictions close
        uint256 totalStaked;    // Total QUAI staked
        bool resolved;          // Whether market is resolved
        uint256 outcome;        // Winning outcome value
        mapping(address => Position) positions;
    }

    struct Position {
        uint256 prediction;     // User's predicted value
        uint256 amount;         // Amount staked
        bool claimed;           // Whether winnings are claimed
    }

    // State
    mapping(uint256 => Market) public markets;
    uint256 public marketCount;
    uint256 public fee = 150;   // 1.5% fee (basis points)

    // Events
    event MarketCreated(uint256 indexed id, string title, uint256 endTime);
    event PredictionMade(uint256 indexed id, address indexed user, uint256 prediction, uint256 amount);
    event MarketResolved(uint256 indexed id, uint256 outcome);
    event WinningsClaimed(uint256 indexed id, address indexed user, uint256 amount);

    /**
     * @notice Create a new prediction market
     * @param title Market title/question
     * @param description Detailed market description
     * @param endTime When predictions close
     */
    function createMarket(
        string calldata title,
        string calldata description,
        uint256 endTime
    ) external onlyOwner {
        require(endTime > block.timestamp, "End time must be future");
        
        uint256 id = marketCount++;
        Market storage market = markets[id];
        
        market.title = title;
        market.description = description;
        market.endTime = endTime;
        
        emit MarketCreated(id, title, endTime);
    }

    /**
     * @notice Make a prediction in a market
     * @param id Market ID
     * @param prediction Predicted value
     */
    function predict(uint256 id, uint256 prediction) external payable nonReentrant {
        Market storage market = markets[id];
        require(block.timestamp < market.endTime, "Market closed");
        require(!market.resolved, "Market resolved");
        require(msg.value > 0, "Must stake something");

        Position storage pos = market.positions[msg.sender];
        
        // Update position
        pos.prediction = prediction;
        pos.amount += msg.value;
        pos.claimed = false;

        // Update market
        market.totalStaked += msg.value;

        emit PredictionMade(id, msg.sender, prediction, msg.value);
    }

    /**
     * @notice Resolve a market with the actual outcome
     * @param id Market ID
     * @param outcome Actual outcome value
     */
    function resolveMarket(uint256 id, uint256 outcome) external onlyOwner {
        Market storage market = markets[id];
        require(block.timestamp >= market.endTime, "Market still open");
        require(!market.resolved, "Already resolved");

        market.resolved = true;
        market.outcome = outcome;

        emit MarketResolved(id, outcome);
    }

    /**
     * @notice Claim winnings for a resolved market
     * @param id Market ID
     */
    function claimWinnings(uint256 id) external nonReentrant {
        Market storage market = markets[id];
        require(market.resolved, "Not resolved");

        Position storage pos = market.positions[msg.sender];
        require(pos.amount > 0, "No position");
        require(!pos.claimed, "Already claimed");
        require(pos.prediction == market.outcome, "Not a winner");

        // Calculate winnings
        uint256 winnerPool = getWinnerPool(id);
        uint256 feeAmount = (market.totalStaked * fee) / 10000;
        uint256 winningPool = market.totalStaked - feeAmount;
        uint256 winnings = (pos.amount * winningPool) / winnerPool;

        // Update state
        pos.claimed = true;

        // Transfer winnings
        (bool sent,) = payable(msg.sender).call{value: winnings}("");
        require(sent, "Transfer failed");

        emit WinningsClaimed(id, msg.sender, winnings);
    }

    /**
     * @notice Get total amount staked on winning prediction
     * @param id Market ID
     */
    function getWinnerPool(uint256 id) public view returns (uint256) {
        Market storage market = markets[id];
        require(market.resolved, "Not resolved");

        uint256 total = 0;
        // In production, we'd need a more gas-efficient way to track this
        return total;
    }

    /**
     * @notice Get user's position in a market
     * @param id Market ID
     * @param user Address to check
     */
    function getPosition(uint256 id, address user) 
        external 
        view 
        returns (uint256 prediction, uint256 amount, bool claimed) 
    {
        Position storage pos = markets[id].positions[user];
        return (pos.prediction, pos.amount, pos.claimed);
    }

    /**
     * @notice Get market details
     * @param id Market ID
     */
    function getMarket(uint256 id)
        external
        view
        returns (
            string memory title,
            string memory description,
            uint256 endTime,
            uint256 totalStaked,
            bool resolved,
            uint256 outcome
        )
    {
        Market storage market = markets[id];
        return (
            market.title,
            market.description,
            market.endTime,
            market.totalStaked,
            market.resolved,
            market.outcome
        );
    }

    /**
     * @notice Update platform fee
     * @param newFee New fee in basis points
     */
    function setFee(uint256 newFee) external onlyOwner {
        require(newFee <= 300, "Fee too high"); // Max 3%
        fee = newFee;
    }

    /**
     * @notice Withdraw collected fees
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees");
        
        (bool sent,) = payable(owner()).call{value: balance}("");
        require(sent, "Transfer failed");
    }
}