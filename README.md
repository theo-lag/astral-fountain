# AstralFountain UBI Treasury

A governance-aware Universal Basic Income (UBI) smart contract built on the Stacks blockchain that enables transparent, decentralized distribution of STX tokens to verified participants through a democratic governance system.

## Overview

AstralFountain coordinates recurring UBI distributions to eligible, verified participants while maintaining treasury sustainability and democratic governance. The contract enforces claim intervals, manages participant verification, and enables community-driven parameter adjustments through on-chain proposals and voting.

## Features

### Core Functionality

- **Participant Registration**: Open registration system with verification requirement
- **Periodic UBI Claims**: Fixed interval-based distribution (144 blocks ≈ 1 day)
- **Treasury Management**: Contribution system with minimum balance protection
- **Emergency Controls**: Owner-controlled pause/unpause functionality

### Governance System

- **Proposal Submission**: Registered participants can propose parameter changes
- **Democratic Voting**: One participant, one vote system
- **Parameter Updates**: Modify distribution amount, intervals, and treasury thresholds
- **Proposal Expiry**: Time-limited voting periods (1440 blocks ≈ 10 days)

### Security Features

- **Verification Requirement**: Only verified participants can claim UBI
- **Cooldown Enforcement**: Prevents double-claiming within distribution intervals
- **Treasury Protection**: Maintains minimum balance threshold
- **Access Controls**: Owner-only administrative functions

## Architecture

### System Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Participants  │    │   Governance    │    │    Treasury     │
│                 │    │                 │    │                 │
│  • Registration │    │  • Proposals    │    │  • Contributions│
│  • Verification │◄──►│  • Voting       │◄──►│  • Distributions│
│  • UBI Claims   │    │  • Parameter    │    │  • Balance Mgmt │
│                 │    │    Updates      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Contract Architecture

#### Data Structures

**Participants Map**

```clarity
{
  registered: bool,           // Registration status
  last-claim-height: uint,    // Block height of last claim
  total-claimed: uint,        // Total STX claimed
  verification-status: bool,  // Verification by contract owner
  join-height: uint,         // Registration block height
  claims-count: uint         // Number of successful claims
}
```

**Governance Proposals Map**

```clarity
{
  proposer: principal,              // Proposal creator
  proposal-type: string-ascii,      // Parameter to modify
  proposed-value: uint,             // New parameter value
  votes-for: uint,                  // Supporting votes
  votes-against: uint,              // Opposing votes
  status: string-ascii,             // Proposal state
  expiry-height: uint              // Voting deadline
}
```

#### Core Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `distribution-interval` | 144 blocks | Minimum time between claims (~1 day) |
| `minimum-balance` | 10,000,000 µSTX | Treasury protection threshold |
| `max-proposed-value` | 1,000,000,000,000 µSTX | Maximum proposal value |

### Data Flow

#### UBI Claim Process

```
1. User calls claim-ubi()
2. Check eligibility:
   - User is verified participant
   - Cooldown period has passed
   - Treasury has sufficient balance
   - Contract is not paused
3. Transfer STX from contract to user
4. Update treasury balance
5. Update participant record
6. Return claimed amount
```

#### Governance Flow

```
1. Participant submits proposal
2. Community votes during voting period
3. Proposal expires after 1440 blocks
4. Manual execution of approved proposals
   (Note: Automatic execution not implemented)
```

## Usage

### For Participants

#### Registration

```clarity
(contract-call? .astral-fountain register)
```

#### Claiming UBI (after verification)

```clarity
(contract-call? .astral-fountain claim-ubi)
```

#### Submitting Governance Proposals

```clarity
(contract-call? .astral-fountain submit-proposal "distribution-amount" u2000000)
```

#### Voting on Proposals

```clarity
(contract-call? .astral-fountain vote u1 true) ;; Vote for proposal #1
```

### For Contributors

#### Contributing to Treasury

```clarity
(contract-call? .astral-fountain contribute)
```

### For Contract Owner

#### Verifying Participants

```clarity
(contract-call? .astral-fountain verify-participant 'SP1234...)
```

#### Emergency Controls

```clarity
(contract-call? .astral-fountain pause)   ;; Pause operations
(contract-call? .astral-fountain unpause) ;; Resume operations
```

## Read-Only Functions

### Query Participant Information

```clarity
(contract-call? .astral-fountain get-participant-info 'SP1234...)
```

### Check Treasury Balance

```clarity
(contract-call? .astral-fountain get-treasury-balance)
```

### View Proposal Details

```clarity
(contract-call? .astral-fountain get-proposal u1)
```

### Get Distribution Parameters

```clarity
(contract-call? .astral-fountain get-distribution-info)
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `err-owner-only` | Function restricted to contract owner |
| 101 | `err-already-registered` | User already registered or voted |
| 102 | `err-not-registered` | User not found in participant registry |
| 103 | `err-ineligible` | User not eligible for UBI claim |
| 104 | `err-cooldown-active` | Claim cooldown period still active |
| 105 | `err-insufficient-funds` | Treasury balance too low |
| 106 | `err-invalid-amount` | Invalid contribution amount |
| 107 | `err-unauthorized` | Contract paused or unauthorized action |
| 108 | `err-invalid-proposal` | Invalid proposal type or inactive proposal |
| 109 | `err-expired-proposal` | Voting period has ended |
| 110 | `err-invalid-value` | Proposed value outside valid range |

## Governance Parameters

### Modifiable Parameters

- **distribution-amount**: UBI payout per claim (current: 1 STX)
- **distribution-interval**: Blocks between eligible claims (current: 144)
- **minimum-balance**: Treasury protection threshold (current: 10 STX)

### Proposal Types

- `"distribution-amount"`: Modify UBI payout amount
- `"distribution-interval"`: Adjust claim frequency
- `"minimum-balance"`: Update treasury protection threshold

## Development

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet)
- Node.js (for tests)

### Testing

```bash
# Run Clarity contract checks
clarinet check

# Run unit tests
npm test
```

### Deployment

1. Configure deployment settings in `settings/` folder
2. Deploy using Clarinet or preferred deployment tool

## Security Considerations

### Current Limitations

- **Manual Proposal Execution**: Approved proposals require manual implementation
- **Single Owner Model**: Centralized verification and emergency controls
- **No Slashing**: No penalty mechanism for malicious behavior

### Recommendations

- Implement multi-signature owner model
- Add automatic proposal execution mechanism
- Consider reputation-based verification system
- Implement participant slashing for governance abuse

## License

This project is open source. Please review the license terms before use.

## Contributing

Contributions are welcome! Please submit pull requests with comprehensive tests and documentation.
