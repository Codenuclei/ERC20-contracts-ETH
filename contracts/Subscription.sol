// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Subscription is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct SubscriptionPlan {
        uint256 price;
        uint256 duration;
        bool active;
    }

    struct UserSubscription {
        uint256 planId;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }

    mapping(uint256 => SubscriptionPlan) public plans;
    mapping(address => UserSubscription) public subscriptions;
    uint256 public nextPlanId;
    IERC20 public paymentToken;

    event PlanCreated(uint256 planId, uint256 price, uint256 duration);
    event SubscriptionPurchased(address subscriber, uint256 planId, uint256 startTime, uint256 endTime);
    event SubscriptionCancelled(address subscriber);
    event SubscriptionRenewed(address subscriber, uint256 planId, uint256 newEndTime);

    constructor(address _paymentToken) Ownable(msg.sender) {
        paymentToken = IERC20(_paymentToken);
        nextPlanId = 1;
    }

    function createPlan(uint256 _price, uint256 _duration) external onlyOwner {
        require(_duration > 0, "Duration must be greater than 0");
        plans[nextPlanId] = SubscriptionPlan(_price, _duration, true);
        emit PlanCreated(nextPlanId, _price, _duration);
        nextPlanId++;
    }

    function subscribe(uint256 _planId) external nonReentrant whenNotPaused {
        require(plans[_planId].active, "Plan does not exist or is not active");
        require(!subscriptions[msg.sender].active, "Already subscribed");

        uint256 price = plans[_planId].price;
        paymentToken.safeTransferFrom(msg.sender, address(this), price);

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + plans[_planId].duration;

        subscriptions[msg.sender] = UserSubscription(_planId, startTime, endTime, true);
        emit SubscriptionPurchased(msg.sender, _planId, startTime, endTime);
    }

    function renewSubscription() external nonReentrant whenNotPaused {
        UserSubscription storage sub = subscriptions[msg.sender];
        require(sub.active, "No active subscription");
        
        SubscriptionPlan storage plan = plans[sub.planId];
        require(plan.active, "Plan no longer active");

        paymentToken.safeTransferFrom(msg.sender, address(this), plan.price);

        uint256 newEndTime;
        if (block.timestamp > sub.endTime) {
            newEndTime = block.timestamp + plan.duration;
        } else {
            newEndTime = sub.endTime + plan.duration;
        }
        
        sub.endTime = newEndTime;
        emit SubscriptionRenewed(msg.sender, sub.planId, newEndTime);
    }

    function cancelSubscription() external whenNotPaused {
        require(subscriptions[msg.sender].active, "No active subscription");
        subscriptions[msg.sender].active = false;
        emit SubscriptionCancelled(msg.sender);
    }

    function isSubscribed(address _subscriber) external view returns (bool) {
        return subscriptions[_subscriber].active && 
               block.timestamp < subscriptions[_subscriber].endTime;
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = paymentToken.balanceOf(address(this));
        paymentToken.safeTransfer(owner(), balance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
