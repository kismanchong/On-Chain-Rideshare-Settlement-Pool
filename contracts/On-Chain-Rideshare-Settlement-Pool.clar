(define-constant CONTRACT_OWNER tx-sender)
(define-constant PLATFORM_FEE u300)
(define-constant MIN_DISPUTE_DEPOSIT u1000000)
(define-constant DISPUTE_RESOLUTION_BLOCKS u144)

(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_DRIVER_NOT_FOUND (err u1002))
(define-constant ERR_INSUFFICIENT_FUNDS (err u1003))
(define-constant ERR_POOL_NOT_FOUND (err u1004))
(define-constant ERR_DISPUTE_ACTIVE (err u1005))
(define-constant ERR_DISPUTE_NOT_FOUND (err u1006))
(define-constant ERR_INVALID_AMOUNT (err u1007))
(define-constant ERR_ALREADY_EXISTS (err u1008))

(define-data-var total-pools uint u0)
(define-data-var platform-fee-balance uint u0)

(define-map drivers principal {
  total-earned: uint,
  rides-completed: uint,
  is-active: bool
})

(define-map settlement-pools uint {
  total-amount: uint,
  remaining-amount: uint,
  driver-count: uint,
  created-at: uint,
  is-active: bool,
  has-dispute: bool
})

(define-map pool-drivers {pool-id: uint, driver: principal} {
  amount-earned: uint,
  rides-count: uint,
  claimed: bool
})

(define-map disputes uint {
  pool-id: uint,
  disputer: principal,
  deposit: uint,
  created-at: uint,
  resolved: bool,
  resolution: (optional bool)
})

(define-public (register-driver)
  (let ((existing-driver (map-get? drivers tx-sender)))
    (if (is-some existing-driver)
      ERR_ALREADY_EXISTS
      (ok (map-set drivers tx-sender {
        total-earned: u0,
        rides-completed: u0,
        is-active: true
      })))))

(define-public (create-settlement-pool (initial-amount uint))
  (if (> initial-amount u0)
    (let ((pool-id (+ (var-get total-pools) u1))
          (platform-fee (/ (* initial-amount PLATFORM_FEE) u10000)))
      (try! (stx-transfer? initial-amount tx-sender (as-contract tx-sender)))
      (map-set settlement-pools pool-id {
        total-amount: (- initial-amount platform-fee),
        remaining-amount: (- initial-amount platform-fee),
        driver-count: u0,
        created-at: stacks-block-height,
        is-active: true,
        has-dispute: false
      })
      (var-set total-pools pool-id)
      (var-set platform-fee-balance (+ (var-get platform-fee-balance) platform-fee))
      (ok pool-id))
    ERR_INVALID_AMOUNT))

(define-public (add-driver-to-pool (pool-id uint) (driver principal) (rides-count uint))
  (let ((pool (unwrap! (map-get? settlement-pools pool-id) ERR_POOL_NOT_FOUND))
        (driver-data (unwrap! (map-get? drivers driver) ERR_DRIVER_NOT_FOUND)))
    (if (and (get is-active pool) (not (get has-dispute pool)))
      (begin
        (map-set pool-drivers {pool-id: pool-id, driver: driver} {
          amount-earned: u0,
          rides-count: rides-count,
          claimed: false
        })
        (map-set settlement-pools pool-id 
          (merge pool {driver-count: (+ (get driver-count pool) u1)}))
        (ok true))
      ERR_DISPUTE_ACTIVE)))

(define-public (calculate-driver-share (pool-id uint) (driver principal))
  (let ((pool (unwrap! (map-get? settlement-pools pool-id) ERR_POOL_NOT_FOUND))
        (driver-pool-data (unwrap! (map-get? pool-drivers {pool-id: pool-id, driver: driver}) ERR_DRIVER_NOT_FOUND)))
    (if (> (get driver-count pool) u0)
      (let ((base-share (/ (get total-amount pool) (get driver-count pool)))
            (rides-bonus (/ (* (get rides-count driver-pool-data) (get total-amount pool)) u1000)))
        (ok (+ base-share rides-bonus)))
      (ok u0))))

(define-public (claim-payment (pool-id uint))
  (let ((pool (unwrap! (map-get? settlement-pools pool-id) ERR_POOL_NOT_FOUND))
        (driver-pool-data (unwrap! (map-get? pool-drivers {pool-id: pool-id, driver: tx-sender}) ERR_DRIVER_NOT_FOUND))
        (driver-share (unwrap! (calculate-driver-share pool-id tx-sender) ERR_INVALID_AMOUNT)))
    (if (and (get is-active pool) 
             (not (get has-dispute pool))
             (not (get claimed driver-pool-data))
             (>= (get remaining-amount pool) driver-share))
      (begin
        (try! (as-contract (stx-transfer? driver-share tx-sender tx-sender)))
        (map-set pool-drivers {pool-id: pool-id, driver: tx-sender}
          (merge driver-pool-data {claimed: true, amount-earned: driver-share}))
        (map-set settlement-pools pool-id
          (merge pool {remaining-amount: (- (get remaining-amount pool) driver-share)}))
        (map-set drivers tx-sender
          (merge (unwrap! (map-get? drivers tx-sender) ERR_DRIVER_NOT_FOUND)
            {total-earned: (+ (get total-earned 
              (unwrap! (map-get? drivers tx-sender) ERR_DRIVER_NOT_FOUND)) driver-share),
             rides-completed: (+ (get rides-completed 
              (unwrap! (map-get? drivers tx-sender) ERR_DRIVER_NOT_FOUND)) 
              (get rides-count driver-pool-data))}))
        (ok driver-share))
      ERR_INSUFFICIENT_FUNDS)))

(define-public (raise-dispute (pool-id uint))
  (let ((pool (unwrap! (map-get? settlement-pools pool-id) ERR_POOL_NOT_FOUND)))
    (if (and (get is-active pool) (not (get has-dispute pool)))
      (begin
        (try! (stx-transfer? MIN_DISPUTE_DEPOSIT tx-sender (as-contract tx-sender)))
        (map-set disputes pool-id {
          pool-id: pool-id,
          disputer: tx-sender,
          deposit: MIN_DISPUTE_DEPOSIT,
          created-at: stacks-block-height,
          resolved: false,
          resolution: none
        })
        (map-set settlement-pools pool-id (merge pool {has-dispute: true}))
        (ok true))
      ERR_DISPUTE_ACTIVE)))

(define-public (resolve-dispute (pool-id uint) (favor-disputer bool))
  (let ((dispute (unwrap! (map-get? disputes pool-id) ERR_DISPUTE_NOT_FOUND))
        (pool (unwrap! (map-get? settlement-pools pool-id) ERR_POOL_NOT_FOUND)))
    (if (is-eq tx-sender CONTRACT_OWNER)
      (if (not (get resolved dispute))
        (begin
          (if favor-disputer
            (try! (as-contract (stx-transfer? (get deposit dispute) tx-sender (get disputer dispute))))
            (var-set platform-fee-balance (+ (var-get platform-fee-balance) (get deposit dispute))))
          (map-set disputes pool-id 
            (merge dispute {resolved: true, resolution: (some favor-disputer)}))
          (map-set settlement-pools pool-id (merge pool {has-dispute: false}))
          (ok favor-disputer))
        ERR_ALREADY_EXISTS)
      ERR_NOT_AUTHORIZED)))

(define-public (withdraw-platform-fees)
  (if (is-eq tx-sender CONTRACT_OWNER)
    (let ((fee-balance (var-get platform-fee-balance)))
      (if (> fee-balance u0)
        (begin
          (try! (as-contract (stx-transfer? fee-balance tx-sender CONTRACT_OWNER)))
          (var-set platform-fee-balance u0)
          (ok fee-balance))
        ERR_INSUFFICIENT_FUNDS))
    ERR_NOT_AUTHORIZED))

(define-public (deactivate-driver)
  (let ((driver-data (unwrap! (map-get? drivers tx-sender) ERR_DRIVER_NOT_FOUND)))
    (map-set drivers tx-sender (merge driver-data {is-active: false}))
    (ok true)))

(define-read-only (get-driver-info (driver principal))
  (map-get? drivers driver))

(define-read-only (get-pool-info (pool-id uint))
  (map-get? settlement-pools pool-id))

(define-read-only (get-driver-pool-info (pool-id uint) (driver principal))
  (map-get? pool-drivers {pool-id: pool-id, driver: driver}))

(define-read-only (get-dispute-info (pool-id uint))
  (map-get? disputes pool-id))

(define-read-only (get-platform-fee-balance)
  (var-get platform-fee-balance))

(define-read-only (get-total-pools)
  (var-get total-pools))
