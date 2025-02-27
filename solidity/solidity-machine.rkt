#lang racket

(require "../machine.rkt" "../special.rkt")

(provide solidity-machine%  (all-defined-out))
;;;;;;;;;;;;;;;;;;;;; program state macro ;;;;;;;;;;;;;;;;;;;;;;;;
;; This is just for convenience.
(define-syntax-rule
  (progstate regs memory cost contract storage sink balance summary)
  (vector regs memory cost contract storage sink balance summary))

(define-syntax-rule (progstate-regs x) (vector-ref x 0))
(define-syntax-rule (progstate-memory x) (vector-ref x 1))
(define-syntax-rule (progstate-cost x) (vector-ref x 2))
(define-syntax-rule (progstate-contract x) (vector-ref x 3))
(define-syntax-rule (progstate-storage x) (vector-ref x 4))
(define-syntax-rule (progstate-sink x) (vector-ref x 5))
(define-syntax-rule (progstate-balance x) (vector-ref x 6))
(define-syntax-rule (progstate-summary x) (vector-ref x 7))

(define-syntax-rule (set-progstate-regs! x v) (vector-set! x 0 v))
(define-syntax-rule (set-progstate-memory! x v) (vector-set! x 1 v))
(define-syntax-rule (set-progstate-cost! x v) (vector-set! x 2 v))
(define-syntax-rule (set-progstate-contract! x v) (vector-set! x 3 v))
(define-syntax-rule (set-progstate-storage! x v) (vector-set! x 4 v))
(define-syntax-rule (set-progstate-sink! x v) (vector-set! x 5 v))
(define-syntax-rule (set-progstate-balance! x v) (vector-set! x 6 v))
(define-syntax-rule (set-progstate-summary! x v) (vector-set! x 7 v))


(define contract-out-str `(
                      "GAS"
                      "ADDRESS"
                      "TIMESTAMP"
                      "NUMBER"
                      "CODESIZE"
                      "GASPRICE"
                      "GASLIMIT"
                      "DIFFICULTY"
                      "COINBASE"))

(define solidity-machine%
  (class machine%
    (super-new)
    (inherit-field bitwidth random-input-bits config)
    (inherit init-machine-description define-instruction-class finalize-machine-description
             define-progstate-type define-arg-type
             ; update-progstate-ins kill-outs
             )
    (override get-constructor progstate-structure display-state)

    (define (get-constructor) solidity-machine%)

    (unless bitwidth (set! bitwidth 32))
    (set! random-input-bits bitwidth)

    ;;;;;;;;;;;;;;;;;;;;; program state ;;;;;;;;;;;;;;;;;;;;;;;;
    (define (progstate-structure)
      ; ? ;; modify this function to define program state

      ;; Example:
      ;; Program state has registers and memory.
      ;; config = number of registers in this example.
      (progstate (for/vector ([i config]) 'reg)
                 (get-memory-type)
                 `cost  ; gas consumption
                 (for/vector ([i (length contract-out-str)]) 'contract)
                 ;; (for/vector ([i 40]) 'storage)
                 (list)
                 (for/vector ([i 10]) 'sink)
                 (list)
                 (list)
                 ))

    ;; Pretty print progstate.
    (define (display-state s)
      (pretty-display "REGS:")
      (pretty-display (progstate-regs s))
      ; (pretty-display (filter (lambda (arg) (> (string-length (~v arg)) 6)) (vector->list (progstate-regs s))))
      (pretty-display "MEMORY:")
      (pretty-display (progstate-memory s))
      (pretty-display `("Contract: ", (progstate-contract s)))
      (pretty-display (format "Gas-cost: ~a" (progstate-cost s)))
      (pretty-display "Storage:")
      (pretty-display (progstate-storage s))
      (pretty-display `("Sink: ", (progstate-sink s)))
      )

    (define-progstate-type
      'reg 
      #:get (lambda (state arg) (vector-ref (progstate-regs state) arg))
      #:set (lambda (state arg val) (vector-set! (progstate-regs state) arg val)))


    ; Contract and transaction-related data structures.
    ; 0: CALLVALUE
    (define-progstate-type
      'contract 
      #:get (lambda (state arg) (vector-ref (progstate-contract state) arg))
      #:set (lambda (state arg val) (vector-set! (progstate-contract state) arg val)))

    (define-progstate-type
      (get-memory-type)
      #:get (lambda (state) (progstate-memory state))
      #:set (lambda (state val) (set-progstate-memory! state val)))

    ;; (define-progstate-type
    ;;   'storage
    ;;   #:get (lambda (state arg) (table-ref (progstate-storage state) arg))
    ;;   #:set (lambda (state arg val) (table-set (progstate-storage state) arg val)))

    ;; (define-progstate-type
    ;;   'storage
    ;;   #:get (lambda (state arg) (table-ref (progstate-balance state) arg))
    ;;   #:set (lambda (state arg val) (table-set (progstate-balance state) arg val)))

    ;; Gas consumption.
    (define-progstate-type 'cost
      #:get (lambda (state) (progstate-cost state))
      #:set (lambda (state val) (set-progstate-cost! state val))
      #:const 0
      )
    (define-progstate-type
      'sink
      #:get (lambda (state arg) (vector-ref (progstate-sink state) arg))
      #:set (lambda (state arg val) (vector-set! (progstate-sink state) arg val)))


    ;; Inform GreenThumb how many opcodes there are in one instruction. 
    (init-machine-description 1)
    

    (finalize-machine-description)

    ))
      

