;; Athlete Performance Tracking Smart Contract
;; This contract manages athlete registration and performance tracking

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ATHLETE-NOT-FOUND (err u101))
(define-constant ERR-ATHLETE-EXISTS (err u102))
(define-constant ERR-INVALID-PERFORMANCE (err u103))
(define-constant ERR-INVALID-SPORT (err u104))
(define-constant ERR-INVALID-TIME (err u105))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data structures

;; Athlete profile structure
(define-map athletes
  { athlete-id: principal }
  {
    name: (string-ascii 50),
    sport: (string-ascii 20),
    age: uint,
    registration-block: uint,
    active: bool
  }
)

;; Performance records structure
(define-map performance-records
  { athlete-id: principal, record-id: uint }
  {
    event-name: (string-ascii 50),
    performance-value: uint, ;; time in milliseconds or score
    measurement-unit: (string-ascii 10), ;; "ms", "points", "meters", etc.
    event-date: uint, ;; block height when recorded
    verified: bool
  }
)

;; Performance counter for each athlete
(define-map athlete-performance-count
  { athlete-id: principal }
  { count: uint }
)

;; Global performance counter
(define-data-var global-performance-id uint u0)

;; Authorized coaches/trainers
(define-map authorized-coaches
  { coach-id: principal }
  { authorized: bool }
)

;; Public functions

;; Register a new athlete
(define-public (register-athlete (athlete-id principal) 
                               (name (string-ascii 50)) 
                               (sport (string-ascii 20)) 
                               (age uint))
  (begin
    ;; Check if athlete already exists
    (asserts! (is-none (map-get? athletes { athlete-id: athlete-id })) ERR-ATHLETE-EXISTS)
    ;; Validate inputs
    (asserts! (> age u0) ERR-INVALID-PERFORMANCE)
    (asserts! (> (len name) u0) ERR-INVALID-PERFORMANCE)
    (asserts! (> (len sport) u0) ERR-INVALID-SPORT)
    
    ;; Register athlete
    (map-set athletes 
      { athlete-id: athlete-id }
      {
        name: name,
        sport: sport,
        age: age,
        registration-block: block-height,
        active: true
      }
    )
    
    ;; Initialize performance count
    (map-set athlete-performance-count
      { athlete-id: athlete-id }
      { count: u0 }
    )
    
    (ok true)
  )
)

;; Add performance record (only by athlete themselves or authorized coach)
(define-public (add-performance (athlete-id principal)
                              (event-name (string-ascii 50))
                              (performance-value uint)
                              (measurement-unit (string-ascii 10)))
  (let 
    (
      (current-count (default-to { count: u0 } 
                                (map-get? athlete-performance-count { athlete-id: athlete-id })))
      (new-record-id (+ (get count current-count) u1))
      (is-authorized (or (is-eq tx-sender athlete-id)
                        (is-some (map-get? authorized-coaches { coach-id: tx-sender }))
                        (is-eq tx-sender CONTRACT-OWNER)))
      (athlete-data (map-get? athletes { athlete-id: athlete-id }))
    )
    
    ;; Check authorization
    (asserts! is-authorized ERR-NOT-AUTHORIZED)
    ;; Check if athlete exists
    (asserts! (is-some athlete-data) ERR-ATHLETE-NOT-FOUND)
    ;; Validate inputs
    (asserts! (> (len event-name) u0) ERR-INVALID-PERFORMANCE)
    (asserts! (> performance-value u0) ERR-INVALID-PERFORMANCE)
    (asserts! (> (len measurement-unit) u0) ERR-INVALID-PERFORMANCE)
    
    ;; Add performance record
    (map-set performance-records
      { athlete-id: athlete-id, record-id: new-record-id }
      {
        event-name: event-name,
        performance-value: performance-value,
        measurement-unit: measurement-unit,
        event-date: block-height,
        verified: false
      }
    )
    
    ;; Update performance count
    (map-set athlete-performance-count
      { athlete-id: athlete-id }
      { count: new-record-id }
    )
    
    ;; Update global counter
    (var-set global-performance-id (+ (var-get global-performance-id) u1))
    
    ;; Update leaderboard
    (let 
      (
        (sport (get sport (unwrap-panic athlete-data)))
        (leaderboard-rank (update-leaderboard athlete-id sport event-name performance-value measurement-unit))
      )
      (ok { record-id: new-record-id, leaderboard-rank: leaderboard-rank })
    )
  )
)

;; Verify performance record (only by contract owner or authorized coach)
(define-public (verify-performance (athlete-id principal) (record-id uint))
  (let 
    (
      (current-record (map-get? performance-records { athlete-id: athlete-id, record-id: record-id }))
      (is-authorized (or (is-eq tx-sender CONTRACT-OWNER)
                        (is-some (map-get? authorized-coaches { coach-id: tx-sender }))))
    )
    
    ;; Check authorization
    (asserts! is-authorized ERR-NOT-AUTHORIZED)
    ;; Check if record exists
    (asserts! (is-some current-record) ERR-ATHLETE-NOT-FOUND)
    
    ;; Update verification status
    (map-set performance-records
      { athlete-id: athlete-id, record-id: record-id }
      (merge (unwrap-panic current-record) { verified: true })
    )
    
    (ok true)
  )
)

;; Authorize coach (only contract owner)
(define-public (authorize-coach (coach-id principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-coaches
      { coach-id: coach-id }
      { authorized: true }
    )
    (ok true)
  )
)

;; Revoke coach authorization (only contract owner)
(define-public (revoke-coach-authorization (coach-id principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-delete authorized-coaches { coach-id: coach-id })
    (ok true)
  )
)

;; Deactivate athlete (only by athlete themselves or contract owner)
(define-public (deactivate-athlete (athlete-id principal))
  (let 
    (
      (current-athlete (map-get? athletes { athlete-id: athlete-id }))
      (is-authorized (or (is-eq tx-sender athlete-id) (is-eq tx-sender CONTRACT-OWNER)))
    )
    
    ;; Check authorization
    (asserts! is-authorized ERR-NOT-AUTHORIZED)
    ;; Check if athlete exists
    (asserts! (is-some current-athlete) ERR-ATHLETE-NOT-FOUND)
    
    ;; Deactivate athlete
    (map-set athletes
      { athlete-id: athlete-id }
      (merge (unwrap-panic current-athlete) { active: false })
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get athlete profile
(define-read-only (get-athlete-profile (athlete-id principal))
  (map-get? athletes { athlete-id: athlete-id })
)

;; Get specific performance record
(define-read-only (get-performance-record (athlete-id principal) (record-id uint))
  (map-get? performance-records { athlete-id: athlete-id, record-id: record-id })
)

;; Get athlete's total performance count
(define-read-only (get-athlete-performance-count (athlete-id principal))
  (default-to { count: u0 } 
              (map-get? athlete-performance-count { athlete-id: athlete-id }))
)

;; Check if athlete is active
(define-read-only (is-athlete-active (athlete-id principal))
  (match (map-get? athletes { athlete-id: athlete-id })
    athlete-data (get active athlete-data)
    false
  )
)

;; Check if coach is authorized
(define-read-only (is-coach-authorized (coach-id principal))
  (is-some (map-get? authorized-coaches { coach-id: coach-id }))
)

;; Get performance record verification status
(define-read-only (is-performance-verified (athlete-id principal) (record-id uint))
  (match (map-get? performance-records { athlete-id: athlete-id, record-id: record-id })
    record-data (get verified record-data)
    false
  )
)

;; Get contract owner
(define-read-only (get-contract-owner)
  CONTRACT-OWNER
)

;; Get global performance count
(define-read-only (get-global-performance-count)
  (var-get global-performance-id)
)

;; Get latest performance record for athlete
(define-read-only (get-latest-performance (athlete-id principal))
  (let 
    (
      (latest-id (get count (get-athlete-performance-count athlete-id)))
    )
    (if (> latest-id u0)
      (map-get? performance-records { athlete-id: athlete-id, record-id: latest-id })
      none
    )
  )
)

;; Get performance record by specific record ID (direct lookup)
(define-read-only (get-performance-by-id (athlete-id principal) (record-id uint))
  (map-get? performance-records { athlete-id: athlete-id, record-id: record-id })
)

;; Check if a specific performance record exists
(define-read-only (performance-record-exists (athlete-id principal) (record-id uint))
  (is-some (map-get? performance-records { athlete-id: athlete-id, record-id: record-id }))
)

;; LEADERBOARD & RANKING SYSTEM

;; Global leaderboard entry structure
(define-map global-leaderboard
  { sport: (string-ascii 20), event-name: (string-ascii 50), rank: uint }
  { 
    athlete-id: principal,
    performance-value: uint,
    measurement-unit: (string-ascii 10),
    record-date: uint
  }
)

;; Sport-specific leaderboard counters
(define-map sport-leaderboard-size
  { sport: (string-ascii 20), event-name: (string-ascii 50) }
  { total-entries: uint }
)

;; Update leaderboard when new performance is added (called internally)
(define-private (update-leaderboard (athlete-id principal) 
                                   (sport (string-ascii 20))
                                   (event-name (string-ascii 50))
                                   (performance-value uint)
                                   (measurement-unit (string-ascii 10)))
  (let 
    (
      (current-size (default-to { total-entries: u0 } 
                                (map-get? sport-leaderboard-size { sport: sport, event-name: event-name })))
      (new-rank (+ (get total-entries current-size) u1))
    )
    
    ;; Add to leaderboard
    (map-set global-leaderboard
      { sport: sport, event-name: event-name, rank: new-rank }
      {
        athlete-id: athlete-id,
        performance-value: performance-value,
        measurement-unit: measurement-unit,
        record-date: block-height
      }
    )
    
    ;; Update counter
    (map-set sport-leaderboard-size
      { sport: sport, event-name: event-name }
      { total-entries: new-rank }
    )
    
    new-rank
  )
)

;; Get leaderboard entry by rank
(define-read-only (get-leaderboard-entry (sport (string-ascii 20)) 
                                        (event-name (string-ascii 50)) 
                                        (rank uint))
  (map-get? global-leaderboard { sport: sport, event-name: event-name, rank: rank })
)

;; Get total entries in sport/event leaderboard
(define-read-only (get-leaderboard-size (sport (string-ascii 20)) (event-name (string-ascii 50)))
  (default-to { total-entries: u0 } 
              (map-get? sport-leaderboard-size { sport: sport, event-name: event-name }))
)

;; Get first performance record for athlete
(define-read-only (get-first-performance (athlete-id principal))
  (map-get? performance-records { athlete-id: athlete-id, record-id: u1 })
)

;; NFT ACHIEVEMENT SYSTEM

;; Achievement types and requirements
(define-map achievement-definitions
  { achievement-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 100),
    requirement-type: (string-ascii 20), ;; "performance-count", "verified-records", "personal-best"
    requirement-value: uint,
    sport-specific: bool,
    target-sport: (optional (string-ascii 20))
  }
)

;; Athlete achievements (NFT-like records)
(define-map athlete-achievements
  { athlete-id: principal, achievement-id: uint }
  {
    earned-date: uint,
    performance-trigger: (optional uint), ;; record-id that triggered achievement
    verified: bool,
    metadata-uri: (optional (string-ascii 200))
  }
)

;; Achievement counters
(define-data-var total-achievements uint u0)
(define-map athlete-achievement-count
  { athlete-id: principal }
  { count: uint }
)

;; Initialize default achievements (called once by contract owner)
(define-public (initialize-achievements)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    ;; First Performance Achievement
    (map-set achievement-definitions
      { achievement-id: u1 }
      {
        name: "First Steps",
        description: "Record your first performance",
        requirement-type: "performance-count",
        requirement-value: u1,
        sport-specific: false,
        target-sport: none
      }
    )
    
    ;; Consistent Performer Achievement
    (map-set achievement-definitions
      { achievement-id: u2 }
      {
        name: "Consistent Performer",
        description: "Record 10 performances",
        requirement-type: "performance-count",
        requirement-value: u10,
        sport-specific: false,
        target-sport: none
      }
    )
    
    ;; Verified Athlete Achievement
    (map-set achievement-definitions
      { achievement-id: u3 }
      {
        name: "Verified Athlete",
        description: "Get 5 verified performance records",
        requirement-type: "verified-records",
        requirement-value: u5,
        sport-specific: false,
        target-sport: none
      }
    )
    
    (var-set total-achievements u3)
    (ok true)
  )
)

;; Award achievement to athlete
(define-public (award-achievement (athlete-id principal) 
                                (achievement-id uint) 
                                (performance-trigger (optional uint)))
  (let 
    (
      (achievement-def (map-get? achievement-definitions { achievement-id: achievement-id }))
      (existing-achievement (map-get? athlete-achievements { athlete-id: athlete-id, achievement-id: achievement-id }))
      (current-count (default-to { count: u0 } 
                                (map-get? athlete-achievement-count { athlete-id: athlete-id })))
      (is-authorized (or (is-eq tx-sender CONTRACT-OWNER)
                        (is-some (map-get? authorized-coaches { coach-id: tx-sender }))))
    )
    
    ;; Check authorization
    (asserts! is-authorized ERR-NOT-AUTHORIZED)
    ;; Check if achievement exists
    (asserts! (is-some achievement-def) ERR-ATHLETE-NOT-FOUND)
    ;; Check if athlete doesn't already have this achievement
    (asserts! (is-none existing-achievement) ERR-ATHLETE-EXISTS)
    ;; Check if athlete exists
    (asserts! (is-some (map-get? athletes { athlete-id: athlete-id })) ERR-ATHLETE-NOT-FOUND)
    
    ;; Award achievement
    (map-set athlete-achievements
      { athlete-id: athlete-id, achievement-id: achievement-id }
      {
        earned-date: block-height,
        performance-trigger: performance-trigger,
        verified: true,
        metadata-uri: none
      }
    )
    
    ;; Update athlete achievement count
    (map-set athlete-achievement-count
      { athlete-id: athlete-id }
      { count: (+ (get count current-count) u1) }
    )
    
    (ok true)
  )
)

;; Check if athlete has specific achievement
(define-read-only (has-achievement (athlete-id principal) (achievement-id uint))
  (is-some (map-get? athlete-achievements { athlete-id: athlete-id, achievement-id: achievement-id }))
)

;; Get athlete's achievement details
(define-read-only (get-athlete-achievement (athlete-id principal) (achievement-id uint))
  (map-get? athlete-achievements { athlete-id: athlete-id, achievement-id: achievement-id })
)

;; Get achievement definition
(define-read-only (get-achievement-definition (achievement-id uint))
  (map-get? achievement-definitions { achievement-id: achievement-id })
)

;; Get athlete's total achievement count
(define-read-only (get-athlete-achievement-count (athlete-id principal))
  (default-to { count: u0 } 
              (map-get? athlete-achievement-count { athlete-id: athlete-id }))
)

;; Auto-check and award achievements based on performance milestones
(define-private (check-achievement-eligibility (athlete-id principal))
  (let 
    (
      (performance-count (get count (get-athlete-performance-count athlete-id)))
    )
    performance-count
  )
)