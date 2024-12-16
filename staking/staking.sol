// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


contract SingleStaking is ReentrancyGuard, Ownable2Step {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    struct Reward {
        address rewardsDistributor;
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }
    IERC20 public stakingToken;
    mapping(address => Reward) public rewardData;
    address[] public rewardTokens;

    // user -> reward token -> amount
    mapping(address => mapping(address => uint256))
        public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _stakingToken) Ownable2Step() {
        stakingToken = IERC20(_stakingToken);
        emit SetStakingToken(_stakingToken);
    }

    function addReward(
        address _rewardsToken,
        address _rewardsDistributor,
        uint256 _rewardsDuration
    ) public onlyOwner {
        require(rewardData[_rewardsToken].rewardsDuration == 0);
        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
        emit AddRewardToken(_rewardsToken, _rewardsDuration);
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable(
        address _rewardsToken
    ) public view returns (uint256) {
        return
            Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    function rewardPerToken(
        address _rewardsToken
    ) public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardData[_rewardsToken].rewardPerTokenStored;
        }
        return
            rewardData[_rewardsToken].rewardPerTokenStored.add(
                lastTimeRewardApplicable(_rewardsToken)
                    .sub(rewardData[_rewardsToken].lastUpdateTime)
                    .mul(rewardData[_rewardsToken].rewardRate)
                    .mul(1e18)
                    .div(_totalSupply)
            );
    }

    function earned(
        address account,
        address _rewardsToken
    ) public view returns (uint256) {
        return
            _balances[account]
                .mul(
                    rewardPerToken(_rewardsToken).sub(
                        userRewardPerTokenPaid[account][_rewardsToken]
                    )
                )
                .div(1e18)
                .add(rewards[account][_rewardsToken]);
    }

    function getRewardForDuration(
        address _rewardsToken
    ) public view returns (uint256) {
        return
            rewardData[_rewardsToken].rewardRate.mul(
                rewardData[_rewardsToken].rewardsDuration
            );
    }

    struct Token {
        address tokenAddress;
        string name;
        string symbol;
        uint8 decimals;
    }

    struct RewardToken {
        Token token;
        Reward rewardData;
        uint256 lastTimeRewardApplicable;
        uint256 rewardPerToken;
        uint256 rewardForDuration;
    }

    function getToken(address token) public view returns (Token memory _token) {
        IERC20Metadata erc20Metadata = IERC20Metadata(token);
        _token.tokenAddress = token;
        _token.name = erc20Metadata.name();
        _token.symbol = erc20Metadata.symbol();
        _token.decimals = erc20Metadata.decimals();
    }

    function getInfo()
        external
        view
        returns (
            uint256 __totalSupply,
            Token memory _stakingToken,
            RewardToken[] memory _rewardTokens
        )
    {
        _rewardTokens = new RewardToken[](rewardTokens.length);
        __totalSupply = _totalSupply;
        _stakingToken = getToken(address(stakingToken));
        for (uint i; i < rewardTokens.length; i++) {
            _rewardTokens[i] = RewardToken({
                token: getToken(rewardTokens[i]),
                rewardData: rewardData[rewardTokens[i]],
                lastTimeRewardApplicable: lastTimeRewardApplicable(
                    rewardTokens[i]
                ),
                rewardPerToken: rewardPerToken(rewardTokens[i]),
                rewardForDuration: getRewardForDuration(rewardTokens[i])
            });
        }
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function setRewardsDistributor(
        address _rewardsToken,
        address _rewardsDistributor
    ) external onlyOwner {
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
    }

    function stake(
        uint256 amount
    ) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function stakeWithPermit(
        uint256 amount,
        uint256 deadline,
        uint256 approveAmount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(address(stakingToken)).permit(
            msg.sender,
            address(this),
            approveAmount,
            deadline,
            v,
            r,
            s
        );
        stake(amount);
    }

    function withdraw(
        uint256 amount
    ) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        for (uint i; i < rewardTokens.length; i++) {
            address _rewardsToken = rewardTokens[i];
            uint256 reward = rewards[msg.sender][_rewardsToken];
            if (reward > 0) {
                rewards[msg.sender][_rewardsToken] = 0;
                IERC20(_rewardsToken).safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, _rewardsToken, reward);
            }
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(
        address _rewardsToken,
        uint256 reward
    ) external updateReward(address(0)) {
        require(rewardData[_rewardsToken].rewardsDistributor == msg.sender);
        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the reward amount
        IERC20(_rewardsToken).safeTransferFrom(
            msg.sender,
            address(this),
            reward
        );

        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            rewardData[_rewardsToken].rewardRate = reward.div(
                rewardData[_rewardsToken].rewardsDuration
            );
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish.sub(
                block.timestamp
            );
            uint256 leftover = remaining.mul(
                rewardData[_rewardsToken].rewardRate
            );
            rewardData[_rewardsToken].rewardRate = reward.add(leftover).div(
                rewardData[_rewardsToken].rewardsDuration
            );
        }

        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish = block.timestamp.add(
            rewardData[_rewardsToken].rewardsDuration
        );
        emit RewardAdded(_rewardsToken, reward);
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(
        address tokenAddress,
        uint256 tokenAmount
    ) external onlyOwner {
        require(
            tokenAddress != address(stakingToken),
            "Cannot withdraw staking token"
        );
        require(
            rewardData[tokenAddress].lastUpdateTime == 0,
            "Cannot withdraw reward token"
        );
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /** 
     * @notice Sets the duration for rewards distribution of a specific token
     * @param _rewardsToken Address of the reward token
     * @param _rewardsDuration New duration in seconds
     */
    function setRewardsDuration(
        address _rewardsToken,
        uint256 _rewardsDuration
    ) external {
        // Input validation
        require(_rewardsToken != address(0), "Invalid reward token");
        require(_rewardsDuration > 0, "Reward duration must be non-zero");
        
        // Check if previous reward period has ended
        require(
            block.timestamp > rewardData[_rewardsToken].periodFinish,
            "Previous reward period still active"
        );
        
        // Verify caller is authorized distributor
        require(
            rewardData[_rewardsToken].rewardsDistributor == msg.sender,
            "Caller is not rewards distributor"
        );
    
        // Update reward duration
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
        
        emit RewardsDurationUpdated(_rewardsToken, _rewardsDuration);
    }
    
    /* ========== MODIFIERS ========== */
    
    /**
     * @notice Updates rewards for all reward tokens for an account
     * @dev Gas optimization: Skip updates for zero address
     * @param account Address of the account to update rewards for
     */
    modifier updateReward(address account) {
        uint256 length = rewardTokens.length;
        address token;
        RewardData storage rData;
        
        // Cache frequently accessed storage variables
        for (uint256 i; i < length; ++i) {
            token = rewardTokens[i];
            rData = rewardData[token];
            
            // Update global reward state
            rData.rewardPerTokenStored = rewardPerToken(token);
            rData.lastUpdateTime = lastTimeRewardApplicable(token);
            
            // Skip reward calculations for zero address
            if (account != address(0)) {
                rewards[account][token] = earned(account, token);
                userRewardPerTokenPaid[account][token] = rData.rewardPerTokenStored;
            }
        }
        _;
    }
    
    /* ========== EVENTS ========== */
    
    /**
     * @dev Events for tracking state changes
     */
    event SetStakingToken(address indexed token);
    event AddRewardToken(
        address indexed token,
        uint256 rewardDuration,
        uint256 timestamp
    );
    event RewardAdded(
        address indexed token,
        uint256 reward,
        uint256 duration
    );
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );
    event Withdrawn(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );
    event RewardPaid(
        address indexed user,
        address indexed rewardsToken,
        uint256 reward,
        uint256 timestamp
    );
    event RewardsDurationUpdated(address indexed token, uint256 newDuration);
    event Recovered(address token, uint256 amount);
}