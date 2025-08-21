;; ============================================================================
;; Title: ASTRALFOUNTAIN UBI TREASURY
;; ============================================================================
;; Summary:
;; A governance-aware universal basic income (UBI) smart contract that maintains
;; a verified participant registry, schedules UBI claims on a fixed interval,
;; and enables on-chain parameter updates via proposals and voting-backed by a
;; guarded treasury with emergency pause controls.
;;
;; Description:
;; AstralFountain coordinates a recurring UBI distribution to eligible,
;; verified participants. It tracks claim cadence per address, enforces a
;; cooldown between claims, and refuses payouts when the treasury is below a
;; minimum balance threshold. A lightweight governance module lets registered
;; participants submit, review, and vote on proposals to adjust distribution
;; parameters. Administrators retain the ability to pause/unpause operations
;; during incidents. Read-only views expose participant, treasury, and proposal
;; state for full transparency.
;; ============================================================================

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-registered (err u101))
(define-constant err-not-registered (err u102))
(define-constant err-ineligible (err u103))
(define-constant err-cooldown-active (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-unauthorized (err u107))
(define-constant err-invalid-proposal (err u108))
(define-constant err-expired-proposal (err u109))
(define-constant err-invalid-value (err u110))
(define-constant distribution-interval u144) ;; ~1 day in blocks
(define-constant minimum-balance u10000000) ;; Minimum treasury balance
(define-constant max-proposed-value u1000000000000) ;; Maximum value for proposals

;; Data Variables
(define-data-var treasury-balance uint u0)
(define-data-var total-participants uint u0)
(define-data-var distribution-amount uint u1000000) ;; 1 STX = 1000000 microSTX
(define-data-var last-distribution-height uint u0)
(define-data-var paused bool false)
(define-data-var proposal-counter uint u0)

;; Data Maps
(define-map participants
  principal
  {
    registered: bool,
    last-claim-height: uint,
    total-claimed: uint,
    verification-status: bool,
    join-height: uint,
    claims-count: uint,
  }
)

(define-map governance-proposals
  uint
  {
    proposer: principal,
    proposal-type: (string-ascii 32),
    proposed-value: uint,
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 10),
    expiry-height: uint,
  }
)

(define-map voter-records
  {
    proposal-id: uint,
    voter: principal,
  }
  bool
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (is-eligible (user principal))
  (match (map-get? participants user)
    participant-info (and
      (get verification-status participant-info)
      (>= (- stacks-block-height (get last-claim-height participant-info))
        distribution-interval
      )
      (>= (var-get treasury-balance) (var-get distribution-amount))
    )
    false
  )
)

(define-private (update-participant-record
    (user principal)
    (claimed-amount uint)
  )
  (match (map-get? participants user)
    current-info (ok (map-set participants user
      (merge current-info {
        last-claim-height: stacks-block-height,
        total-claimed: (+ (get total-claimed current-info) claimed-amount),
        claims-count: (+ (get claims-count current-info) u1),
      })
    ))
    err-not-registered
  )
)

(define-private (is-valid-proposal-type (proposal-type (string-ascii 32)))
  (or
    (is-eq proposal-type "distribution-amount")
    (is-eq proposal-type "distribution-interval")
    (is-eq proposal-type "minimum-balance")
  )
)

(define-private (is-valid-proposed-value (value uint))
  (and
    (> value u0)
    (<= value max-proposed-value)
  )
)

;; Public Functions
(define-public (register)
  (let ((existing-record (map-get? participants tx-sender)))
    (asserts! (is-none existing-record) err-already-registered)
    (map-set participants tx-sender {
      registered: true,
      last-claim-height: u0,
      total-claimed: u0,
      verification-status: false,
      join-height: stacks-block-height,
      claims-count: u0,
    })
    (var-set total-participants (+ (var-get total-participants) u1))
    (ok true)
  )
)

(define-public (verify-participant (user principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (asserts! (is-some (map-get? participants user)) err-not-registered)
    (map-set participants user
      (merge (unwrap! (map-get? participants user) err-not-registered) { verification-status: true })
    )
    (ok true)
  )
)

(define-public (claim-ubi)
  (let (
      (user tx-sender)
      (can-claim (is-eligible user))
    )
    (asserts! (not (var-get paused)) err-unauthorized)
    (asserts! can-claim err-ineligible)
    (asserts! (>= (var-get treasury-balance) (var-get distribution-amount))
      err-insufficient-funds
    )

    ;; Process claim
    (try! (as-contract (stx-transfer? (var-get distribution-amount) contract-caller user)))
    (var-set treasury-balance
      (- (var-get treasury-balance) (var-get distribution-amount))
    )
    (try! (update-participant-record user (var-get distribution-amount)))
    (ok (var-get distribution-amount))
  )
)

(define-public (contribute)
  (let ((amount (stx-get-balance tx-sender)))
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set treasury-balance (+ (var-get treasury-balance) amount))
    (ok amount)
  )
)

;; Governance Functions
(define-public (submit-proposal
    (proposal-type (string-ascii 32))
    (proposed-value uint)
  )
  (let ((new-proposal-id (+ (var-get proposal-counter) u1)))
    (asserts! (is-some (map-get? participants tx-sender)) err-not-registered)
    (asserts! (is-valid-proposal-type proposal-type) err-invalid-proposal)
    (asserts! (is-valid-proposed-value proposed-value) err-invalid-value)

    (map-set governance-proposals new-proposal-id {
      proposer: tx-sender,
      proposal-type: proposal-type,
      proposed-value: proposed-value,
      votes-for: u0,
      votes-against: u0,
      status: "active",
      expiry-height: (+ stacks-block-height u1440),
    })
    (var-set proposal-counter new-proposal-id)
    (ok new-proposal-id)
  )
)

(define-public (vote
    (proposal-id uint)
    (vote-for bool)
  )
  (let (
      (proposal (unwrap! (map-get? governance-proposals proposal-id) err-not-registered))
      (voter-key {
        proposal-id: proposal-id,
        voter: tx-sender,
      })
    )
    (asserts! (is-some (map-get? participants tx-sender)) err-not-registered)
    (asserts! (is-none (map-get? voter-records voter-key)) err-already-registered)
    (asserts! (<= proposal-id (var-get proposal-counter)) err-invalid-proposal)
    (asserts! (< stacks-block-height (get expiry-height proposal))
      err-expired-proposal
    )
    (asserts! (is-eq (get status proposal) "active") err-invalid-proposal)

    (map-set voter-records voter-key true)
    (map-set governance-proposals proposal-id
      (merge proposal {
        votes-for: (if vote-for
          (+ (get votes-for proposal) u1)
          (get votes-for proposal)
        ),
        votes-against: (if vote-for
          (get votes-against proposal)
          (+ (get votes-against proposal) u1)
        ),
      })
    )
    (ok true)
  )
)

;; Emergency Functions
(define-public (pause)
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (var-set paused true)
    (ok true)
  )
)

(define-public (unpause)
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (var-set paused false)
    (ok true)
  )
)

;; Getter Functions
(define-read-only (get-participant-info (user principal))
  (map-get? participants user)
)

(define-read-only (get-treasury-balance)
  (var-get treasury-balance)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? governance-proposals proposal-id)
)

(define-read-only (get-distribution-info)
  {
    amount: (var-get distribution-amount),
    interval: distribution-interval,
    last-height: (var-get last-distribution-height),
    minimum-balance: minimum-balance,
  }
)
