;; Health Records Management Contract - Enhanced Version

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-patient-only (err u101))
(define-constant err-provider-only (err u102))
(define-constant err-invalid-record (err u103))
(define-constant err-invalid-category (err u104))
(define-constant err-contract-paused (err u105))
(define-constant err-invalid-batch (err u106))
(define-constant err-invalid-access-level (err u107))

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var record-counter uint u0)

;; Enhanced Data Maps
(define-map Patients principal 
  {
    registered: bool,
    delegate: (optional principal)
  }
)

(define-map HealthcareProviders principal 
  {
    registered: bool,
    access-level: uint,
    specialization: (string-ascii 20)
  }
)

(define-map Records 
    {record-id: uint, patient: principal}
    {
      data-hash: (string-ascii 64),
      provider: principal,
      timestamp: uint,
      access-type: (string-ascii 10),
      category: (string-ascii 20),
      version: uint,
      previous-version: (optional uint)
    }
)

(define-map AccessGrants
    {patient: principal, provider: principal}
    {
      granted: bool,
      expiry: uint,
      emergency-access: bool,
      access-level: uint,
      last-access: uint
    }
)

;; Enhanced helper functions
(define-private (validate-access-level (level uint))
    (and (>= level u1) (<= level u4))
)

(define-private (is-valid-batch-size (size uint))
    (and (> size u0) (<= size u10))
)

;; Enhanced registration functions
(define-public (register-provider-with-details (specialization (string-ascii 20)) (access-level uint))
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (validate-access-level access-level) err-invalid-access-level)
        (map-set HealthcareProviders tx-sender 
            {
                registered: true,
                access-level: access-level,
                specialization: specialization
            }
        )
        (ok true)
    )
)

;; Batch record operations
(define-public (add-batch-records 
    (patient principal)
    (data-hashes (list 10 (string-ascii 64)))
    (access-type (string-ascii 10))
    (category (string-ascii 20)))
    (let
        ((batch-size (len data-hashes)))
        (begin
            (asserts! (not (var-get contract-paused)) err-contract-paused)
            (asserts! (and (is-provider tx-sender) (has-access tx-sender patient)) err-not-authorized)
            (asserts! (is-valid-batch-size batch-size) err-invalid-batch)
            (asserts! (is-valid-category category) err-invalid-category)
            (ok (map add-single-record data-hashes))
        )
    )
)

;; Record version tracking
(define-read-only (get-record-history (record-id uint) (patient principal))
    (let ((current-record (unwrap! (map-get? Records {record-id: record-id, patient: patient}) err-invalid-record)))
        (ok {
            current-version: (get version current-record),
            previous-version: (get previous-version current-record),
            last-update: (get timestamp current-record)
        })
    )
)

;; [Previous functions remain unchanged...]
