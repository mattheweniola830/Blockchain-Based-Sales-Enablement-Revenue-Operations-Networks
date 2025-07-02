;; Sales Process Management Smart Contract
;; Manages sales processes and deal pipeline

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_INVALID_STAGE (err u202))
(define-constant ERR_INVALID_INPUT (err u203))

;; Data Variables
(define-data-var contract-active bool true)
(define-data-var total-processes uint u0)
(define-data-var total-deals uint u0)

;; Data Maps
(define-map sales-processes
  { process-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    stages: (list 10 (string-ascii 30)),
    created-by: uint,
    created-at: uint,
    active: bool
  }
)

(define-map deals
  { deal-id: uint }
  {
    process-id: uint,
    client-name: (string-ascii 50),
    value: uint,
    current-stage: uint,
    probability: uint,
    assigned-to: uint,
    created-at: uint,
    updated-at: uint,
    closed: bool
  }
)

(define-map deal-history
  { deal-id: uint, sequence: uint }
  {
    stage: uint,
    timestamp: uint,
    notes: (string-ascii 200),
    updated-by: uint
  }
)

;; Public Functions

;; Create a new sales process
(define-public (create-process
  (name (string-ascii 50))
  (description (string-ascii 200))
  (stages (list 10 (string-ascii 30)))
  (manager-id uint)
)
  (let
    (
      (new-id (+ (var-get total-processes) u1))
    )
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_INPUT)
    (asserts! (> (len stages) u0) ERR_INVALID_INPUT)

    (map-set sales-processes
      { process-id: new-id }
      {
        name: name,
        description: description,
        stages: stages,
        created-by: manager-id,
        created-at: block-height,
        active: true
      }
    )

    (var-set total-processes new-id)
    (ok new-id)
  )
)

;; Create a new deal
(define-public (create-deal
  (process-id uint)
  (client-name (string-ascii 50))
  (value uint)
  (assigned-to uint)
  (manager-id uint)
)
  (let
    (
      (new-id (+ (var-get total-deals) u1))
    )
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? sales-processes { process-id: process-id })) ERR_NOT_FOUND)
    (asserts! (> (len client-name) u0) ERR_INVALID_INPUT)
    (asserts! (> value u0) ERR_INVALID_INPUT)

    (map-set deals
      { deal-id: new-id }
      {
        process-id: process-id,
        client-name: client-name,
        value: value,
        current-stage: u0,
        probability: u10,
        assigned-to: assigned-to,
        created-at: block-height,
        updated-at: block-height,
        closed: false
      }
    )

    ;; Record initial stage
    (map-set deal-history
      { deal-id: new-id, sequence: u0 }
      {
        stage: u0,
        timestamp: block-height,
        notes: "Deal created",
        updated-by: manager-id
      }
    )

    (var-set total-deals new-id)
    (ok new-id)
  )
)

;; Advance deal to next stage
(define-public (advance-deal-stage
  (deal-id uint)
  (new-stage uint)
  (probability uint)
  (notes (string-ascii 200))
  (manager-id uint)
)
  (let
    (
      (deal-data (unwrap! (map-get? deals { deal-id: deal-id }) ERR_NOT_FOUND))
      (current-stage (get current-stage deal-data))
      (next-sequence (+ current-stage u1))
    )
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (not (get closed deal-data)) ERR_INVALID_STAGE)
    (asserts! (<= probability u100) ERR_INVALID_INPUT)

    (map-set deals
      { deal-id: deal-id }
      (merge deal-data {
        current-stage: new-stage,
        probability: probability,
        updated-at: block-height
      })
    )

    ;; Record stage change
    (map-set deal-history
      { deal-id: deal-id, sequence: next-sequence }
      {
        stage: new-stage,
        timestamp: block-height,
        notes: notes,
        updated-by: manager-id
      }
    )

    (ok true)
  )
)

;; Close deal (won/lost)
(define-public (close-deal
  (deal-id uint)
  (won bool)
  (notes (string-ascii 200))
  (manager-id uint)
)
  (let
    (
      (deal-data (unwrap! (map-get? deals { deal-id: deal-id }) ERR_NOT_FOUND))
      (final-probability (if won u100 u0))
      (current-stage (get current-stage deal-data))
      (next-sequence (+ current-stage u1))
    )
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (not (get closed deal-data)) ERR_INVALID_STAGE)

    (map-set deals
      { deal-id: deal-id }
      (merge deal-data {
        probability: final-probability,
        updated-at: block-height,
        closed: true
      })
    )

    ;; Record deal closure
    (map-set deal-history
      { deal-id: deal-id, sequence: next-sequence }
      {
        stage: (if won u999 u998), ;; Special stage codes for won/lost
        timestamp: block-height,
        notes: notes,
        updated-by: manager-id
      }
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get process details
(define-read-only (get-process (process-id uint))
  (map-get? sales-processes { process-id: process-id })
)

;; Get deal details
(define-read-only (get-deal (deal-id uint))
  (map-get? deals { deal-id: deal-id })
)

;; Get deal history entry
(define-read-only (get-deal-history (deal-id uint) (sequence uint))
  (map-get? deal-history { deal-id: deal-id, sequence: sequence })
)

;; Calculate pipeline value for a process
(define-read-only (get-pipeline-value (process-id uint))
  ;; This would require iteration over deals - simplified for demo
  u0
)

;; Get total processes
(define-read-only (get-total-processes)
  (var-get total-processes)
)

;; Get total deals
(define-read-only (get-total-deals)
  (var-get total-deals)
)

;; Admin Functions
(define-public (toggle-contract-status)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-active (not (var-get contract-active)))
    (ok (var-get contract-active))
  )
)
