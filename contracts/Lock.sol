// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title TokenStaking
 * @dev A contract allowing users to stake one token and receive another token as reward.
 */
contract TokenStaking {

    address public stakingToken;
    
    address public rewardToken;
    
    // Reward rate (10% = 1000 basis points)
    uint256 public constant REWARD_RATE = 1000;
    uint256 public constant BASIS_POINTS = 10000;
    
    // Staking duration
    uint256 public stakingDuration = 30;
    
    // Minimum staking amount (dummy)
    uint256 public minStakeAmount = 1 * 10**18;
    
    address public owner;
    
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        bool claimed;
    }
    
    mapping(address => StakeInfo[]) public userStakes;
    
    uint256 public totalStaked;
    
    // Events for interfacing 
    event Staked(address indexed user, uint256 amount, uint256 stakeId);
    event Unstaked(address indexed user, uint256 amount, uint256 reward, uint256 stakeId);
    event StakingDurationUpdated(uint256 newDuration);
    event MinStakeAmountUpdated(uint256 newAmount);
    event EmergencyWithdraw(address indexed user, uint256 amount, uint256 stakeId);
    
    // Must add: Modifier to restrict functions to owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    /**
     * @dev Constructor to initialize the staking contract
     * @param _stakingToken Address of the token to be staked
     * @param _rewardToken Address of the token given as reward
     */
    constructor(address _stakingToken, address _rewardToken) {
        require(_stakingToken != address(0), "Staking token cannot be zero address");
        require(_rewardToken != address(0), "Reward token cannot be zero address");
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        owner = msg.sender;
    }
    
    /**
     * @dev Allows users to stake tokens
     * @param amount The amount of tokens to stake
     */
    function stake(uint256 amount) external returns (uint256 stakeId) {
        require(amount >= minStakeAmount, "Amount below minimum stake amount");
        require(amount > 0, "Cannot stake 0");
        
        // Transfer tokens from user to contract
        require(IERC20(stakingToken).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
    
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + stakingDuration;
        
        // Storing staking info
        userStakes[msg.sender].push(StakeInfo({
            amount: amount,
            startTime: startTime,
            endTime: endTime,
            claimed: false
        }));
        
        stakeId = userStakes[msg.sender].length - 1;
        
        
        totalStaked += amount;
        
        
        emit Staked(msg.sender, amount, stakeId);
        
        return stakeId;
    }
    
    /**
     * @dev Allows users to unstake tokens and claim rewards
     * @param stakeId The ID of the stake to unstake
     */
    function unstake(uint256 stakeId) external {
        require(stakeId < userStakes[msg.sender].length, "Invalid stake ID");
        
        StakeInfo storage stakeInfo = userStakes[msg.sender][stakeId];
        require(!stakeInfo.claimed, "Already claimed");
        require(block.timestamp >= stakeInfo.endTime, "Staking period not finished");
        
        uint256 amount = stakeInfo.amount;
        uint256 reward = calculateReward(amount);
        
        // Mark as claimed else not
        stakeInfo.claimed = true;
        
        // Update total staked
        totalStaked -= amount;
        
        // Transfer staked tokens back to user
        require(IERC20(stakingToken).transfer(msg.sender, amount), "Transfer failed");
        
        // Transfer reward tokens to user
        require(IERC20(rewardToken).transfer(msg.sender, reward), "Transfer failed");
        
        emit Unstaked(msg.sender, amount, reward, stakeId);
    }

    //IMPORTANT: Emergency withdrawal are integral part for any staking contract
    /**
     * @dev Allows emergency withdrawal without rewards in case of issues
     * @param stakeId The ID of the stake to withdraw
     */
    function emergencyWithdraw(uint256 stakeId) external {
        require(stakeId < userStakes[msg.sender].length, "Invalid stake ID");
        
        StakeInfo storage stakeInfo = userStakes[msg.sender][stakeId];
        require(!stakeInfo.claimed, "Already claimed");
        
        uint256 amount = stakeInfo.amount;
        
        stakeInfo.claimed = true;
        
        // Update total staked
        totalStaked -= amount;
        
        // Transfer staked tokens back to user (no reward)
        require(IERC20(stakingToken).transfer(msg.sender, amount), "Transfer failed");
        
        emit EmergencyWithdraw(msg.sender, amount, stakeId);
    }
    
    /**
     * @dev Calculate reward based on staked amount
     * @param amount The amount of staked tokens
     * @return The reward amount
     */
    function calculateReward(uint256 amount) public pure returns (uint256) {
        return (amount * REWARD_RATE) / BASIS_POINTS;
    }
    
    /**
     * @dev Check if a stake is ready to be unstaked
     * @param user The address of the user
     * @param stakeId The ID of the stake to check
     * @return ready Boolean indicating if stake is ready to unstake
     * @return timeRemaining Seconds remaining until stake can be unstaked (0 if ready)
     */
    function isStakeReady(address user, uint256 stakeId) external view returns (bool ready, uint256 timeRemaining) {
        require(stakeId < userStakes[user].length, "Invalid stake ID");
        
        StakeInfo storage stakeInfo = userStakes[user][stakeId];
        
        if (stakeInfo.claimed) {
            return (false, 0); // Already claimed
        }
        
        if (block.timestamp >= stakeInfo.endTime) {
            return (true, 0); // Ready to unstake
        } else {
            return (false, stakeInfo.endTime - block.timestamp); // Not ready, return time remaining
        }
    }
    
    /**
     * @dev Get all stakes for a user
     * @param user The address of the user
     * @return Array of stake information
     */
    function getStakes(address user) external view returns (StakeInfo[] memory) {
        return userStakes[user];
    }
    
    /**
     * @dev Get the number of stakes for a user
     * @param user The address of the user
     * @return The number of stakes
     */
    function getStakeCount(address user) external view returns (uint256) {
        return userStakes[user].length;
    }
    
    /**
     * @dev Update staking duration (only owner)
     * @param newDuration The new staking duration in seconds
     */
    function updateStakingDuration(uint256 newDuration) external onlyOwner {
        require(newDuration > 0, "Duration cannot be 0");
        stakingDuration = newDuration;
        emit StakingDurationUpdated(newDuration);
    }
    
    /**
     * @dev Update minimum stake amount (only owner)
     * @param newAmount The new minimum stake amount
     */
    function updateMinStakeAmount(uint256 newAmount) external onlyOwner {
        require(newAmount > 0, "Min amount cannot be 0");
        minStakeAmount = newAmount;
        emit MinStakeAmountUpdated(newAmount);
    }
    
    /**
     * @dev Function to check contract's token balances (for testing)
     * @return stakingTokenBalance The balance of staking tokens in the contract
     * @return rewardTokenBalance The balance of reward tokens in the contract
     */
    function getContractBalances() external view returns (uint256 stakingTokenBalance, uint256 rewardTokenBalance) {
        stakingTokenBalance = IERC20(stakingToken).balanceOf(address(this));
        rewardTokenBalance = IERC20(rewardToken).balanceOf(address(this));
        return (stakingTokenBalance, rewardTokenBalance);
    }
    
    /**
     * @dev Function for the owner to deposit reward tokens into the contract
     * @param amount The amount of reward tokens to deposit
     */
    function depositRewardTokens(uint256 amount) external onlyOwner {
        require(amount > 0, "Cannot deposit 0");
        require(IERC20(rewardToken).transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }
}

/**
 * @title IERC20
 * @dev Interface for the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

// /**
//  * @title DummyERC20
//  * @dev A  ERC20 token for creating tokens and testing
//  */
// contract DummyERC20 {
//     string public name;
//     string public symbol;
//     uint8 public decimals = 18;
//     uint256 public totalSupply;
    
//     mapping(address => uint256) public balanceOf;
//     mapping(address => mapping(address => uint256)) public allowance;
    
//     event Transfer(address indexed from, address indexed to, uint256 value);
//     event Approval(address indexed owner, address indexed spender, uint256 value);
    
//     constructor(string memory _name, string memory _symbol, uint256 _initialSupply) {
//         name = _name;
//         symbol = _symbol;
//         totalSupply = _initialSupply * 10**18;
//         balanceOf[msg.sender] = totalSupply;
//         emit Transfer(address(0), msg.sender, totalSupply);
//     }
    
//     function transfer(address to, uint256 amount) external returns (bool) {
//         require(to != address(0), "Transfer to zero address");
//         require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        
//         balanceOf[msg.sender] -= amount;
//         balanceOf[to] += amount;
//         emit Transfer(msg.sender, to, amount);
//         return true;
//     }
    
//     function approve(address spender, uint256 amount) external returns (bool) {
//         allowance[msg.sender][spender] = amount;
//         emit Approval(msg.sender, spender, amount);
//         return true;
//     }
    
//     function transferFrom(address from, address to, uint256 amount) external returns (bool) {
//         require(from != address(0), "Transfer from zero address");
//         require(to != address(0), "Transfer to zero address");
//         require(balanceOf[from] >= amount, "Insufficient balance");
//         require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
//         balanceOf[from] -= amount;
//         balanceOf[to] += amount;
//         allowance[from][msg.sender] -= amount;
//         emit Transfer(from, to, amount);
//         return true;
//     }
// }