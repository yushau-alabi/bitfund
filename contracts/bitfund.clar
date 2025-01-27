;; Title: BitFund - Decentralized Bitcoin-Backed Fund Management
;;
;; Summary:
;; A sophisticated decentralized fund management protocol built on Stacks, leveraging 
;; Bitcoin's security and Stacks' programmability. BitFund enables transparent governance,
;; secure fund management, and democratic decision-making for Bitcoin-backed assets.
;;
;; Description:
;; BitFund revolutionizes decentralized fund management by providing:
;; - Secure deposit and withdrawal mechanisms with time-locks
;; - Democratic proposal creation and voting system
;; - Transparent fund allocation through community governance
;; - Proportional voting power based on deposit size
;; - Automated proposal execution with multi-layer security checks
;;
;; The protocol ensures maximum security through:
;; - Time-locked deposits preventing flash loan attacks
;; - Minimum deposit requirements to prevent spam
;; - Duration constraints on proposals for proper deliberation
;; - Multiple validation layers for proposal execution
;; - Protected withdrawal mechanisms

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-initialized (err u101))
(define-constant err-already-initialized (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-proposal-not-found (err u106))
(define-constant err-proposal-expired (err u107))
(define-constant err-already-voted (err u108))
(define-constant err-below-minimum (err u109))
(define-constant err-locked-period (err u110))
(define-constant err-transfer-failed (err u111))
(define-constant err-invalid-duration (err u112))
(define-constant err-zero-amount (err u113))
(define-constant err-invalid-target (err u114))
(define-constant err-invalid-description (err u115))
(define-constant err-invalid-proposal-id (err u116))
(define-constant err-invalid-vote (err u117))
(define-constant minimum-duration u144) ;; minimum 1 day (assuming 10min blocks)
(define-constant maximum-duration u20160) ;; maximum 14 days

;; Data Variables
(define-data-var total-supply uint u0)
(define-data-var minimum-deposit uint u1000000) ;; in microSTX
(define-data-var lock-period uint u1440) ;; ~10 days in blocks
(define-data-var initialized bool false)
(define-data-var last-rebalance uint u0)
(define-data-var proposal-count uint u0)

;; Data Maps
(define-map balances principal uint)
(define-map deposits
    principal
    {
        amount: uint,
        lock-until: uint,
        last-reward-block: uint
    }
)

(define-map proposals
    uint
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
)

(define-map votes {proposal-id: uint, voter: principal} bool)

;; Private Functions
(define-private (is-contract-owner)
    (is-eq tx-sender contract-owner)
)

(define-private (check-initialized)
    (ok (asserts! (var-get initialized) err-not-initialized))
)

(define-private (validate-proposal-id (proposal-id uint))
    (ok (asserts! (<= proposal-id (var-get proposal-count)) err-invalid-proposal-id))
)

(define-private (calculate-voting-power (voter principal))
    (default-to u0 (map-get? balances voter))
)

(define-private (transfer-tokens (sender principal) (recipient principal) (amount uint))
    (let (
        (sender-balance (default-to u0 (map-get? balances sender)))
        (recipient-balance (default-to u0 (map-get? balances recipient)))
    )
        (asserts! (>= sender-balance amount) err-insufficient-balance)
        (map-set balances sender (- sender-balance amount))
        (map-set balances recipient (+ recipient-balance amount))
        (ok true)
    )
)

(define-private (mint-tokens (account principal) (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? balances account)))
    )
        (map-set balances account (+ current-balance amount))
        (var-set total-supply (+ (var-get total-supply) amount))
        (ok true)
    )
)

(define-private (burn-tokens (account principal) (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? balances account)))
    )
        (asserts! (>= current-balance amount) err-insufficient-balance)
        (map-set balances account (- current-balance amount))
        (var-set total-supply (- (var-get total-supply) amount))
        (ok true)
    )
)

;; Public Functions

;; desc Initialize the contract with default settings
;; access Contract owner only
;; returns (ok true) on success
(define-public (initialize)
    (begin
        (asserts! (is-contract-owner) err-owner-only)
        (asserts! (not (var-get initialized)) err-already-initialized)
        (var-set initialized true)
        (ok true)
    )
)

;; desc Deposit STX tokens into the fund
;; param amount: The amount of STX to deposit (in microSTX)
;; returns (ok true) on successful deposit
(define-public (deposit (amount uint))
    (begin
        (try! (check-initialized))
        (asserts! (>= amount (var-get minimum-deposit)) err-below-minimum)
        (asserts! (> amount u0) err-zero-amount)

        ;; Transfer STX to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update deposit records
        (map-set deposits tx-sender {
            amount: amount,
            lock-until: (+ block-height (var-get lock-period)),
            last-reward-block: block-height
        })
        
        ;; Mint fund tokens
        (mint-tokens tx-sender amount)
    )
)

;; desc Withdraw STX tokens from the fund
;; param amount: The amount of STX to withdraw (in microSTX)
;; returns (ok true) on successful withdrawal
(define-public (withdraw (amount uint))
    (begin
        (try! (check-initialized))
        (asserts! (> amount u0) err-zero-amount)

        (let (
            (deposit-info (unwrap! (map-get? deposits tx-sender) err-unauthorized))
            (user-balance (unwrap! (get-balance tx-sender) err-unauthorized))
        )
            (asserts! (>= block-height (get lock-until deposit-info)) err-locked-period)
            (asserts! (>= user-balance amount) err-insufficient-balance)
            
            ;; Burn tokens first
            (try! (burn-tokens tx-sender amount))
            
            ;; Transfer STX back to user
            (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender))
        )
    )
)

;; desc Create a new proposal for fund allocation
;; param description: Proposal description (max 256 ASCII chars)
;; param amount: Amount of STX to allocate
;; param target: Recipient address
;; param duration: Proposal duration in blocks
;; returns (ok uint) with proposal ID on success
(define-public (create-proposal
    (description (string-ascii 256))
    (amount uint)
    (target principal)
    (duration uint)
)
    (begin
        (try! (check-initialized))

        ;; Input validation
        (asserts! (> (len description) u0) err-invalid-description)
        (asserts! (> amount u0) err-zero-amount)
        (asserts! (not (is-eq target (as-contract tx-sender))) err-invalid-target)
        (asserts! (and (>= duration minimum-duration) (<= duration maximum-duration)) err-invalid-duration)
        
        (let (
            (proposer-balance (unwrap! (map-get? balances tx-sender) err-unauthorized))
            (proposal-id (+ (var-get proposal-count) u1))
        )
            (asserts! (> proposer-balance u0) err-unauthorized)
            
            ;; Create new proposal with validated inputs
            (map-set proposals proposal-id {
                proposer: tx-sender,
                description: description,
                amount: amount,
                target: target,
                expires-at: (+ block-height duration),
                executed: false,
                yes-votes: u0,
                no-votes: u0
            })
            
            (var-set proposal-count proposal-id)
            (ok proposal-id)
        )
    )
)

;; desc Cast a vote on an existing proposal
;; param proposal-id: The ID of the proposal
;; param vote-for: true for yes, false for no
;; returns (ok true) on successful vote
(define-public (vote (proposal-id uint) (vote-for bool))
    (begin
        (try! (check-initialized))
        (try! (validate-proposal-id proposal-id))

        (let (
            (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
            (voter-power (calculate-voting-power tx-sender))
        )
            (asserts! (> voter-power u0) err-unauthorized)
            (asserts! (< block-height (get expires-at proposal)) err-proposal-expired)
            (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) err-already-voted)
            
            ;; Record vote after all validations pass
            (map-set votes {proposal-id: proposal-id, voter: tx-sender} vote-for)
            
            ;; Update vote counts
            (map-set proposals proposal-id 
                (merge proposal 
                    {
                        yes-votes: (if vote-for 
                            (+ (get yes-votes proposal) voter-power)
                            (get yes-votes proposal)),
                        no-votes: (if vote-for
                            (get no-votes proposal)
                            (+ (get no-votes proposal) voter-power))
                    }
                )
            )
            
            (ok true)
        )
    )
)

;; desc Execute an approved proposal
;; param proposal-id: The ID of the proposal to execute
;; returns (ok true) on successful execution
(define-public (execute-proposal (proposal-id uint))
    (begin
        (try! (check-initialized))
        (try! (validate-proposal-id proposal-id))

        (let (
            (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
            (contract-balance (stx-get-balance (as-contract tx-sender)))
        )
            (asserts! (not (get executed proposal)) err-unauthorized)
            (asserts! (>= block-height (get expires-at proposal)) err-proposal-expired)
            (asserts! (> (get yes-votes proposal) (get no-votes proposal)) err-unauthorized)
            (asserts! (>= contract-balance (get amount proposal)) err-insufficient-balance)
            
            ;; Execute proposal (transfer funds)
            (try! (as-contract (stx-transfer? (get amount proposal) (as-contract tx-sender) (get target proposal))))
            
            ;; Mark proposal as executed
            (map-set proposals proposal-id (merge proposal {executed: true}))
            (ok true)
        )
    )
)

;; Read-only Functions

;; desc Get the token balance of an account
;; param account: The principal to check
;; returns (ok uint) with the balance
(define-read-only (get-balance (account principal))
    (ok (default-to u0 (map-get? balances account)))
)
