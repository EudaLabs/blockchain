# MyToken Smart Contract

A comprehensive ERC20 token implementation with advanced features for security, trading control, reward distribution, and DEX integration.

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

### DEX Integration
- PancakeSwap integration
- Liquidity locking mechanism
- Auto-liquidity generation
- Price impact monitoring
- Trading volume tracking
- Anti-manipulation measures

### Analytics & Tracking
- Trade history tracking
- Volume tracking
- Holder tracking
- Price impact monitoring
- Daily statistics
- User trade counts

## Contract Functions

### Core Functions
- `constructor(uint256 _maxSupply, address _treasuryWallet, address _routerAddress)`
- `_transfer(address sender, address recipient, uint256 amount)`
- `_calculateFee(address sender, address recipient, uint256 amount)`
- `_handleFees(address sender, uint256 fee)`

### DEX Integration Functions
- `lockLiquidity(uint256 amount, uint256 duration)`
- `unlockLiquidity(uint256 lockIndex)`
- `calculatePriceImpact(uint256 amount, bool isSell)`
- `addLiquidity()`
- `setLiquidityPool(address _pool)`
- `setAutoLiquidity(bool _enabled)`

### Trading Control Functions
- `enableTrading()`
- `setDexPair(address pair, bool status)`
- `setFees(uint256 _buyFee, uint256 _sellFee)`
- `setLimits(uint256 _maxTx, uint256 _maxWallet, uint256 _maxSell)`

### Analytics Functions
- `getTradeHistory(address trader, uint256 limit)`
- `getDailyVolume(uint256 numberOfDays)`
- `getLiquidityLocks(address user)`
- `getTokenomics()`
- `getLimits()`

## Test Coverage

### DEX Integration Tests
- Liquidity locking/unlocking
- Price impact calculation
- Auto-liquidity generation
- Trading volume tracking

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

## Security Considerations

1. **DEX Integration**
   - Price impact limits
   - Liquidity lock timeouts
   - Anti-manipulation checks

2. **Flash Loan Protection**
   - Same-block transaction detection
   - Higher fees for rapid trades

3. **Anti-Bot Measures**
   - Initial trading restrictions
   - Transaction amount limits
   - Gas price checks

4. **Multi-Signature Security**
   - Multiple signatures required
   - Time-locked operations
   - Operation cancellation

## Gas Optimization

1. **Storage Optimization**
   - Packed storage variables
   - Minimal state changes
   - Efficient mappings

2. **Computation Efficiency**
   - Cached variables
   - Optimized loops
   - Minimal redundant calculations

## Dependencies

- OpenZeppelin Contracts v4.9.0
  - ERC20
  - Ownable
  - Pausable
  - ReentrancyGuard

## Networks

### BSC Testnet
- Network Name: BSC Testnet
- RPC URL: https://data-seed-prebsc-1-s1.binance.org:8545
- Chain ID: 97
- Currency Symbol: tBNB

### BSC Mainnet
- Network Name: BSC Mainnet
- RPC URL: https://bsc-dataseed.binance.org/
- Chain ID: 56
- Currency Symbol: BNB

## Environment Setup

Create a `.env` file with:
```plaintext
PRIVATE_KEY=your_private_key_here
BSCSCAN_API_KEY=your_bscscan_api_key_here
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key_here
```

## Scripts

- `npm run test` - Run tests
- `npm run compile` - Compile contracts
- `npm run deploy:testnet` - Deploy to BSC testnet
- `npm run deploy:mainnet` - Deploy to BSC mainnet
- `npm run verify` - Verify contract on BSCScan
- `npm run coverage` - Generate test coverage report

## License

MIT License 