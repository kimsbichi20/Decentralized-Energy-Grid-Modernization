;; Utility Verification Contract
;; Validates and manages energy providers in the decentralized grid

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_UTILITY_NOT_FOUND (err u101))
(define-constant ERR_UTILITY_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Utility status types
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Data structures
(define-map utilities
  { utility-id: uint }
  {
    name: (string-ascii 100),
    operator: principal,
    capacity-mw: uint,
    location: (string-ascii 50),
    energy-type: (string-ascii 20),
    status: uint,
    verified-at: uint,
    verifier: principal
  }
)

(define-map utility-operators
  { operator: principal }
  { utility-id: uint }
)

(define-data-var next-utility-id uint u1)

;; Events
(define-data-var utility-registered-event
  {utility-id: uint, operator: principal, name: (string-ascii 100)}
  {utility-id: u0, operator: tx-sender, name: ""})

;; Register new utility
(define-public (register-utility
  (name (string-ascii 100))
  (capacity-mw uint)
  (location (string-ascii 50))
  (energy-type (string-ascii 20)))
  (let ((utility-id (var-get next-utility-id)))
    (asserts! (is-none (map-get? utility-operators {operator: tx-sender})) ERR_UTILITY_ALREADY_EXISTS)
    (map-set utilities
      {utility-id: utility-id}
      {
        name: name,
        operator: tx-sender,
        capacity-mw: capacity-mw,
        location: location,
        energy-type: energy-type,
        status: STATUS_PENDING,
        verified-at: u0,
        verifier: CONTRACT_OWNER
      })
    (map-set utility-operators {operator: tx-sender} {utility-id: utility-id})
    (var-set next-utility-id (+ utility-id u1))
    (ok utility-id)))

;; Verify utility (admin only)
(define-public (verify-utility (utility-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? utilities {utility-id: utility-id})
      utility-data
      (begin
        (map-set utilities
          {utility-id: utility-id}
          (merge utility-data {
            status: STATUS_VERIFIED,
            verified-at: block-height,
            verifier: tx-sender
          }))
        (ok true))
      ERR_UTILITY_NOT_FOUND)))

;; Update utility status
(define-public (update-utility-status (utility-id uint) (new-status uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-status STATUS_REVOKED) ERR_INVALID_STATUS)
    (match (map-get? utilities {utility-id: utility-id})
      utility-data
      (begin
        (map-set utilities
          {utility-id: utility-id}
          (merge utility-data {status: new-status}))
        (ok true))
      ERR_UTILITY_NOT_FOUND)))

;; Read-only functions
(define-read-only (get-utility (utility-id uint))
  (map-get? utilities {utility-id: utility-id}))

(define-read-only (get-utility-by-operator (operator principal))
  (match (map-get? utility-operators {operator: operator})
    operator-data
    (map-get? utilities {utility-id: (get utility-id operator-data)})
    none))

(define-read-only (is-utility-verified (utility-id uint))
  (match (map-get? utilities {utility-id: utility-id})
    utility-data
    (is-eq (get status utility-data) STATUS_VERIFIED)
    false))

(define-read-only (get-next-utility-id)
  (var-get next-utility-id))
