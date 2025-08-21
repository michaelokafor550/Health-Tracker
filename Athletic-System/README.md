# Athlete Performance Tracking Smart Contract

A comprehensive Clarity smart contract for managing athlete registration, performance tracking, leaderboards, and achievement systems on the Stacks blockchain.

## Overview

This smart contract provides a complete solution for tracking athlete performance data, maintaining leaderboards, and awarding achievements in a decentralized manner. It's designed for sports organizations, training facilities, and athletic competitions that need transparent and verifiable performance tracking.

## Features

### Core Functionality
- **Athlete Registration**: Register athletes with profile information including name, sport, and age
- **Performance Tracking**: Record and manage athlete performance data with timestamps
- **Verification System**: Authorized coaches and contract owners can verify performance records
- **Authorization Management**: Multi-level authorization system for coaches and administrators

### Advanced Features
- **Global Leaderboards**: Sport and event-specific ranking system
- **Achievement System**: NFT-like achievement awards for performance milestones
- **Data Integrity**: Built-in validation and error handling
- **Access Control**: Role-based permissions for different user types

## Contract Structure

### Data Maps
- `athletes`: Stores athlete profile information
- `performance-records`: Individual performance entries with verification status
- `authorized-coaches`: List of authorized coaches who can verify records
- `global-leaderboard`: Rankings by sport and event
- `achievement-definitions`: Available achievements and requirements
- `athlete-achievements`: Individual achievement records

### Error Codes
- `ERR-NOT-AUTHORIZED (u100)`: Insufficient permissions
- `ERR-ATHLETE-NOT-FOUND (u101)`: Athlete doesn't exist
- `ERR-ATHLETE-EXISTS (u102)`: Athlete already registered
- `ERR-INVALID-PERFORMANCE (u103)`: Invalid performance data
- `ERR-INVALID-SPORT (u104)`: Invalid sport specification
- `ERR-INVALID-TIME (u105)`: Invalid timing data

## Public Functions

### Athlete Management

#### `register-athlete`
```clarity
(register-athlete (athlete-id principal) (name string-ascii) (sport string-ascii) (age uint))
```
Registers a new athlete in the system.

**Parameters:**
- `athlete-id`: Principal address of the athlete
- `name`: Athlete's name (max 50 characters)
- `sport`: Sport category (max 20 characters)
- `age`: Athlete's age

#### `deactivate-athlete`
```clarity
(deactivate-athlete (athlete-id principal))
```
Deactivates an athlete account. Can only be called by the athlete or contract owner.

### Performance Tracking

#### `add-performance`
```clarity
(add-performance (athlete-id principal) (event-name string-ascii) (performance-value uint) (measurement-unit string-ascii))
```
Records a new performance entry for an athlete.

**Parameters:**
- `athlete-id`: Principal address of the athlete
- `event-name`: Name of the event or competition
- `performance-value`: Numeric performance value
- `measurement-unit`: Unit of measurement (e.g., "ms", "points", "meters")

**Authorization:** Athlete, authorized coach, or contract owner

#### `verify-performance`
```clarity
(verify-performance (athlete-id principal) (record-id uint))
```
Verifies a performance record as authentic.

**Authorization:** Contract owner or authorized coach

### Authorization Management

#### `authorize-coach`
```clarity
(authorize-coach (coach-id principal))
```
Grants coaching authorization to a principal.

**Authorization:** Contract owner only

#### `revoke-coach-authorization`
```clarity
(revoke-coach-authorization (coach-id principal))
```
Revokes coaching authorization from a principal.

**Authorization:** Contract owner only

### Achievement System

#### `initialize-achievements`
```clarity
(initialize-achievements)
```
Sets up default achievement definitions. Should be called once after contract deployment.

**Authorization:** Contract owner only

#### `award-achievement`
```clarity
(award-achievement (athlete-id principal) (achievement-id uint) (performance-trigger optional))
```
Awards an achievement to an athlete.

**Authorization:** Contract owner or authorized coach

## Read-Only Functions

### Athlete Information
- `get-athlete-profile`: Retrieve athlete profile data
- `is-athlete-active`: Check if athlete is currently active
- `get-athlete-performance-count`: Get total performance records for athlete

### Performance Data
- `get-performance-record`: Retrieve specific performance record
- `get-latest-performance`: Get athlete's most recent performance
- `is-performance-verified`: Check verification status of a record
- `performance-record-exists`: Verify if a specific record exists

### Leaderboard System
- `get-leaderboard-entry`: Retrieve leaderboard entry by rank
- `get-leaderboard-size`: Get total entries for sport/event combination

### Achievement System
- `has-achievement`: Check if athlete has specific achievement
- `get-athlete-achievement`: Get achievement details for athlete
- `get-achievement-definition`: Retrieve achievement requirements
- `get-athlete-achievement-count`: Get total achievements for athlete

### Authorization
- `is-coach-authorized`: Check if principal has coaching authorization
- `get-contract-owner`: Retrieve contract owner address

## Default Achievements

The contract includes three built-in achievements:

1. **First Steps**: Awarded for recording first performance
2. **Consistent Performer**: Awarded for recording 10 performances  
3. **Verified Athlete**: Awarded for having 5 verified performance records

## Usage Examples

### Basic Athlete Registration
```clarity
;; Register a new athlete
(contract-call? .athlete-tracker register-athlete 'SP1234... "John Doe" "Swimming" u25)

;; Add a performance record
(contract-call? .athlete-tracker add-performance 'SP1234... "100m Freestyle" u58320 "ms")

;; Verify the performance (as authorized coach)
(contract-call? .athlete-tracker verify-performance 'SP1234... u1)
```

### Coach Authorization Flow
```clarity
;; Contract owner authorizes a coach
(contract-call? .athlete-tracker authorize-coach 'SP5678...)

;; Coach can now verify performances
(contract-call? .athlete-tracker verify-performance 'SP1234... u1)
```

## Deployment Notes

1. The deploying address becomes the contract owner with full administrative privileges
2. Call `initialize-achievements` after deployment to set up default achievements
3. Authorize coaches before they can verify performance records
4. All performance values should be stored in consistent units (e.g., milliseconds for time-based events)

## Security Considerations

- All sensitive operations require proper authorization checks
- Performance data is immutable once recorded
- Only verification status can be updated after record creation
- Role-based access control prevents unauthorized modifications
- Input validation prevents invalid data entry

## Integration

This contract can be integrated with:
- Sports management applications
- Athletic competition platforms
- Training facility management systems
- Performance analytics tools
- Achievement and reward systems