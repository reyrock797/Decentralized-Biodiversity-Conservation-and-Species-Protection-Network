;; Ecosystem Service Valuation Contract
;; Quantifies and compensates for nature's economic contributions

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-INPUT (err u501))
(define-constant ERR-SERVICE-EXISTS (err u502))
(define-constant ERR-SERVICE-NOT-FOUND (err u503))
(define-constant ERR-INSUFFICIENT-FUNDS (err u504))

;; Data Variables
(define-data-var next-service-id uint u1)
(define-data-var next-payment-id uint u1)
(define-data-var total-ecosystem-services uint u0)
(define-data-var total-payments-made uint u0)
(define-data-var total-value-tracked uint u0)

;; Data Maps
(define-map ecosystem-services uint {
    service-name: (string-ascii 100),
    service-type: (string-ascii 50),
    location: (string-ascii 200),
    area-km2: uint,
    annual-value-usd: uint,
    carbon-sequestration-tons: uint,
    water-purification-liters: uint,
    biodiversity-index: uint,
    soil-protection-hectares: uint,
    provider: principal,
    verification-date: uint,
    status: (string-ascii 20)
})

(define-map payment-programs uint {
    service-id: uint,
    payment-type: (string-ascii 50),
    annual-payment: uint,
    contract-duration-years: uint,
    total-paid: uint,
    performance-metrics: (list 5 uint),
    beneficiary: principal,
    start-date: uint,
    status: (string-ascii 20)
})

(define-map service-measurements uint {
    service-id: uint,
    measurement-date: uint,
    carbon-captured: uint,
    water-filtered: uint,
    species-count: uint,
    soil-quality-score: uint,
    measurer: principal
})

(define-map carbon-credits uint {
    service-id: uint,
    credits-generated: uint,
    credits-sold: uint,
    price-per-credit: uint,
    buyer: (optional principal),
    verification-standard: (string-ascii 50),
    issuance-date: uint
})

(define-map authorized-valuers principal bool)
(define-map service-providers principal bool)
(define-map carbon-verifiers principal bool)

;; Service Management Functions
(define-public (register-ecosystem-service (service-name (string-ascii 100)) (service-type (string-ascii 50)) (location (string-ascii 200)) (area-km2 uint) (annual-value uint) (carbon-sequestration uint) (water-purification uint) (biodiversity-index uint) (soil-protection uint))
    (let ((service-id (var-get next-service-id)))
        (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (default-to false (map-get? service-providers tx-sender))) ERR-NOT-AUTHORIZED)
        (asserts! (> (len service-name) u0) ERR-INVALID-INPUT)
        (asserts! (> area-km2 u0) ERR-INVALID-INPUT)
        (asserts! (> annual-value u0) ERR-INVALID-INPUT)
        (asserts! (<= biodiversity-index u100) ERR-INVALID-INPUT)

        (map-set ecosystem-services service-id {
            service-name: service-name,
            service-type: service-type,
            location: location,
            area-km2: area-km2,
            annual-value-usd: annual-value,
            carbon-sequestration-tons: carbon-sequestration,
            water-purification-liters: water-purification,
            biodiversity-index: biodiversity-index,
            soil-protection-hectares: soil-protection,
            provider: tx-sender,
            verification-date: block-height,
            status: "registered"
        })

        (var-set next-service-id (+ service-id u1))
        (var-set total-ecosystem-services (+ (var-get total-ecosystem-services) u1))
        (var-set total-value-tracked (+ (var-get total-value-tracked) annual-value))

        (print {event: "ecosystem-service-registered", service-id: service-id, service-name: service-name, annual-value: annual-value, area: area-km2})
        (ok service-id)
    )
)

(define-public (create-payment-program (service-id uint) (payment-type (string-ascii 50)) (annual-payment uint) (contract-duration uint) (performance-metrics (list 5 uint)))
    (let (
        (payment-id (var-get next-payment-id))
        (service (unwrap! (map-get? ecosystem-services service-id) ERR-SERVICE-NOT-FOUND))
    )
        (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (default-to false (map-get? authorized-valuers tx-sender))) ERR-NOT-AUTHORIZED)
        (asserts! (> (len payment-type) u0) ERR-INVALID-INPUT)
        (asserts! (> annual-payment u0) ERR-INVALID-INPUT)
        (asserts! (> contract-duration u0) ERR-INVALID-INPUT)

        (map-set payment-programs payment-id {
            service-id: service-id,
            payment-type: payment-type,
            annual-payment: annual-payment,
            contract-duration-years: contract-duration,
            total-paid: u0,
            performance-metrics: performance-metrics,
            beneficiary: (get provider service),
            start-date: block-height,
            status: "active"
        })

        (var-set next-payment-id (+ payment-id u1))
        (var-set total-payments-made (+ (var-get total-payments-made) u1))

        (print {event: "payment-program-created", payment-id: payment-id, service-id: service-id, annual-payment: annual-payment, duration: contract-duration})
        (ok payment-id)
    )
)

(define-public (record-service-measurement (service-id uint) (carbon-captured uint) (water-filtered uint) (species-count uint) (soil-quality-score uint))
    (let (
        (service (unwrap! (map-get? ecosystem-services service-id) ERR-SERVICE-NOT-FOUND))
        (measurement-key (+ (* service-id u1000) block-height))
    )
        (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (default-to false (map-get? authorized-valuers tx-sender))) ERR-NOT-AUTHORIZED)
        (asserts! (<= soil-quality-score u100) ERR-INVALID-INPUT)

        (map-set service-measurements measurement-key {
            service-id: service-id,
            measurement-date: block-height,
            carbon-captured: carbon-captured,
            water-filtered: water-filtered,
            species-count: species-count,
            soil-quality-score: soil-quality-score,
            measurer: tx-sender
        })

        (print {event: "service-measurement-recorded", service-id: service-id, carbon-captured: carbon-captured, water-filtered: water-filtered, species-count: species-count})
        (ok true)
    )
)

(define-public (issue-carbon-credits (service-id uint) (credits-generated uint) (price-per-credit uint) (verification-standard (string-ascii 50)))
    (let (
        (service (unwrap! (map-get? ecosystem-services service-id) ERR-SERVICE-NOT-FOUND))
        (credit-key (+ (* service-id u1000) block-height))
    )
        (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (default-to false (map-get? carbon-verifiers tx-sender))) ERR-NOT-AUTHORIZED)
        (asserts! (> credits-generated u0) ERR-INVALID-INPUT)
        (asserts! (> price-per-credit u0) ERR-INVALID-INPUT)
        (asserts! (> (len verification-standard) u0) ERR-INVALID-INPUT)

        (map-set carbon-credits credit-key {
            service-id: service-id,
            credits-generated: credits-generated,
            credits-sold: u0,
            price-per-credit: price-per-credit,
            buyer: none,
            verification-standard: verification-standard,
            issuance-date: block-height
        })

        (print {event: "carbon-credits-issued", service-id: service-id, credits: credits-generated, price-per-credit: price-per-credit, standard: verification-standard})
        (ok true)
    )
)

(define-public (authorize-valuer (valuer principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (map-set authorized-valuers valuer true)
        (print {event: "valuer-authorized", valuer: valuer})
        (ok true)
    )
)

(define-public (authorize-service-provider (provider principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (map-set service-providers provider true)
        (print {event: "service-provider-authorized", provider: provider})
        (ok true)
    )
)

(define-public (authorize-carbon-verifier (verifier principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (map-set carbon-verifiers verifier true)
        (print {event: "carbon-verifier-authorized", verifier: verifier})
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-ecosystem-service (service-id uint))
    (map-get? ecosystem-services service-id)
)

(define-read-only (get-payment-program (payment-id uint))
    (map-get? payment-programs payment-id)
)

(define-read-only (get-service-measurement (service-id uint) (measurement-date uint))
    (let ((measurement-key (+ (* service-id u1000) measurement-date)))
        (map-get? service-measurements measurement-key)
    )
)

(define-read-only (get-carbon-credits (service-id uint) (issuance-date uint))
    (let ((credit-key (+ (* service-id u1000) issuance-date)))
        (map-get? carbon-credits credit-key)
    )
)

(define-read-only (get-total-ecosystem-services)
    (var-get total-ecosystem-services)
)

(define-read-only (get-total-payments-made)
    (var-get total-payments-made)
)

(define-read-only (get-total-value-tracked)
    (var-get total-value-tracked)
)

(define-read-only (is-authorized-valuer (valuer principal))
    (default-to false (map-get? authorized-valuers valuer))
)

(define-read-only (is-service-provider (provider principal))
    (default-to false (map-get? service-providers provider))
)

(define-read-only (is-carbon-verifier (verifier principal))
    (default-to false (map-get? carbon-verifiers verifier))
)

(define-read-only (calculate-service-roi (service-id uint))
    (match (map-get? ecosystem-services service-id)
        service (some {
            service-id: service-id,
            annual-value: (get annual-value-usd service),
            value-per-km2: (/ (get annual-value-usd service) (get area-km2 service)),
            carbon-value-per-ton: (if (> (get carbon-sequestration-tons service) u0)
                (/ (get annual-value-usd service) (get carbon-sequestration-tons service))
                u0
            ),
            biodiversity-efficiency: (* (get biodiversity-index service) (get area-km2 service))
        })
        none
    )
)
