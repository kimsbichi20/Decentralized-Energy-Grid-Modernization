;; Infrastructure Upgrade Contract
;; Tracks grid modernization projects and their progress

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_PROJECT_NOT_FOUND (err u201))
(define-constant ERR_INVALID_STATUS (err u202))
(define-constant ERR_INSUFFICIENT_FUNDS (err u203))

;; Project status types
(define-constant STATUS_PROPOSED u0)
(define-constant STATUS_APPROVED u1)
(define-constant STATUS_IN_PROGRESS u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_CANCELLED u4)

;; Data structures
(define-map infrastructure-projects
  { project-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    location: (string-ascii 50),
    estimated-cost: uint,
    actual-cost: uint,
    funding-allocated: uint,
    status: uint,
    contractor: principal,
    start-date: uint,
    completion-date: uint,
    created-by: principal,
    created-at: uint
  }
)

(define-map project-milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-ascii 200),
    target-date: uint,
    completion-date: uint,
    is-completed: bool
  }
)

(define-data-var next-project-id uint u1)
(define-data-var total-infrastructure-budget uint u0)

;; Create new infrastructure project
(define-public (create-project
  (title (string-ascii 100))
  (description (string-ascii 500))
  (location (string-ascii 50))
  (estimated-cost uint))
  (let ((project-id (var-get next-project-id)))
    (map-set infrastructure-projects
      {project-id: project-id}
      {
        title: title,
        description: description,
        location: location,
        estimated-cost: estimated-cost,
        actual-cost: u0,
        funding-allocated: u0,
        status: STATUS_PROPOSED,
        contractor: tx-sender,
        start-date: u0,
        completion-date: u0,
        created-by: tx-sender,
        created-at: block-height
      })
    (var-set next-project-id (+ project-id u1))
    (ok project-id)))

;; Approve project and allocate funding
(define-public (approve-project (project-id uint) (funding-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? infrastructure-projects {project-id: project-id})
      project-data
      (begin
        (map-set infrastructure-projects
          {project-id: project-id}
          (merge project-data {
            status: STATUS_APPROVED,
            funding-allocated: funding-amount,
            start-date: block-height
          }))
        (var-set total-infrastructure-budget
          (+ (var-get total-infrastructure-budget) funding-amount))
        (ok true))
      ERR_PROJECT_NOT_FOUND)))

;; Update project status
(define-public (update-project-status (project-id uint) (new-status uint))
  (begin
    (match (map-get? infrastructure-projects {project-id: project-id})
      project-data
      (begin
        (asserts! (or (is-eq tx-sender (get contractor project-data))
                     (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
        (asserts! (<= new-status STATUS_CANCELLED) ERR_INVALID_STATUS)
        (map-set infrastructure-projects
          {project-id: project-id}
          (merge project-data {
            status: new-status,
            completion-date: (if (is-eq new-status STATUS_COMPLETED) block-height u0)
          }))
        (ok true))
      ERR_PROJECT_NOT_FOUND)))

;; Add project milestone
(define-public (add-milestone
  (project-id uint)
  (milestone-id uint)
  (description (string-ascii 200))
  (target-date uint))
  (begin
    (match (map-get? infrastructure-projects {project-id: project-id})
      project-data
      (begin
        (asserts! (is-eq tx-sender (get contractor project-data)) ERR_UNAUTHORIZED)
        (map-set project-milestones
          {project-id: project-id, milestone-id: milestone-id}
          {
            description: description,
            target-date: target-date,
            completion-date: u0,
            is-completed: false
          })
        (ok true))
      ERR_PROJECT_NOT_FOUND)))

;; Complete milestone
(define-public (complete-milestone (project-id uint) (milestone-id uint))
  (begin
    (match (map-get? infrastructure-projects {project-id: project-id})
      project-data
      (begin
        (asserts! (is-eq tx-sender (get contractor project-data)) ERR_UNAUTHORIZED)
        (match (map-get? project-milestones {project-id: project-id, milestone-id: milestone-id})
          milestone-data
          (begin
            (map-set project-milestones
              {project-id: project-id, milestone-id: milestone-id}
              (merge milestone-data {
                completion-date: block-height,
                is-completed: true
              }))
            (ok true))
          ERR_PROJECT_NOT_FOUND))
      ERR_PROJECT_NOT_FOUND)))

;; Read-only functions
(define-read-only (get-project (project-id uint))
  (map-get? infrastructure-projects {project-id: project-id}))

(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? project-milestones {project-id: project-id, milestone-id: milestone-id}))

(define-read-only (get-total-budget)
  (var-get total-infrastructure-budget))

(define-read-only (get-next-project-id)
  (var-get next-project-id))
