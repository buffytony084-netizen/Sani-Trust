;; Sani-Trust: Health Insurance with Liquidity Pool
;; NOTE: This demo focuses on protocol logic and shares accounting.
;; In production, you'd transfer STX or SIP-010 tokens for deposits/claims.

(define-data-var owner (optional principal) none)

(define-data-var total-liquidity uint u0)
(define-data-var total-shares uint u0)

;; Liquidity providers by principal
(define-map lps principal {shares: uint, deposited: uint})

;; Policies keyed by holder principal
(define-map policies principal {premium: uint, coverage: uint, active: bool, paid: uint})

;; Claims keyed by incremental id
(define-data-var next-claim-id uint u0)
(define-map claims uint {holder: principal, amount: uint, approved: bool})

;; Errors
(define-constant err-owner-set u100)
(define-constant err-unauthorized u101)
(define-constant err-zero-amount u200)
(define-constant err-no-position u201)
(define-constant err-not-enough-shares u202)
(define-constant err-policy-exists u300)
(define-constant err-no-policy u301)
(define-constant err-inactive-policy u302)
(define-constant err-claim-exists u400)
(define-constant err-no-claim u401)
(define-constant err-claim-approved u402)
(define-constant err-insufficient-liquidity u500)

(define-read-only (get-owner)
  (ok (var-get owner))
)

(define-public (set-owner)
  (begin
    (if (is-none (var-get owner))
        (begin (var-set owner (some tx-sender)) (ok true))
        (err err-owner-set)
    )
  )
)

(define-private (assert-owner)
  (match (var-get owner)
    owner-opt (if (is-some owner-opt)
                   (if (is-eq tx-sender (unwrap owner-opt (err err-unauthorized))) (ok true) (err err-unauthorized))
                   (err err-unauthorized))
  )
)

(define-read-only (get-totals)
  (ok {total-liquidity: (var-get total-liquidity), total-shares: (var-get total-shares)})
)

(define-read-only (get-lp (who principal))
  (ok (map-get? lps who))
)

(define-read-only (get-policy (who principal))
  (ok (map-get? policies who))
)

(define-read-only (get-claim (id uint))
  (ok (map-get? claims id))
)

(define-public (deposit-liquidity (amount uint))
  (begin
    (if (is-eq amount u0) (err err-zero-amount)
      (let (
        (tl (var-get total-liquidity))
        (ts (var-get total-shares))
        (new-shares (if (is-eq ts u0) amount (u/ (u* amount ts) (if (is-eq tl u0) u1 tl))))
        (prev (default-to {shares: u0, deposited: u0} (map-get? lps tx-sender)))
      )
        (begin
          (var-set total-liquidity (u+ tl amount))
          (var-set total-shares (u+ ts new-shares))
          (map-set lps tx-sender {shares: (u+ (get shares prev) new-shares), deposited: (u+ (get deposited prev) amount)})
          (ok new-shares)
        )
      )
    )
  )
)

(define-public (withdraw-liquidity (shares uint))
  (let (
    (ts (var-get total-shares))
    (tl (var-get total-liquidity))
    (pos-opt (map-get? lps tx-sender))
  )
    (begin
      (if (is-eq shares u0) (err err-zero-amount)
        (match pos-opt pos
          (if (> shares (get shares pos)) (err err-not-enough-shares)
            (let (
              (amount (if (is-eq ts u0) u0 (u/ (u* shares tl) ts)))
              (rem-shares (u- (get shares pos) shares))
              (rem-deposited (if (> (get deposited pos) amount) (u- (get deposited pos) amount) u0))
            )
              (begin
                (if (> amount tl) (err err-insufficient-liquidity)
                  (begin
                    (var-set total-liquidity (u- tl amount))
                    (var-set total-shares (u- ts shares))
                    (map-set lps tx-sender {shares: rem-shares, deposited: rem-deposited})
                    (ok amount)
                  )
                )
              )
            )
          )
          (err err-no-position)
        )
      )
    )
  )
)

(define-public (create-policy (premium uint) (coverage uint))
  (let ((p (map-get? policies tx-sender)))
    (match p _ (err err-policy-exists)
      (begin
        (map-set policies tx-sender {premium: premium, coverage: coverage, active: false, paid: u0})
        (ok true)
      )
    )
  )
)

(define-public (pay-premium (amount uint))
  (match (map-get? policies tx-sender) pol
    (let ((new-paid (u+ (get paid pol) amount))
          (should-activate (>= (u+ (get paid pol) amount) (get premium pol))))
      (begin
        (map-set policies tx-sender {premium: (get premium pol), coverage: (get coverage pol), active: (or (get active pol) should-activate), paid: new-paid})
        (var-set total-liquidity (u+ (var-get total-liquidity) amount))
        (ok new-paid)
      )
    )
    (err err-no-policy)
  )
)

(define-public (file-claim (amount uint))
  (match (map-get? policies tx-sender) pol
    (if (and (get active pol) (> (get coverage pol) u0))
      (let ((id (var-get next-claim-id)))
        (begin
          (map-set claims id {holder: tx-sender, amount: amount, approved: false})
          (var-set next-claim-id (u+ id u1))
          (ok id)
        )
      )
      (err err-inactive-policy)
    )
    (err err-no-policy)
  )
)

(define-public (approve-claim (id uint) (amount uint))
  (begin
    (unwrap! (assert-owner) err-unauthorized)
    (match (map-get? claims id) cl
      (if (get approved cl) (err err-claim-approved)
        (if (> amount (var-get total-liquidity)) (err err-insufficient-liquidity)
          (begin
            (var-set total-liquidity (u- (var-get total-liquidity) amount))
            (map-set claims id {holder: (get holder cl), amount: (get amount cl), approved: true})
            (ok true)
          )
        )
      )
      (err err-no-claim)
    )
  )
)
