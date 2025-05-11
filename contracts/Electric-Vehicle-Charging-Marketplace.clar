;; Electric Vehicle Charging Marketplace
;; A decentralized marketplace for EV charging stations on the Stacks blockchain

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-STATION-ALREADY-EXISTS u101)
(define-constant ERR-STATION-NOT-FOUND u102)
(define-constant ERR-STATION-NOT-AVAILABLE u103)
(define-constant ERR-INVALID-PRICING u104)
(define-constant ERR-RESERVATION-NOT-FOUND u105)
(define-constant ERR-INVALID-RESERVATION u106)
(define-constant ERR-SESSION-ALREADY-ACTIVE u107)
(define-constant ERR-SESSION-NOT-FOUND u108)
(define-constant ERR-INSUFFICIENT-FUNDS u109)
(define-constant ERR-NOT-STATION-OWNER u110)
(define-constant ERR-RATING-OUT-OF-RANGE u111)
(define-constant ERR-ALREADY-RATED u112)
(define-constant ERR-INVALID-FEE u113)

;; Principal Variables
(define-data-var contract-admin principal tx-sender)
(define-data-var platform-fee-percentage uint u5) ;; Default 5%

;; Data Maps

;; Charging Station Data Map
(define-map charging-stations
  uint ;; station-id
  {
    owner: principal,
    location-lat: int,
    location-lng: int,
    price-per-kwh: uint,
    available: bool,
    connector-type: (string-ascii 20),
    power-output: uint, ;; in kW
    total-ratings: uint,
    sum-ratings: uint
  }
)

;; Reservations Data Map
(define-map reservations
  uint ;; reservation-id
  {
    station-id: uint,
    user: principal,
    start-time: uint, ;; Unix timestamp
    duration: uint,   ;; Duration in minutes
    status: (string-ascii 20) ;; "pending", "active", "completed", "cancelled"
  }
)

;; Charging Sessions Data Map
(define-map charging-sessions
  uint ;; session-id
  {
    reservation-id: uint,
    station-id: uint,
    user: principal,
    start-time: uint,
    end-time: uint,
    energy-used: uint, ;; in kWh * 100 for precision (eg. 10.5 kWh = 1050)
    total-cost: uint,
    completed: bool
  }
)

;; User Ratings Data Map
(define-map user-ratings
  {station-id: uint, user: principal}
  uint ;; rating (1-5)
)

;; Counters for IDs
(define-data-var next-station-id uint u1)
(define-data-var next-reservation-id uint u1)
(define-data-var next-session-id uint u1)

;; Admin Functions

;; Set contract administrator
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set contract-admin new-admin))
  )
)

;; Set platform fee percentage
(define-public (set-platform-fee (fee-percentage uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR-NOT-AUTHORIZED))
    (asserts! (< fee-percentage u100) (err ERR-INVALID-FEE))
    (ok (var-set platform-fee-percentage fee-percentage))
  )
)

;; Station Owner Functions

;; Register a new charging station
(define-public (register-charging-station
                (location-lat int)
                (location-lng int)
                (price-per-kwh uint)
                (connector-type (string-ascii 20))
                (power-output uint))
  (let ((station-id (var-get next-station-id)))
    (asserts! (> price-per-kwh u0) (err ERR-INVALID-PRICING))
    (map-insert charging-stations station-id
      {
        owner: tx-sender,
        location-lat: location-lat,
        location-lng: location-lng,
        price-per-kwh: price-per-kwh,
        available: true,
        connector-type: connector-type,
        power-output: power-output,
        total-ratings: u0,
        sum-ratings: u0
      }
    )
    (var-set next-station-id (+ station-id u1))
    (ok station-id)
  )
)

;; Update station availability
(define-public (update-station-availability (station-id uint) (available bool))
  (let ((station (unwrap! (map-get? charging-stations station-id) (err ERR-STATION-NOT-FOUND))))
    (asserts! (is-eq tx-sender (get owner station)) (err ERR-NOT-STATION-OWNER))
    (map-set charging-stations station-id
      (merge station {available: available})
    )
    (ok true)
  )
)

;; Update station pricing
(define-public (update-station-pricing (station-id uint) (price-per-kwh uint))
  (let ((station (unwrap! (map-get? charging-stations station-id) (err ERR-STATION-NOT-FOUND))))
    (asserts! (is-eq tx-sender (get owner station)) (err ERR-NOT-STATION-OWNER))
    (asserts! (> price-per-kwh u0) (err ERR-INVALID-PRICING))
    (map-set charging-stations station-id
      (merge station {price-per-kwh: price-per-kwh})
    )
    (ok true)
  )
)

;; EV Owner Functions

;; Make a reservation for a charging station
(define-public (make-reservation (station-id uint) (start-time uint) (duration uint))
  (let (
    (station (unwrap! (map-get? charging-stations station-id) (err ERR-STATION-NOT-FOUND)))
    (reservation-id (var-get next-reservation-id))
  )
    (asserts! (get available station) (err ERR-STATION-NOT-AVAILABLE))
    (asserts! (> duration u0) (err ERR-INVALID-RESERVATION))
    
    ;; Create reservation
    (map-insert reservations reservation-id
      {
        station-id: station-id,
        user: tx-sender,
        start-time: start-time,
        duration: duration,
        status: "pending"
      }
    )
    
    (var-set next-reservation-id (+ reservation-id u1))
    (ok reservation-id)
  )
)

;; Start a charging session
(define-public (start-charging-session (reservation-id uint))
  (let (
    (reservation (unwrap! (map-get? reservations reservation-id) (err ERR-RESERVATION-NOT-FOUND)))
    (station-id (get station-id reservation))
    (station (unwrap! (map-get? charging-stations station-id) (err ERR-STATION-NOT-FOUND)))
    (session-id (var-get next-session-id))
    (current-time (get-current-time))
  )
    (asserts! (is-eq tx-sender (get user reservation)) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-eq (get status reservation) "pending") (err ERR-INVALID-RESERVATION))
    (asserts! (get available station) (err ERR-STATION-NOT-AVAILABLE))
    
    ;; Update reservation status
    (map-set reservations reservation-id
      (merge reservation {status: "active"})
    )
    
    ;; Mark station as unavailable
    (map-set charging-stations station-id
      (merge station {available: false})
    )
    
    ;; Create charging session
    (map-insert charging-sessions session-id
      {
        reservation-id: reservation-id,
        station-id: station-id,
        user: tx-sender,
        start-time: current-time,
        end-time: u0,
        energy-used: u0,
        total-cost: u0,
        completed: false
      }
    )
    
    (var-set next-session-id (+ session-id u1))
    (ok session-id)
  )
)

;; Complete a charging session
(define-public (complete-charging-session (session-id uint) (energy-used uint))
  (let (
    (session (unwrap! (map-get? charging-sessions session-id) (err ERR-SESSION-NOT-FOUND)))
    (station-id (get station-id session))
    (station (unwrap! (map-get? charging-stations station-id) (err ERR-STATION-NOT-FOUND)))
    (reservation-id (get reservation-id session))
    (reservation (unwrap! (map-get? reservations reservation-id) (err ERR-RESERVATION-NOT-FOUND)))
    (current-time (get-current-time))
    (price-per-kwh (get price-per-kwh station))
    (platform-fee (var-get platform-fee-percentage))
    (station-owner (get owner station))
    (raw-cost (* energy-used price-per-kwh))
    (platform-fee-amount (/ (* raw-cost platform-fee) u100))
    (station-owner-amount (- raw-cost platform-fee-amount))
  )
    ;; Check authorization - either station owner or user can complete
    (asserts! (or (is-eq tx-sender (get user session)) (is-eq tx-sender station-owner)) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (get completed session)) (err ERR-INVALID-RESERVATION))
    
    ;; Calculate payment
    (unwrap! (stx-transfer? raw-cost tx-sender (var-get contract-admin)) (err ERR-INSUFFICIENT-FUNDS))
    (unwrap! (stx-transfer? station-owner-amount (var-get contract-admin) station-owner) (err u0))
    
    ;; Update session data
    (map-set charging-sessions session-id
      (merge session {
        end-time: current-time,
        energy-used: energy-used,
        total-cost: raw-cost,
        completed: true
      })
    )
    
    ;; Update reservation status
    (map-set reservations reservation-id
      (merge reservation {status: "completed"})
    )
    
    ;; Mark station as available again
    (map-set charging-stations station-id
      (merge station {available: true})
    )
    
    (ok true)
  )
)

;; Rate a charging station
(define-public (rate-charging-station (station-id uint) (rating uint))
  (let (
    (station (unwrap! (map-get? charging-stations station-id) (err ERR-STATION-NOT-FOUND)))
    (rating-key {station-id: station-id, user: tx-sender})
    (current-rating (map-get? user-ratings rating-key))
    (total-ratings (get total-ratings station))
    (sum-ratings (get sum-ratings station))
  )
    ;; Check rating is between 1-5
    (asserts! (and (>= rating u1) (<= rating u5)) (err ERR-RATING-OUT-OF-RANGE))
    (asserts! (is-none current-rating) (err ERR-ALREADY-RATED))
    
    ;; Add the new rating
    (map-set user-ratings rating-key rating)
    
    ;; Update station rating data
    (map-set charging-stations station-id
      (merge station {
        total-ratings: (+ total-ratings u1),
        sum-ratings: (+ sum-ratings rating)
      })
    )
    
    (ok true)
  )
)

;; Read-Only Functions

;; Get details of a charging station
(define-read-only (get-charging-station (station-id uint))
  (map-get? charging-stations station-id)
)

;; Get details of a reservation
(define-read-only (get-reservation (reservation-id uint))
  (map-get? reservations reservation-id)
)

;; Get a user's rating for a station
(define-read-only (get-user-rating (station-id uint) (user principal))
  (map-get? user-ratings {station-id: station-id, user: user})
)

;; Get the average rating for a station
(define-read-only (get-station-average-rating (station-id uint))
  (let (
    (station (unwrap! (map-get? charging-stations station-id) (none)))
    (total-ratings (get total-ratings station))
    (sum-ratings (get sum-ratings station))
  )
    (if (is-eq total-ratings u0)
      none
      (some (/ sum-ratings total-ratings))
    )
  )
)

;; Get the current platform fee percentage
(define-read-only (get-platform-fee)
  (var-get platform-fee-percentage)
)

;; Helper function to get current time (using a workaround since block-height is not available)
(define-read-only (get-current-time)
  ;; In a production contract, you would need a mechanism to get the current time
  ;; For now we'll use tx-sender as a source of entropy to simulate time
  ;; In real implementation, consider using oracles or other timestamp sources
  (len (unwrap-panic (as-max-len? (principal->string tx-sender) u100)))
)