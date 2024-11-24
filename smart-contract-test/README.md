# MyToken Smart Contract

A comprehensive ERC20 token implementation with advanced features for security, trading control, and reward distribution.

## Features

### Core Token Features
- ERC20 standard implementation
- Maximum supply control
- Burning mechanism
- Dynamic fee system
- Reward distribution

### Security Features
- Pausable functionality
- ReentrancyGuard protection
- Blacklist/Whitelist system
- Multi-signature operations
- Flash loan protection
- Anti-bot measures

### Trading Controls
- Trading enable/disable
- Anti-whale mechanisms
- Max transaction limits
- Max wallet limits
- Max sell limits
- Cooldown periods
- Dynamic fees based on volume

### Fee System
- Buy fee (default 0.3%)
- Sell fee (default 0.8%)
- Dynamic fee multiplier
- Fee distribution:
  - 40% burn
  - 40% treasury
  - 20% rewards

### Liquidity Management
- Auto-liquidity generation
- Liquidity locking
- Minimum threshold for liquidity adds

### Analytics & Tracking
- Trade history tracking
- Volume tracking
- Holder tracking
- Price impact monitoring

## Contract Functions

### Core Functions
- `constructor(uint256 _maxSupply, address _treasuryWallet)`
- `_transfer(address sender, address recipient, uint256 amount)`
- `_calculateFee(address sender, address recipient, uint256 amount)`
- `_handleFees(address sender, uint256 fee)`

### Trading Control Functions
- `enableTrading()`
- `setDexPair(address pair, bool status)`
- `setFees(uint256 _buyFee, uint256 _sellFee)`
- `setLimits(uint256 _maxTx, uint256 _maxWallet, uint256 _maxSell)`

### Multi-Signature Functions
- `addSigner(address _signer)`
- `removeSigner(address _signer)`
- `createOperation(bytes32 operationType, bytes memory data)`
- `signOperation(bytes32 operationId)`
- `executeOperation(bytes32 operationId)`
- `cancelOperation(bytes32 operationId)`

### Reward System Functions
- `claimRewards()`
- `_calculateTotalPoints()`
- `_addHolder(address holder)`
- `_removeHolder(address holder)`

### View Functions
- `getTokenomics()`
- `getLimits()`
- `getTradeHistory(address trader, uint256 limit)`
- `getDailyVolume(uint256 numberOfDays)`
- `getOperationInfo(bytes32 operationId)`
- `getHolderCount()`

## Test Coverage

### Deployment Tests
- Initial parameters
- Token distribution
- Initial limits

### Trading Control Tests
- Trading enablement
- Anti-bot protection
- Fee calculations
- Transfer limits

### Fee System Tests
- Buy fee application
- Sell fee application
- Fee distribution
- Dynamic fee adjustment

### Security Tests
- Flash loan protection
- Blacklist functionality
- Emergency pause/unpause
- Multi-signature operations

### Reward System Tests
- Point accumulation
- Reward distribution
- Reward claiming
- Holder tracking

### Analytics Tests
- Trade history recording
- Volume tracking
- Daily statistics
- Holder management

## Usage Example

```javascript
// Deploy contract
const MyToken = await ethers.getContractFactory("MyToken");
const myToken = await MyToken.deploy(
    ethers.utils.parseEther("1000000"), // 1 million max supply
    treasuryWallet.address
);

// Enable trading
await myToken.enableTrading();

// Set up DEX pair
await myToken.setDexPair(pairAddress, true);

// Configure fees
await myToken.setFees(30, 80); // 3% buy, 8% sell

// Set limits
await myToken.setLimits(
    maxTxAmount,
    maxWalletAmount,
    maxSellAmount
);
```

## Security Considerations

1. **Flash Loan Protection**
   - Same-block transaction detection
   - Higher fees for rapid trades

2. **Anti-Bot Measures**
   - Initial trading restrictions
   - Transaction amount limits
   - Gas price checks

3. **Multi-Signature Security**
   - Multiple signatures required
   - Time-locked operations
   - Operation cancellation

4. **Emergency Controls**
   - Emergency pause
   - Blacklist functionality
   - Trading restrictions

## Gas Optimization

1. **Storage Optimization**
   - Packed storage variables
   - Minimal state changes
   - Efficient mappings

2. **Computation Efficiency**
   - Cached variables
   - Optimized loops
   - Minimal redundant calculations

## Events

- `TradingEnabled(uint256 timestamp)`
- `TokensBurned(address indexed from, uint256 amount)`
- `RewardsDistributed(uint256 amount)`
- `RewardsClaimed(address indexed user, uint256 amount)`
- `DexPairUpdated(address indexed pair, bool status)`
- `FeesUpdated(uint256 buyFee, uint256 sellFee)`
- `LimitsUpdated(uint256 maxTx, uint256 maxWallet, uint256 maxSell)`
- `OperationCreated(bytes32 indexed operationId, address indexed creator, bytes data)`
- `OperationExecuted(bytes32 indexed operationId)`
- `BlacklistUpdated(address indexed account, bool status)`

## Dependencies

- OpenZeppelin Contracts v4.9.0
  - ERC20
  - Ownable
  - Pausable
  - ReentrancyGuard

## Development Setup

1. Install dependencies:
```bash
npm install
```

2. Compile contracts:
```bash
npx hardhat compile
```

3. Run tests:
```bash
npx hardhat test
```

4. Deploy:
```bash
npx hardhat run scripts/deploy.js --network <network>
```

## License

MIT License 