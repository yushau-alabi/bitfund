# BitFund: Decentralized Bitcoin-Backed Fund Management

BitFund is a sophisticated decentralized fund management protocol built on the Stacks blockchain, leveraging Bitcoin's security and Stacks' programmability to enable transparent governance and secure fund management.

## Overview

BitFund enables users to:

- Deposit STX tokens into a managed fund
- Create and vote on fund allocation proposals
- Execute approved proposals
- Withdraw funds after lock periods
- Participate in democratic decision-making

## Key Features

### Secure Fund Management

- Time-locked deposits prevent flash loan attacks
- Minimum deposit requirements prevent spam
- Multi-layer security checks for all operations
- Protected withdrawal mechanisms
- Proportional voting power based on deposit size

### Governance System

- Democratic proposal creation
- Community-driven fund allocation
- Transparent voting mechanism
- Automated proposal execution
- Time-bounded voting periods

## Technical Specifications

### Constants

- Minimum proposal duration: 144 blocks (~1 day)
- Maximum proposal duration: 20,160 blocks (~14 days)
- Minimum deposit: 1,000,000 microSTX
- Lock period: 1,440 blocks (~10 days)

### Data Structures

#### Deposits

```clarity
{
    amount: uint,
    lock-until: uint,
    last-reward-block: uint
}
```

#### Proposals

```clarity
{
    proposer: principal,
    description: (string-ascii 256),
    amount: uint,
    target: principal,
    expires-at: uint,
    executed: bool,
    yes-votes: uint,
    no-votes: uint
}
```

## Core Functions

### Deposit

```clarity
(define-public (deposit (amount uint)))
```

- Accepts STX deposits above minimum threshold
- Mints fund tokens 1:1 with deposited STX
- Implements time-lock on deposits

### Withdraw

```clarity
(define-public (withdraw (amount uint)))
```

- Allows withdrawal after lock period expires
- Burns fund tokens upon withdrawal
- Returns equivalent STX to user

### Create Proposal

```clarity
(define-public (create-proposal
    (description (string-ascii 256))
    (amount uint)
    (target principal)
    (duration uint)
))
```

- Creates fund allocation proposals
- Requires proposer to hold fund tokens
- Enforces duration constraints

### Vote

```clarity
(define-public (vote (proposal-id uint) (vote-for bool)))
```

- Enables token holders to vote on proposals
- Voting power proportional to token holdings
- Prevents double voting

### Execute Proposal

```clarity
(define-public (execute-proposal (proposal-id uint)))
```

- Executes approved proposals after voting period
- Requires majority approval
- Transfers funds to target address

## Read-Only Functions

### Get Balance

```clarity
(define-read-only (get-balance (account principal)))
```

- Returns account's fund token balance

### Get Total Supply

```clarity
(define-read-only (get-total-supply))
```

- Returns total supply of fund tokens

### Get Proposal

```clarity
(define-read-only (get-proposal (proposal-id uint)))
```

- Returns detailed proposal information

### Get Deposit Info

```clarity
(define-read-only (get-deposit-info (account principal)))
```

- Returns account's deposit information

### Get Vote

```clarity
(define-read-only (get-vote (proposal-id uint) (voter principal)))
```

- Returns voter's decision on a proposal

## Security Measures

### Time Locks

- Deposits locked for 1,440 blocks (~10 days)
- Prevents rapid deposit/withdrawal attacks
- Ensures stable voting power

### Proposal Controls

- Minimum duration prevents rushed decisions
- Maximum duration ensures timely execution
- Description length limits prevent spam

### Access Controls

- Owner-only initialization
- Deposit-based voting rights
- Multi-step proposal execution

## Error Handling

The contract includes comprehensive error handling:

- Owner-only access errors
- Initialization state errors
- Balance and amount validation
- Proposal state validation
- Vote eligibility checks
- Duration and timing validations

## Best Practices

### For Users

1. Always verify proposal details before voting
2. Consider lock periods when planning deposits
3. Check voting power before creating proposals
4. Monitor proposal expiration times

### For Developers

1. Use read-only functions to verify state
2. Handle all error cases in client applications
3. Implement proper principal validation
4. Monitor block height for timing operations

## Integration Guide

### Initialization

```clarity
(contract-call? .bitfund initialize)
```

### Making Deposits

```clarity
(contract-call? .bitfund deposit u1000000)
```

### Creating Proposals

```clarity
(contract-call? .bitfund create-proposal "Fund allocation" u500000 tx-sender u1440)
```

### Voting

```clarity
(contract-call? .bitfund vote u1 true)
```
