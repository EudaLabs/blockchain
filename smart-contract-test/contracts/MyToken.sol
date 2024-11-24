// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IPancakeFactory.sol";

contract MyToken is ERC20, Ownable, Pausable, ReentrancyGuard {
    // Constants
    uint256 constant DAYS = 1 days;
    uint256 private constant FLASH_LOAN_FEE = 50; // 5%
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant ANTI_BOT_TIMER = 60; // 60 seconds
    uint256 public constant MAX_FEE = 50; // 5%
    
    // State variables
    uint256 public maxSupply;
    uint256 public maxTransactionAmount;
    uint256 public maxWalletAmount;
    uint256 public maxSellAmount;
    uint256 public cooldownTime = 60;
    uint256 public buyFee = 3;    // 0.3%
    uint256 public sellFee = 8;   // 0.8%
    uint256 public rewardThreshold;
    uint256 public rewardPoolBalance;
    
    // Trading control
    bool public tradingEnabled;
    uint256 public tradingEnabledAt;
    mapping(address => uint256) public lastSellDay;
    
    // Addresses
    address public treasuryWallet;
    
    // Mappings
    mapping(address => bool) public blacklisted;
    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public lastTradeTime;
    mapping(address => uint256) private _lastTransferTimestamp;
    mapping(address => uint256) public rewardPoints;
    mapping(address => uint256) public unclaimedRewards;
    mapping(address => bool) public isDexPair;
    mapping(address => uint256) public sellCount;
    
    // Events
    event TradingEnabled(uint256 timestamp);
    event TokensBurned(address indexed from, uint256 amount);
    event RewardsDistributed(uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event DexPairUpdated(address indexed pair, bool status);
    event FeesUpdated(uint256 buyFee, uint256 sellFee);
    event LimitsUpdated(uint256 maxTx, uint256 maxWallet, uint256 maxSell);
    event VolumeUpdated(uint256 newVolume);
    event DynamicFeeUpdated(uint256 multiplier);
    event LiquidityAdded(uint256 tokenAmount, uint256 bnbAmount);
    event TradeExecuted(address indexed trader, bool isBuy, uint256 amount, uint256 price);
    event LiquidityLocked(address indexed user, uint256 amount, uint256 unlockTime);
    event LiquidityUnlocked(address indexed user, uint256 amount);
    event HighPriceImpact(uint256 impact, uint256 maxAllowed);
    event OperationCreated(bytes32 indexed operationId, address indexed creator, bytes data);
    event OperationCancelled(bytes32 indexed operationId);
    event BlacklistUpdated(address indexed account, bool status);
    
    // Multi-signature related
    uint256 public constant REQUIRED_SIGNATURES = 2;
    uint256 public constant OPERATION_DELAY = 1 * DAYS;
    mapping(bytes32 => uint256) public pendingOperations;
    mapping(bytes32 => mapping(address => bool)) public hasSignedOperation;
    mapping(address => bool) public isSigner;
    uint256 public signerCount;
    
    // Enhanced security
    uint256 public immutable launchTime;
    uint256 public constant MAX_WALLET_PERCENT = 5; // 5% max wallet
    bool public tradingPermanentlyEnabled;
    uint256 public maxSellsPerDay;
    
    // Additional events
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event OperationProposed(bytes32 indexed operationId, address indexed proposer);
    event OperationSigned(bytes32 indexed operationId, address indexed signer);
    event OperationExecuted(bytes32 indexed operationId);
    event TradingPermanentlyEnabled();
    event EmergencyPause(bool paused);

    // Dynamic fee adjustment
    uint256 public constant MAX_DYNAMIC_FEE_MULTIPLIER = 200; // 2x max
    uint256 public constant VOLUME_THRESHOLD = 1000 ether;
    uint256 public lastDayVolume;
    uint256 public lastVolumeUpdateTime;
    uint256 public dynamicFeeMultiplier = 100; // 1x default

    // Liquidity management
    address public liquidityPool;
    uint256 public liquidityFee = 5; // 0.5%
    uint256 public totalLiquidityAdded;
    bool public autoLiquidity;
    uint256 public minTokensForLiquidity = 1000 * 10**decimals();

    // Trading analytics
    struct TradeData {
        uint256 timestamp;
        uint256 amount;
        bool isBuy;
        uint256 price;
    }
    
    mapping(address => TradeData[]) private tradeHistory;
    uint256 public totalTrades;
    uint256 public totalVolume;
    mapping(uint256 => uint256) public dailyVolume; // day => volume
    mapping(address => uint256) public userTradeCount;

    IPancakeRouter02 public pancakeRouter;
    IPancakePair public pancakePair;
    
    // Liquidity locking
    struct LockInfo {
        uint256 amount;
        uint256 unlockTime;
        bool claimed;
    }
    
    mapping(address => LockInfo[]) public liquidityLocks;
    uint256 public constant MIN_LOCK_DURATION = 30 days;
    uint256 public constant MAX_LOCK_DURATION = 365 days;
    uint256 public totalLockedLiquidity;
    
    // Price impact
    uint256 public constant MAX_PRICE_IMPACT = 50; // 5%
    uint256 public constant PRICE_IMPACT_DENOMINATOR = 1000;
    
    constructor(
        uint256 _maxSupply,
        address _treasuryWallet,
        address _routerAddress
    ) ERC20("MyToken", "MTK") {
        require(_maxSupply > 0, "Max supply must be positive");
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        require(_routerAddress != address(0), "Invalid router");
        pancakeRouter = IPancakeRouter02(_routerAddress);
        
        maxSupply = _maxSupply;
        treasuryWallet = _treasuryWallet;
        
        // Set limits as percentages of max supply
        maxTransactionAmount = _maxSupply * 1 / 100; // 1%
        maxWalletAmount = _maxSupply * 2 / 100;      // 2%
        maxSellAmount = _maxSupply * 1 / 100;        // 1%
        rewardThreshold = 1000 * 10**decimals();
        maxSellsPerDay = 5; // Maximum 5 sells per day
        
        // Initial minting
        _mint(msg.sender, _maxSupply);
        
        // Set initial whitelist and signer
        whitelisted[msg.sender] = true;
        whitelisted[_treasuryWallet] = true;
        isSigner[msg.sender] = true;
        signerCount = 1;
        
        launchTime = block.timestamp;
    }

    // Core transfer function with all checks and fee handling
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(sender != address(0), "Transfer from zero");
        require(recipient != address(0), "Transfer to zero");
        require(!blacklisted[sender] && !blacklisted[recipient], "Blacklisted");
        
        // Skip checks for whitelisted addresses
        if (!whitelisted[sender] && !whitelisted[recipient]) {
            require(tradingEnabled, "Trading not enabled");
            require(amount <= maxTransactionAmount, "Exceeds max tx");
            
            // Enhanced anti-bot checks
            if (block.timestamp <= tradingEnabledAt + ANTI_BOT_TIMER) {
                require(whitelisted[sender], "Anti-bot: Only whitelisted");
            }
            
            // Sell limit per day
            if (isDexPair[recipient]) {
                uint256 currentDay = block.timestamp / DAYS;
                if (lastSellDay[sender] != currentDay) {
                    sellCount[sender] = 0;
                    lastSellDay[sender] = currentDay;
                }
                require(sellCount[sender] < maxSellsPerDay, "Max sells per day");
                sellCount[sender]++;
            }
            
            // Enhanced max wallet check
            if (!isDexPair[recipient]) {
                require(
                    balanceOf(recipient) + amount <= maxSupply * MAX_WALLET_PERCENT / 100,
                    "Exceeds max wallet"
                );
            }
        }
        
        // Update dynamic fee based on volume
        updateDynamicFee();

        // Calculate and handle fees
        uint256 fee = _calculateFee(sender, recipient, amount);
        uint256 transferAmount = amount - fee;
        
        if (fee > 0) {
            _handleFees(sender, fee);
        }
        
        // Execute transfer
        super._transfer(sender, recipient, transferAmount);
        
        // Record trade
        bool isBuy = isDexPair[sender];
        uint256 price = 0; // In practice, you'd get this from the DEX
        recordTrade(recipient, amount, isBuy, price);
        
        // Try to add liquidity if conditions are met
        if (isDexPair[recipient]) {
            addLiquidity();
        }

        // Update reward points if applicable
        if (amount >= rewardThreshold) {
            rewardPoints[sender] += amount / rewardThreshold;
        }

        // Update holder tracking
        _addHolder(recipient);
        if (balanceOf(sender) == 0) {
            _removeHolder(sender);
        }

        // Add price impact check for DEX trades
        if (isDexPair[sender] || isDexPair[recipient]) {
            uint256 priceImpact = calculatePriceImpact(amount, isDexPair[recipient]);
            require(priceImpact <= MAX_PRICE_IMPACT, "Price impact too high");
            
            if (priceImpact > MAX_PRICE_IMPACT / 2) {
                emit HighPriceImpact(priceImpact, MAX_PRICE_IMPACT);
            }
        }
    }

    function _calculateFee(
        address sender,
        address recipient,
        uint256 amount
    ) internal view returns (uint256) {
        if (whitelisted[sender] || whitelisted[recipient]) {
            return 0;
        }
        
        uint256 baseFee = isDexPair[sender] ? buyFee : (isDexPair[recipient] ? sellFee : 0);
        uint256 adjustedFee = (baseFee * dynamicFeeMultiplier) / 100;
        return (amount * adjustedFee) / FEE_DENOMINATOR;
    }

    function _handleFees(address sender, uint256 fee) internal {
        if (fee == 0) return;
        
        uint256 burnShare = fee * 40 / 100;     // 40% burn
        uint256 treasuryShare = fee * 40 / 100; // 40% treasury
        uint256 rewardShare = fee * 20 / 100;   // 20% rewards
        
        if (burnShare > 0) {
            super._burn(sender, burnShare);
            emit TokensBurned(sender, burnShare);
        }
        
        if (treasuryShare > 0) {
            super._transfer(sender, treasuryWallet, treasuryShare);
        }
        
        if (rewardShare > 0) {
            super._transfer(sender, address(this), rewardShare);
            rewardPoolBalance += rewardShare;
        }
    }

    // Owner functions
    function setDexPair(address pair, bool status) external onlyOwner {
        require(pair != address(0), "Invalid pair");
        isDexPair[pair] = status;
        emit DexPairUpdated(pair, status);
    }

    function setFees(uint256 _buyFee, uint256 _sellFee) external onlyOwner {
        require(_buyFee <= MAX_FEE && _sellFee <= MAX_FEE, "Fee too high");
        buyFee = _buyFee;
        sellFee = _sellFee;
        emit FeesUpdated(_buyFee, _sellFee);
    }

    function setLimits(
        uint256 _maxTx,
        uint256 _maxWallet,
        uint256 _maxSell
    ) external onlyOwner {
        require(_maxTx <= maxSupply * 5 / 100, "Max tx too high");
        require(_maxWallet <= maxSupply * 5 / 100, "Max wallet too high");
        require(_maxSell <= maxSupply * 5 / 100, "Max sell too high");
        
        maxTransactionAmount = _maxTx;
        maxWalletAmount = _maxWallet;
        maxSellAmount = _maxSell;
        
        emit LimitsUpdated(_maxTx, _maxWallet, _maxSell);
    }

    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading already enabled");
        tradingEnabled = true;
        tradingEnabledAt = block.timestamp;
        emit TradingEnabled(block.timestamp);
    }

    // Reward claiming
    function claimRewards() external nonReentrant {
        uint256 points = rewardPoints[msg.sender];
        require(points > 0, "No rewards");
        require(rewardPoolBalance > 0, "No rewards in pool");
        
        uint256 reward = (rewardPoolBalance * points) / _calculateTotalPoints();
        require(reward > 0, "Reward too small");
        
        rewardPoints[msg.sender] = 0;
        rewardPoolBalance -= reward;
        
        super._transfer(address(this), msg.sender, reward);
        emit RewardsClaimed(msg.sender, reward);
    }

    function _calculateTotalPoints() internal view returns (uint256) {
        uint256 total = 0;
        address[] memory holders = _getHolders();
        
        for (uint256 i = 0; i < holders.length; i++) {
            total += rewardPoints[holders[i]];
        }
        
        return total > 0 ? total : 1; // Prevent division by zero
    }

    // View functions
    function getTokenomics() external view returns (
        uint256 _maxSupply,
        uint256 _totalSupply,
        uint256 _rewardPool,
        uint256 _buyFee,
        uint256 _sellFee
    ) {
        return (
            maxSupply,
            totalSupply(),
            rewardPoolBalance,
            buyFee,
            sellFee
        );
    }

    function getLimits() external view returns (
        uint256 _maxTx,
        uint256 _maxWallet,
        uint256 _maxSell
    ) {
        return (
            maxTransactionAmount,
            maxWalletAmount,
            maxSellAmount
        );
    }

    // Multi-signature functionality
    function addSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Invalid signer");
        require(!isSigner[_signer], "Already signer");
        require(signerCount < 10, "Too many signers"); // Max 10 signers
        
        isSigner[_signer] = true;
        signerCount++;
        emit SignerAdded(_signer);
    }
    
    function removeSigner(address _signer) external onlyOwner {
        require(isSigner[_signer], "Not a signer");
        require(signerCount > REQUIRED_SIGNATURES, "Too few signers");
        
        isSigner[_signer] = false;
        signerCount--;
        emit SignerRemoved(_signer);
    }
    
    function proposeOperation(bytes32 _operation) external {
        require(isSigner[msg.sender], "Not a signer");
        require(pendingOperations[_operation] == 0, "Already proposed");
        
        pendingOperations[_operation] = block.timestamp + OPERATION_DELAY;
        hasSignedOperation[_operation][msg.sender] = true;
        emit OperationProposed(_operation, msg.sender);
    }
    
    function _executeOperation(bytes32 operationId, bytes memory data) internal {
        if (operationId == OP_SET_TREASURY) {
            address newTreasury = abi.decode(data, (address));
            _setTreasuryWallet(newTreasury);
        } else if (operationId == OP_SET_FEES) {
            (uint256 newBuyFee, uint256 newSellFee) = abi.decode(data, (uint256, uint256));
            _setFees(newBuyFee, newSellFee);
        } else if (operationId == OP_SET_LIMITS) {
            (uint256 newMaxTx, uint256 newMaxWallet, uint256 newMaxSell) = 
                abi.decode(data, (uint256, uint256, uint256));
            _setLimits(newMaxTx, newMaxWallet, newMaxSell);
        } else if (operationId == keccak256("PERMANENT_TRADING_ENABLE")) {
            _permanentlyEnableTrading();
        } else if (operationId == keccak256("EMERGENCY_PAUSE")) {
            _pause();
        } else if (operationId == keccak256("EMERGENCY_UNPAUSE")) {
            _unpause();
        }
    }

    // Enhanced security functions
    function _permanentlyEnableTrading() internal {
        require(!tradingPermanentlyEnabled, "Already permanent");
        tradingPermanentlyEnabled = true;
        tradingEnabled = true;
        emit TradingPermanentlyEnabled();
    }

    // Emergency functions
    function emergencyPause() external {
        require(isSigner[msg.sender], "Not a signer");
        _pause();
        emit EmergencyPause(true);
    }
    
    function emergencyUnpause() external {
        require(isSigner[msg.sender], "Not a signer");
        _unpause();
        emit EmergencyPause(false);
    }

    // Blacklist management
    function setBlacklist(address account, bool status) external onlyOwner {
        require(account != address(0), "Invalid address");
        require(account != owner(), "Cannot blacklist owner");
        require(account != treasuryWallet, "Cannot blacklist treasury");
        blacklisted[account] = status;
        emit BlacklistUpdated(account, status);
    }

    // Multi-signature operation types
    bytes32 public constant OP_SET_TREASURY = keccak256("SET_TREASURY");
    bytes32 public constant OP_SET_FEES = keccak256("SET_FEES");
    bytes32 public constant OP_SET_LIMITS = keccak256("SET_LIMITS");
    bytes32 public constant OP_UPGRADE_CONTRACT = keccak256("UPGRADE_CONTRACT");

    struct Operation {
        bool executed;
        uint256 timestamp;
        uint256 signatureCount;
        mapping(address => bool) signatures;
        bytes data;
    }

    mapping(bytes32 => Operation) public operations;
    
    function createOperation(bytes32 operationType, bytes memory data) external {
        require(isSigner[msg.sender], "Not authorized");
        bytes32 operationId = keccak256(abi.encodePacked(operationType, data, block.timestamp));
        require(operations[operationId].timestamp == 0, "Operation exists");

        Operation storage op = operations[operationId];
        op.timestamp = block.timestamp;
        op.data = data;
        op.signatures[msg.sender] = true;
        op.signatureCount = 1;

        emit OperationCreated(operationId, msg.sender, data);
    }

    function cancelOperation(bytes32 operationId) external {
        require(isSigner[msg.sender], "Not authorized");
        require(operations[operationId].timestamp > 0, "Operation not found");
        require(!operations[operationId].executed, "Already executed");
        
        delete operations[operationId];
        emit OperationCancelled(operationId);
    }

    function signOperation(bytes32 operationId) external {
        require(isSigner[msg.sender], "Not authorized");
        Operation storage op = operations[operationId];
        require(op.timestamp > 0, "Operation not found");
        require(!op.executed, "Already executed");
        require(!op.signatures[msg.sender], "Already signed");
        require(block.timestamp <= op.timestamp + OPERATION_DELAY, "Operation expired");

        op.signatures[msg.sender] = true;
        op.signatureCount++;
    }

    function executeOperation(bytes32 operationId) external {
        Operation storage op = operations[operationId];
        require(op.timestamp > 0, "Operation not found");
        require(!op.executed, "Already executed");
        require(op.signatureCount >= REQUIRED_SIGNATURES, "Insufficient signatures");
        require(block.timestamp >= op.timestamp + OPERATION_DELAY, "Time lock active");

        op.executed = true;
        _executeOperation(operationId, op.data);
    }

    // Internal functions for multi-sig operations
    function _setTreasuryWallet(address newTreasury) internal {
        require(newTreasury != address(0), "Invalid treasury");
        treasuryWallet = newTreasury;
        whitelisted[newTreasury] = true;
    }

    function _setFees(uint256 newBuyFee, uint256 newSellFee) internal {
        require(newBuyFee <= MAX_FEE && newSellFee <= MAX_FEE, "Fee too high");
        buyFee = newBuyFee;
        sellFee = newSellFee;
        emit FeesUpdated(newBuyFee, newSellFee);
    }

    function _setLimits(uint256 newMaxTx, uint256 newMaxWallet, uint256 newMaxSell) internal {
        require(newMaxTx <= maxSupply * 5 / 100, "Max tx too high");
        require(newMaxWallet <= maxSupply * 5 / 100, "Max wallet too high");
        require(newMaxSell <= maxSupply * 5 / 100, "Max sell too high");
        
        maxTransactionAmount = newMaxTx;
        maxWalletAmount = newMaxWallet;
        maxSellAmount = newMaxSell;
        emit LimitsUpdated(newMaxTx, newMaxWallet, newMaxSell);
    }

    // Additional view functions for frontend integration
    function getOperationInfo(bytes32 operationId) external view returns (
        bool executed,
        uint256 timestamp,
        uint256 signatureCount,
        bytes memory data
    ) {
        Operation storage op = operations[operationId];
        return (
            op.executed,
            op.timestamp,
            op.signatureCount,
            op.data
        );
    }

    function getSignerStatus(address account) external view returns (bool) {
        return isSigner[account];
    }

    // Dynamic fee adjustment
    function updateDynamicFee() internal {
        uint256 currentDay = block.timestamp / DAYS;
        uint256 currentVolume = dailyVolume[currentDay];

        if (currentVolume > VOLUME_THRESHOLD) {
            // Increase fees as volume increases
            dynamicFeeMultiplier = 100 + (currentVolume / VOLUME_THRESHOLD) * 20;
            if (dynamicFeeMultiplier > MAX_DYNAMIC_FEE_MULTIPLIER) {
                dynamicFeeMultiplier = MAX_DYNAMIC_FEE_MULTIPLIER;
            }
        } else {
            dynamicFeeMultiplier = 100;
        }

        emit DynamicFeeUpdated(dynamicFeeMultiplier);
    }

    // Liquidity management
    function setLiquidityPool(address _pool) external onlyOwner {
        require(_pool != address(0), "Invalid pool address");
        liquidityPool = _pool;
    }

    function setAutoLiquidity(bool _enabled) external onlyOwner {
        autoLiquidity = _enabled;
    }

    function addLiquidity() internal {
        if (!autoLiquidity || address(this).balance < 0.1 ether) {
            return;
        }

        uint256 tokenBalance = balanceOf(address(this));
        if (tokenBalance < minTokensForLiquidity) {
            return;
        }

        // Add liquidity to pool
        // Note: This is a simplified version. In practice, you'd need to interact with the DEX
        totalLiquidityAdded += tokenBalance;
        emit LiquidityAdded(tokenBalance, address(this).balance);
    }

    // Trading analytics
    function recordTrade(
        address trader,
        uint256 amount,
        bool isBuy,
        uint256 price
    ) internal {
        TradeData memory trade = TradeData({
            timestamp: block.timestamp,
            amount: amount,
            isBuy: isBuy,
            price: price
        });

        tradeHistory[trader].push(trade);
        totalTrades++;
        totalVolume += amount;
        userTradeCount[trader]++;

        uint256 currentDay = block.timestamp / DAYS;
        dailyVolume[currentDay] += amount;

        emit TradeExecuted(trader, isBuy, amount, price);
    }

    // View functions for analytics
    function getTradeHistory(address trader, uint256 limit) external view returns (
        uint256[] memory timestamps,
        uint256[] memory amounts,
        bool[] memory isBuys,
        uint256[] memory prices
    ) {
        TradeData[] storage trades = tradeHistory[trader];
        uint256 length = trades.length;
        uint256 resultLength = limit < length ? limit : length;

        timestamps = new uint256[](resultLength);
        amounts = new uint256[](resultLength);
        isBuys = new bool[](resultLength);
        prices = new uint256[](resultLength);

        for (uint256 i = 0; i < resultLength; i++) {
            TradeData storage trade = trades[length - 1 - i];
            timestamps[i] = trade.timestamp;
            amounts[i] = trade.amount;
            isBuys[i] = trade.isBuy;
            prices[i] = trade.price;
        }

        return (timestamps, amounts, isBuys, prices);
    }

    function getDailyVolume(uint256 numberOfDays) external view returns (uint256[] memory volumes) {
        volumes = new uint256[](numberOfDays);
        uint256 currentDay = block.timestamp / DAYS;
        
        for (uint256 i = 0; i < numberOfDays; i++) {
            volumes[i] = dailyVolume[currentDay - i];
        }
        
        return volumes;
    }

    // Add holder tracking
    mapping(address => bool) private _isHolder;
    address[] private _holders;

    function _addHolder(address holder) internal {
        if (!_isHolder[holder] && holder != address(0) && holder != address(this)) {
            _isHolder[holder] = true;
            _holders.push(holder);
        }
    }

    function _removeHolder(address holder) internal {
        if (_isHolder[holder] && balanceOf(holder) == 0) {
            _isHolder[holder] = false;
            for (uint256 i = 0; i < _holders.length; i++) {
                if (_holders[i] == holder) {
                    _holders[i] = _holders[_holders.length - 1];
                    _holders.pop();
                    break;
                }
            }
        }
    }

    function _getHolders() internal view returns (address[] memory) {
        return _holders;
    }

    // Add view function for holder count
    function getHolderCount() external view returns (uint256) {
        return _holders.length;
    }

    // Add these functions for liquidity locking
    function lockLiquidity(uint256 amount, uint256 duration) external nonReentrant {
        require(amount > 0, "Amount must be positive");
        require(duration >= MIN_LOCK_DURATION && duration <= MAX_LOCK_DURATION, "Invalid duration");
        require(address(pancakePair) != address(0), "Pair not created");
        
        IPancakePair pair = IPancakePair(pancakePair);
        require(pair.balanceOf(msg.sender) >= amount, "Insufficient LP tokens");
        
        // Transfer LP tokens to contract
        require(pair.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        // Create lock
        liquidityLocks[msg.sender].push(LockInfo({
            amount: amount,
            unlockTime: block.timestamp + duration,
            claimed: false
        }));
        
        totalLockedLiquidity += amount;
        emit LiquidityLocked(msg.sender, amount, block.timestamp + duration);
    }
    
    function unlockLiquidity(uint256 lockIndex) external nonReentrant {
        LockInfo[] storage userLocks = liquidityLocks[msg.sender];
        require(lockIndex < userLocks.length, "Invalid lock index");
        
        LockInfo storage lock = userLocks[lockIndex];
        require(!lock.claimed, "Already claimed");
        require(block.timestamp >= lock.unlockTime, "Still locked");
        
        lock.claimed = true;
        totalLockedLiquidity -= lock.amount;
        
        // Return LP tokens
        require(IPancakePair(pancakePair).transfer(msg.sender, lock.amount), "Transfer failed");
        emit LiquidityUnlocked(msg.sender, lock.amount);
    }

    // Add price impact monitoring
    function calculatePriceImpact(uint256 amount, bool isSell) public view returns (uint256) {
        require(address(pancakePair) != address(0), "Pair not created");
        
        IPancakePair pair = IPancakePair(pancakePair);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        
        // Ensure reserves are in correct order
        (uint112 tokenReserve, uint112 bnbReserve) = pair.token0() == address(this) 
            ? (reserve0, reserve1) 
            : (reserve1, reserve0);
        
        uint256 amountAfterFee = amount * (FEE_DENOMINATOR - (isSell ? sellFee : buyFee)) / FEE_DENOMINATOR;
        
        if (isSell) {
            // Calculate price impact for selling
            return (amountAfterFee * PRICE_IMPACT_DENOMINATOR) / tokenReserve;
        } else {
            // Calculate price impact for buying
            return (amountAfterFee * PRICE_IMPACT_DENOMINATOR) / bnbReserve;
        }
    }

    // View functions for liquidity locks
    function getLiquidityLocks(address user) external view returns (
        uint256[] memory amounts,
        uint256[] memory unlockTimes,
        bool[] memory claimed
    ) {
        LockInfo[] storage locks = liquidityLocks[user];
        uint256 length = locks.length;
        
        amounts = new uint256[](length);
        unlockTimes = new uint256[](length);
        claimed = new bool[](length);
        
        for (uint256 i = 0; i < length; i++) {
            amounts[i] = locks[i].amount;
            unlockTimes[i] = locks[i].unlockTime;
            claimed[i] = locks[i].claimed;
        }
        
        return (amounts, unlockTimes, claimed);
    }
} 