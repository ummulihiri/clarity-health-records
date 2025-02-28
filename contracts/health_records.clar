;; Health Records Management Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-patient-only (err u101))
(define-constant err-provider-only (err u102))
(define-constant err-invalid-record (err u103))
(define-constant err-invalid-category (err u104))
(define-constant err-contract-paused (err u105))

;; Data Variables
(define-data-var contract-paused bool false)
(define-map Patients principal bool)
(define-map HealthcareProviders principal bool)
(define-map Records 
    {record-id: uint, patient: principal}
    {data-hash: (string-ascii 64),
     provider: principal,
     timestamp: uint,
     access-type: (string-ascii 10),
     category: (string-ascii 20),
     version: uint}
)
(define-map AccessGrants
    {patient: principal, provider: principal}
    {granted: bool, expiry: uint, emergency-access: bool}
)
(define-map AccessHistory
    {record-id: uint, accessor: principal}
    {timestamp: uint, access-type: (string-ascii 10)}
)

;; Data variables for record tracking
(define-data-var record-counter uint u0)

;; Administrative functions
(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (var-set contract-paused (not (var-get contract-paused)))
        (ok true)
    )
)

;; Helper functions
(define-private (is-valid-category (category (string-ascii 20)))
    (or
        (is-eq category "GENERAL")
        (is-eq category "EMERGENCY")
        (is-eq category "CHRONIC")
        (is-eq category "PREVENTIVE")
    )
)

(define-private (log-access (record-id uint) (access-type (string-ascii 10)))
    (map-set AccessHistory
        {record-id: record-id, accessor: tx-sender}
        {timestamp: block-height, access-type: access-type}
    )
)

;; Authorization checks
(define-private (is-patient (user principal))
    (default-to false (map-get? Patients user))
)

(define-private (is-provider (user principal))
    (default-to false (map-get? HealthcareProviders user))
)

(define-private (has-access (provider principal) (patient principal))
    (let ((grant (map-get? AccessGrants {patient: patient, provider: provider})))
        (and 
            (is-some grant)
            (or
                (get emergency-access (unwrap-panic grant))
                (and
                    (get granted (unwrap-panic grant))
                    (> (get expiry (unwrap-panic grant)) block-height)
                )
            )
        )
    )
)

;; Registration functions
(define-public (register-patient)
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (map-set Patients tx-sender true)
        (ok true)
    )
)

(define-public (register-provider)
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (map-set HealthcareProviders tx-sender true)
        (ok true)
    )
)

;; Access management
(define-public (grant-access (provider principal) (duration uint) (emergency bool))
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (is-patient tx-sender) err-patient-only)
        (map-set AccessGrants 
            {patient: tx-sender, provider: provider}
            {granted: true, expiry: (+ block-height duration), emergency-access: emergency}
        )
        (ok true)
    )
)

(define-public (revoke-access (provider principal))
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (is-patient tx-sender) err-patient-only)
        (map-set AccessGrants 
            {patient: tx-sender, provider: provider}
            {granted: false, expiry: u0, emergency-access: false}
        )
        (ok true)
    )
)

;; Record management
(define-public (add-record 
    (patient principal) 
    (data-hash (string-ascii 64)) 
    (access-type (string-ascii 10))
    (category (string-ascii 20)))
    (let 
        ((record-id (+ (var-get record-counter) u1))
         (existing-record (map-get? Records {record-id: record-id, patient: patient})))
        (begin
            (asserts! (not (var-get contract-paused)) err-contract-paused)
            (asserts! (and (is-provider tx-sender) (has-access tx-sender patient)) err-not-authorized)
            (asserts! (is-valid-category category) err-invalid-category)
            (map-set Records
                {record-id: record-id, patient: patient}
                {data-hash: data-hash,
                 provider: tx-sender,
                 timestamp: block-height,
                 access-type: access-type,
                 category: category,
                 version: (if (is-some existing-record)
                            (+ (get version (unwrap-panic existing-record)) u1)
                            u1)}
            )
            (var-set record-counter record-id)
            (ok record-id)
        )
    )
)

;; Read functions
(define-read-only (get-record (record-id uint) (patient principal))
    (begin
        (asserts! (or 
            (is-eq tx-sender patient)
            (has-access tx-sender patient)
        ) err-not-authorized)
        (log-access record-id "READ")
        (ok (map-get? Records {record-id: record-id, patient: patient}))
    )
)

(define-read-only (check-access (provider principal) (patient principal))
    (ok (has-access provider patient))
)

(define-read-only (get-access-history (record-id uint))
    (begin
        (asserts! (or
            (is-provider tx-sender)
            (is-patient tx-sender)
        ) err-not-authorized)
        (ok (map-get? AccessHistory {record-id: record-id, accessor: tx-sender}))
    )
)
