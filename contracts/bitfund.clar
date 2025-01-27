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
