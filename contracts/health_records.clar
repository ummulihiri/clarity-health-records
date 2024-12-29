;; Health Records Management Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-patient-only (err u101))
(define-constant err-provider-only (err u102))
(define-constant err-invalid-record (err u103))

;; Data Variables
(define-map Patients principal bool)
(define-map HealthcareProviders principal bool)
(define-map Records 
    {record-id: uint, patient: principal}
    {data-hash: (string-ascii 64),
     provider: principal,
     timestamp: uint,
     access-type: (string-ascii 10)}
)
(define-map AccessGrants
    {patient: principal, provider: principal}
    {granted: bool, expiry: uint}
)

;; Data variables for record tracking
(define-data-var record-counter uint u0)

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
            (get granted (unwrap-panic grant))
            (> (get expiry (unwrap-panic grant)) block-height)
        )
    )
)

;; Registration functions
(define-public (register-patient)
    (begin
        (map-set Patients tx-sender true)
        (ok true)
    )
)

(define-public (register-provider)
    (begin
        (map-set HealthcareProviders tx-sender true)
        (ok true)
    )
)

;; Access management
(define-public (grant-access (provider principal) (duration uint))
    (if (is-patient tx-sender)
        (begin
            (map-set AccessGrants 
                {patient: tx-sender, provider: provider}
                {granted: true, expiry: (+ block-height duration)}
            )
            (ok true)
        )
        err-patient-only
    )
)

(define-public (revoke-access (provider principal))
    (if (is-patient tx-sender)
        (begin
            (map-set AccessGrants 
                {patient: tx-sender, provider: provider}
                {granted: false, expiry: u0}
            )
            (ok true)
        )
        err-patient-only
    )
)

;; Record management
(define-public (add-record (patient principal) (data-hash (string-ascii 64)) (access-type (string-ascii 10)))
    (let ((record-id (+ (var-get record-counter) u1)))
        (if (and (is-provider tx-sender) (has-access tx-sender patient))
            (begin
                (map-set Records
                    {record-id: record-id, patient: patient}
                    {data-hash: data-hash,
                     provider: tx-sender,
                     timestamp: block-height,
                     access-type: access-type}
                )
                (var-set record-counter record-id)
                (ok record-id)
            )
            err-not-authorized
        )
    )
)

;; Read functions
(define-read-only (get-record (record-id uint) (patient principal))
    (if (or 
            (is-eq tx-sender patient)
            (has-access tx-sender patient)
        )
        (ok (map-get? Records {record-id: record-id, patient: patient}))
        err-not-authorized
    )
)

(define-read-only (check-access (provider principal) (patient principal))
    (ok (has-access provider patient))
)