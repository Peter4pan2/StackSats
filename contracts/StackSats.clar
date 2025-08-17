
;; title: BTC-Lending-Protocol
;; version: 1.0.0
;; summary: A lending protocol that allows borrowing Stacks assets against Bitcoin collateral
;; description: This protocol enables users to deposit Bitcoin as collateral and borrow STX and other Stacks assets

;; traits
;;

;; token definitions
;;

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-collateral (err u102))
(define-constant err-loan-not-found (err u103))
(define-constant err-already-liquidated (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-loan-not-expired (err u106))
(define-constant err-insufficient-balance (err u107))

;; Collateralization ratio (150% = 15000 basis points)
(define-constant min-collateral-ratio u15000)
(define-constant liquidation-ratio u12000)
(define-constant basis-points u10000)

;; Interest rate (5% annually = 500 basis points)
(define-constant annual-interest-rate u500)

;; data vars
(define-data-var next-loan-id uint u1)
(define-data-var total-btc-collateral uint u0)
(define-data-var total-stx-borrowed uint u0)

;; data maps
;; Map loan ID to loan details
(define-map loans
  uint
  {
    borrower: principal,
    btc-collateral: uint,
    stx-borrowed: uint,
    interest-accrued: uint,
    created-at: uint,
    last-update: uint,
    is-active: bool
  }
)

;; Map user to their loan IDs
(define-map user-loans principal (list 50 uint))

;; Map to track BTC collateral deposits (simplified - in production would use Bitcoin integration)
(define-map btc-deposits principal uint)

;; public functions

;; Deposit BTC collateral (simplified - would integrate with Bitcoin in production)
(define-public (deposit-btc-collateral (amount uint))
  (let
    (
      (current-balance (default-to u0 (map-get? btc-deposits tx-sender)))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (map-set btc-deposits tx-sender (+ current-balance amount))
    (var-set total-btc-collateral (+ (var-get total-btc-collateral) amount))
    (ok amount)
  )
)

;; Borrow STX against BTC collateral
(define-public (borrow-stx (stx-amount uint) (btc-collateral-amount uint))
  (let
    (
      (loan-id (var-get next-loan-id))
      (user-collateral (default-to u0 (map-get? btc-deposits tx-sender)))
      (collateral-value (* btc-collateral-amount u50000)) ;; Assuming 1 BTC = 50,000 STX
      (required-collateral (/ (* stx-amount min-collateral-ratio) basis-points))
      (current-loans (default-to (list) (map-get? user-loans tx-sender)))
    )
    (asserts! (> stx-amount u0) err-invalid-amount)
    (asserts! (>= user-collateral btc-collateral-amount) err-insufficient-balance)
    (asserts! (>= collateral-value required-collateral) err-insufficient-collateral)

    ;; Update user's BTC balance
    (map-set btc-deposits tx-sender (- user-collateral btc-collateral-amount))

    ;; Create loan record
    (map-set loans loan-id
      {
        borrower: tx-sender,
        btc-collateral: btc-collateral-amount,
        stx-borrowed: stx-amount,
        interest-accrued: u0,
        created-at: block-height,
        last-update: block-height,
        is-active: true
      }
    )

    ;; Update user loans list
    (map-set user-loans tx-sender (unwrap! (as-max-len? (append current-loans loan-id) u50) err-not-found))

    ;; Update global state
    (var-set next-loan-id (+ loan-id u1))
    (var-set total-stx-borrowed (+ (var-get total-stx-borrowed) stx-amount))

    ;; Transfer STX to borrower
    (stx-transfer? stx-amount (as-contract tx-sender) tx-sender)
  )
)

;; Repay loan
(define-public (repay-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) err-loan-not-found))
      (interest (calculate-interest loan-id))
      (total-repayment (+ (get stx-borrowed loan) interest))
    )
    (asserts! (get is-active loan) err-not-found)
    (asserts! (is-eq (get borrower loan) tx-sender) err-owner-only)

    ;; Transfer STX from borrower to contract
    (try! (stx-transfer? total-repayment tx-sender (as-contract tx-sender)))

    ;; Return BTC collateral to borrower
    (let
      (
        (current-balance (default-to u0 (map-get? btc-deposits tx-sender)))
      )
      (map-set btc-deposits tx-sender (+ current-balance (get btc-collateral loan)))
    )

    ;; Mark loan as inactive
    (map-set loans loan-id (merge loan { is-active: false }))

    ;; Update global state
    (var-set total-stx-borrowed (- (var-get total-stx-borrowed) (get stx-borrowed loan)))

    (ok total-repayment)
  )
)

;; Liquidate undercollateralized loan
(define-public (liquidate-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) err-loan-not-found))
      (interest (calculate-interest loan-id))
      (total-debt (+ (get stx-borrowed loan) interest))
      (collateral-value (* (get btc-collateral loan) u50000))
      (current-ratio (/ (* collateral-value basis-points) total-debt))
    )
    (asserts! (get is-active loan) err-already-liquidated)
    (asserts! (< current-ratio liquidation-ratio) err-insufficient-collateral)

    ;; Transfer liquidation penalty to liquidator (10% of collateral)
    (let
      (
        (liquidation-reward (/ (get btc-collateral loan) u10))
        (remaining-collateral (- (get btc-collateral loan) liquidation-reward))
        (liquidator-balance (default-to u0 (map-get? btc-deposits tx-sender)))
      )
      ;; Give liquidation reward to liquidator
      (map-set btc-deposits tx-sender (+ liquidator-balance liquidation-reward))

      ;; Return remaining collateral to borrower if any
      (if (> remaining-collateral u0)
        (let
          (
            (borrower-balance (default-to u0 (map-get? btc-deposits (get borrower loan))))
          )
          (map-set btc-deposits (get borrower loan) (+ borrower-balance remaining-collateral))
        )
        true
      )

      ;; Mark loan as inactive
      (map-set loans loan-id (merge loan { is-active: false }))

      ;; Update global state
      (var-set total-stx-borrowed (- (var-get total-stx-borrowed) (get stx-borrowed loan)))

      (ok liquidation-reward)
    )
  )
)

;; read only functions

;; Get loan details
(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)

;; Get user's BTC balance
(define-read-only (get-btc-balance (user principal))
  (default-to u0 (map-get? btc-deposits user))
)

;; Get user's loans
(define-read-only (get-user-loans (user principal))
  (default-to (list) (map-get? user-loans user))
)

;; Calculate current interest for a loan
(define-read-only (calculate-interest (loan-id uint))
  (match (map-get? loans loan-id)
    loan
    (let
      (
        (blocks-elapsed (- block-height (get last-update loan)))
        (principal-amount (get stx-borrowed loan))
        ;; Simplified interest calculation (blocks per year ~= 52,560)
        (interest (/ (* principal-amount annual-interest-rate blocks-elapsed) (* basis-points u52560)))
      )
      interest
    )
    u0
  )
)

;; Get loan health ratio
(define-read-only (get-loan-health (loan-id uint))
  (match (map-get? loans loan-id)
    loan
    (let
      (
        (interest (calculate-interest loan-id))
        (total-debt (+ (get stx-borrowed loan) interest))
        (collateral-value (* (get btc-collateral loan) u50000))
      )
      (if (> total-debt u0)
        (some (/ (* collateral-value basis-points) total-debt))
        none
      )
    )
    none
  )
)

;; Get protocol statistics
(define-read-only (get-protocol-stats)
  {
    total-btc-collateral: (var-get total-btc-collateral),
    total-stx-borrowed: (var-get total-stx-borrowed),
    next-loan-id: (var-get next-loan-id)
  }
)

;; private functions

;; Update loan interest
(define-private (update-loan-interest (loan-id uint))
  (match (map-get? loans loan-id)
    loan
    (let
      (
        (interest (calculate-interest loan-id))
        (updated-loan (merge loan 
          { 
            interest-accrued: (+ (get interest-accrued loan) interest),
            last-update: block-height
          }
        ))
      )
      (map-set loans loan-id updated-loan)
      (ok interest)
    )
    err-loan-not-found
  )
)

