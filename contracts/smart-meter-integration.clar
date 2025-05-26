;; Smart Meter Integration Contract
;; Manages advanced metering infrastructure and data collection

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_METER_NOT_FOUND (err u301))
(define-constant ERR_METER_ALREADY_EXISTS (err u302))
(define-constant ERR_INVALID_READING (err u303))

;; Meter types
(define-constant METER_TYPE_RESIDENTIAL u0)
(define-constant METER_TYPE_COMMERCIAL u1)
(define-constant METER_TYPE_INDUSTRIAL u2)

;; Data structures
(define-map smart-meters
  { meter-id: (string-ascii 50) }
  {
    owner: principal,
    meter-type: uint,
    location: (string-ascii 100),
    installation-date: uint,
    last-reading: uint,
    total-consumption: uint,
    is-active: bool,
    utility-provider: uint
  }
)

(define-map meter-readings
  { meter-id: (string-ascii 50), timestamp: uint }
  {
    energy-consumed: uint,
    energy-produced: uint,
    peak-demand: uint,
    power-factor: uint,
    recorded-by: principal
  }
)

(define-map daily-consumption
  { meter-id: (string-ascii 50), date: uint }
  {
    total-consumed: uint,
    total-produced: uint,
    peak-demand: uint,
    reading-count: uint
  }
)

(define-data-var total-meters-installed uint u0)
(define-data-var total-energy-consumed uint u0)
(define-data-var total-energy-produced uint u0)

;; Install new smart meter
(define-public (install-meter
  (meter-id (string-ascii 50))
  (meter-type uint)
  (location (string-ascii 100))
  (utility-provider uint))
  (begin
    (asserts! (is-none (map-get? smart-meters {meter-id: meter-id})) ERR_METER_ALREADY_EXISTS)
    (map-set smart-meters
      {meter-id: meter-id}
      {
        owner: tx-sender,
        meter-type: meter-type,
        location: location,
        installation-date: block-height,
        last-reading: u0,
        total-consumption: u0,
        is-active: true,
        utility-provider: utility-provider
      })
    (var-set total-meters-installed (+ (var-get total-meters-installed) u1))
    (ok true)))

;; Record meter reading
(define-public (record-reading
  (meter-id (string-ascii 50))
  (energy-consumed uint)
  (energy-produced uint)
  (peak-demand uint)
  (power-factor uint))
  (let ((timestamp block-height)
        (date (/ block-height u144))) ;; Approximate daily blocks
    (match (map-get? smart-meters {meter-id: meter-id})
      meter-data
      (begin
        (asserts! (or (is-eq tx-sender (get owner meter-data))
                     (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
        (asserts! (get is-active meter-data) ERR_METER_NOT_FOUND)

        ;; Record the reading
        (map-set meter-readings
          {meter-id: meter-id, timestamp: timestamp}
          {
            energy-consumed: energy-consumed,
            energy-produced: energy-produced,
            peak-demand: peak-demand,
            power-factor: power-factor,
            recorded-by: tx-sender
          })

        ;; Update meter totals
        (map-set smart-meters
          {meter-id: meter-id}
          (merge meter-data {
            last-reading: timestamp,
            total-consumption: (+ (get total-consumption meter-data) energy-consumed)
          }))

        ;; Update daily aggregates
        (match (map-get? daily-consumption {meter-id: meter-id, date: date})
          daily-data
          (map-set daily-consumption
            {meter-id: meter-id, date: date}
            {
              total-consumed: (+ (get total-consumed daily-data) energy-consumed),
              total-produced: (+ (get total-produced daily-data) energy-produced),
              peak-demand: (if (> peak-demand (get peak-demand daily-data))
                             peak-demand (get peak-demand daily-data)),
              reading-count: (+ (get reading-count daily-data) u1)
            })
          (map-set daily-consumption
            {meter-id: meter-id, date: date}
            {
              total-consumed: energy-consumed,
              total-produced: energy-produced,
              peak-demand: peak-demand,
              reading-count: u1
            }))

        ;; Update global totals
        (var-set total-energy-consumed
          (+ (var-get total-energy-consumed) energy-consumed))
        (var-set total-energy-produced
          (+ (var-get total-energy-produced) energy-produced))

        (ok true))
      ERR_METER_NOT_FOUND)))

;; Deactivate meter
(define-public (deactivate-meter (meter-id (string-ascii 50)))
  (match (map-get? smart-meters {meter-id: meter-id})
    meter-data
    (begin
      (asserts! (or (is-eq tx-sender (get owner meter-data))
                   (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
      (map-set smart-meters
        {meter-id: meter-id}
        (merge meter-data {is-active: false}))
      (ok true))
    ERR_METER_NOT_FOUND))

;; Read-only functions
(define-read-only (get-meter (meter-id (string-ascii 50)))
  (map-get? smart-meters {meter-id: meter-id}))

(define-read-only (get-reading (meter-id (string-ascii 50)) (timestamp uint))
  (map-get? meter-readings {meter-id: meter-id, timestamp: timestamp}))

(define-read-only (get-daily-consumption (meter-id (string-ascii 50)) (date uint))
  (map-get? daily-consumption {meter-id: meter-id, date: date}))

(define-read-only (get-total-meters)
  (var-get total-meters-installed))

(define-read-only (get-total-energy-consumed)
  (var-get total-energy-consumed))

(define-read-only (get-total-energy-produced)
  (var-get total-energy-produced))

(define-read-only (get-net-energy-balance)
  (- (var-get total-energy-produced) (var-get total-energy-consumed)))
