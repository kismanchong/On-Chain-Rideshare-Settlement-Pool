# 🚗 On-Chain Rideshare Settlement Pool

A Clarity smart contract that enables fair and transparent distribution of rideshare earnings to drivers through pooled settlements, platform fee management, and dispute resolution.

## 🎯 Features

- **Driver Registration** - Register as an active driver on the platform
- **Settlement Pools** - Create pools for distributing ride earnings
- **Fair Distribution** - Automatic calculation of driver shares based on rides completed
- **Platform Fees** - Built-in 3% platform fee collection
- **Dispute Resolution** - On-chain dispute mechanism with deposit requirements
- **Payment Claims** - Secure claiming of earned amounts

## 📋 Contract Functions

### Driver Management

#### `register-driver()`
Register yourself as a driver on the platform.
```clarity
(contract-call? .On-Chain-Rideshare-Settlement-Pool register-driver)
```

#### `deactivate-driver()`
Deactivate your driver status.
```clarity
(contract-call? .On-Chain-Rideshare-Settlement-Pool deactivate-driver)
```

### Pool Operations

#### `create-settlement-pool(initial-amount)`
Create a new settlement pool with STX amount (minus 3% platform fee).
```clarity
(contract-call? .On-Chain-Rideshare-Settlement-Pool create-settlement-pool u10000000)
```

#### `add-driver-to-pool(pool-id, driver, rides-count)`
Add a driver to a specific pool with their ride count.
```clarity
(contract-call? .On-Chain-Rideshare-Settlement-Pool add-driver-to-pool u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u25)
```

#### `claim-payment(pool-id)`
Claim your share from a settlement pool.
```clarity
(contract-call? .On-Chain-Rideshare-Settlement-Pool claim-payment u1)
```

### Dispute System

#### `raise-dispute(pool-id)`
Raise a dispute on a pool (requires 1 STX deposit).
```clarity
(contract-call? .On-Chain-Rideshare-Settlement-Pool raise-dispute u1)
```

#### `resolve-dispute(pool-id, favor-disputer)`
Resolve a dispute (owner only).
```clarity
(contract-call? .On-Chain-Rideshare-Settlement-Pool resolve-dispute u1 true)
```

### Read-Only Functions

#### `get-driver-info(driver)`
Get driver statistics and status.
```clarity
(contract-call? .On-Chain-Rideshare-Settlement-Pool get-driver-info 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `get-pool-info(pool-id)`
Get settlement pool details.
```clarity
(contract-call? .On-Chain-Rideshare-Settlement-Pool get-pool-info u1)
```

#### `calculate-driver-share(pool-id, driver)`
Calculate a driver's share in a pool.
```clarity
(contract-call? .On-Chain-Rideshare-Settlement-Pool calculate-driver-share u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 💰 Economics

- **Platform Fee**: 3% of each settlement pool
- **Dispute Deposit**: 1 STX required to raise disputes
- **Share Calculation**: Base share + rides bonus
  - Base: `total_amount / driver_count`
  - Bonus: `(rides_count * total_amount) / 1000`

## 🔧 Usage Example

```clarity
;; 1. Register as driver
(contract-call? .On-Chain-Rideshare-Settlement-Pool register-driver)

;; 2. Platform creates pool with 100 STX
(contract-call? .On-Chain-Rideshare-Settlement-Pool create-settlement-pool u100000000)

;; 3. Add driver with 50 rides to pool
(contract-call? .On-Chain-Rideshare-Settlement-Pool add-driver-to-pool u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u50)

;; 4. Driver claims payment
(contract-call? .On-Chain-Rideshare-Settlement-Pool claim-payment u1)
```

## 🚀 Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Running Tests
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy --testnet
```

## 🏗️ Architecture

The contract manages three main data structures:
- **Drivers Map**: Stores driver profiles and earnings
- **Settlement Pools**: Tracks pool funds and distribution status  
- **Pool-Drivers**: Links drivers to specific pools with ride data

## ⚠️ Error Codes

| Code | Description |
|------|-------------|
| 1001 | Not authorized |
| 1002 | Driver not found |
| 1003 | Insufficient funds |
| 1004 | Pool not found |
| 1005 | Dispute active |
| 1006 | Dispute not found |
| 1007 | Invalid amount |
| 1008 | Already exists |

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.
