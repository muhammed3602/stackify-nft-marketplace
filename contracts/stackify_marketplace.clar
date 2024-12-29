;; Stackify NFT Marketplace Core Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-offer-not-found (err u104))

;; Data vars
(define-data-var marketplace-fee uint u250) ;; 2.5% fee (basis points)
(define-data-var marketplace-treasury principal contract-owner)

;; Data maps
(define-map listings
    { nft-contract: principal, token-id: uint }
    { seller: principal, price: uint, listed-at: uint }
)

(define-map offers 
    { nft-contract: principal, token-id: uint, buyer: principal }
    { amount: uint, created-at: uint }
)

;; Private functions
(define-private (transfer-nft (nft-contract principal) (token-id uint) (from principal) (to principal))
    (contract-call? nft-contract transfer token-id from to)
)

(define-private (calculate-fee (amount uint))
    (/ (* amount (var-get marketplace-fee)) u10000)
)

;; Public functions
(define-public (set-marketplace-fee (new-fee uint))
    (if (is-eq tx-sender contract-owner)
        (ok (var-set marketplace-fee new-fee))
        err-owner-only
    )
)

(define-public (list-nft (nft-contract principal) (token-id uint) (price uint))
    (let (
        (listing-data { seller: tx-sender, price: price, listed-at: block-height })
    )
    (asserts! (> price u0) err-invalid-price)
    (try! (transfer-nft nft-contract token-id tx-sender (as-contract tx-sender)))
    (ok (map-set listings { nft-contract: nft-contract, token-id: token-id } listing-data))
    )
)

(define-public (make-offer (nft-contract principal) (token-id uint))
    (let (
        (listing (unwrap! (map-get? listings { nft-contract: nft-contract, token-id: token-id }) err-listing-not-found))
        (offer-data { amount: (stx-get-balance tx-sender), created-at: block-height })
    )
    (ok (map-set offers { nft-contract: nft-contract, token-id: token-id, buyer: tx-sender } offer-data))
    )
)

(define-public (accept-offer (nft-contract principal) (token-id uint) (buyer principal))
    (let (
        (listing (unwrap! (map-get? listings { nft-contract: nft-contract, token-id: token-id }) err-listing-not-found))
        (offer (unwrap! (map-get? offers { nft-contract: nft-contract, token-id: token-id, buyer: buyer }) err-offer-not-found))
        (fee (calculate-fee (get amount offer)))
        (payment (- (get amount offer) fee))
    )
    (asserts! (is-eq tx-sender (get seller listing)) err-not-authorized)
    
    ;; Process payment
    (try! (stx-transfer? payment buyer (get seller listing)))
    (try! (stx-transfer? fee buyer (var-get marketplace-treasury)))
    
    ;; Transfer NFT
    (try! (transfer-nft nft-contract token-id (as-contract tx-sender) buyer))
    
    ;; Clear listing and offer
    (map-delete listings { nft-contract: nft-contract, token-id: token-id })
    (map-delete offers { nft-contract: nft-contract, token-id: token-id, buyer: buyer })
    
    (ok true)
    )
)

(define-public (cancel-listing (nft-contract principal) (token-id uint))
    (let (
        (listing (unwrap! (map-get? listings { nft-contract: nft-contract, token-id: token-id }) err-listing-not-found))
    )
    (asserts! (is-eq tx-sender (get seller listing)) err-not-authorized)
    (try! (transfer-nft nft-contract token-id (as-contract tx-sender) tx-sender))
    (ok (map-delete listings { nft-contract: nft-contract, token-id: token-id }))
    )
)

;; Read-only functions
(define-read-only (get-listing (nft-contract principal) (token-id uint))
    (map-get? listings { nft-contract: nft-contract, token-id: token-id })
)

(define-read-only (get-offer (nft-contract principal) (token-id uint) (buyer principal))
    (map-get? offers { nft-contract: nft-contract, token-id: token-id, buyer: buyer })
)