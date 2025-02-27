#lang rosette
(require "../simulator-rosette.rkt" "../ops-rosette.rkt" "../utils.rkt"
         "../inst.rkt" "solidity-machine.rkt" graph rosette/lib/match rosette/lib/angelic)
(require (prefix-in unsafe- (only-in racket box set-box! unbox)))
(require racket/pretty)
(require debug/repl)
(require rosette/solver/smt/z3)
(require "../jsonlog.rkt")
(current-solver (z3 #:logic 'QF_UFBV))


(provide solidity-simulator-rosette%)


(define (string-contains s substr)
  (let loop ([i 0])
    (if (> i (- (string-length s) (string-length substr)))
        #f
        (if (string=? (substring s i (+ i (string-length substr))) substr)
            i
            (loop (add1 i))))))

(define (my-string-index s c)
  (let loop ([i 0])
    (if (>= i (string-length s))
        #f
        (if (char=? (string-ref s i) c)
            i
            (loop (add1 i))))))

(define (remove-leading-zeros s)
  (if (or (string=? s "") (not (char=? (string-ref s 0) #\0)))
      s
      (remove-leading-zeros (substring s 1))))

(define (shorten-bv-in-string s)
  (let loop ([s s])
    (let ([start (string-contains s "(bv #x")])
      (if (not start)
          s
          (let* ([index start]
                 [prefix (substring s 0 index)]
                 [rest (substring s index)]
                 [hex-start (string-length "(bv #x")]
                 [rest-hex (substring rest hex-start)]

                 [space-index (or (my-string-index rest-hex #\space)
                                  (string-length rest-hex))]
                 [hex-digits (substring rest-hex 0 space-index)]
                 [trimmed (remove-leading-zeros hex-digits)]
                 [short (string-append "0x" (if (string=? trimmed "") "0" trimmed))]

                 [after-index (or (my-string-index rest #\)) (string-length rest))]
                 [after (substring rest (add1 after-index))])
            (loop (string-append prefix short after)))))))


;;; (define-syntax-rule (progstate-regs x) (vector-ref x 0))
;;; (define-syntax-rule (progstate-memory x) (vector-ref x 1))
;;; (define-syntax-rule (progstate-cost x) (vector-ref x 2))
;;; (define-syntax-rule (progstate-contract x) (vector-ref x 3))
;;; (define-syntax-rule (progstate-storage x) (vector-ref x 4))
;;; (define-syntax-rule (progstate-sink x) (vector-ref x 5))
;;; (define-syntax-rule (progstate-balance x) (vector-ref x 6))
;;; (define-syntax-rule (progstate-summary x) (vector-ref x 7))

(define-syntax (ppstate stx)
  (syntax-case stx ()
    [(_ expr) (syntax/loc stx (begin (newline)
                                     (displayln `expr)
                                     (display `regs) (display ": ") (displayln (progstate-regs expr))
                                     (display `memory) (display ": ") (displayln (progstate-memory expr))
                                     (display `cost) (display ": ") (displayln (progstate-cost expr))
                                     (display `contract) (display ": ") (displayln (progstate-contract expr))
                                     (display `storage) (display ": ") (displayln (progstate-storage expr))
                                     (display `sink) (display ": ") (displayln (progstate-sink expr))
                                     (display `balance) (display ": ") (displayln (progstate-balance expr))
                                     (display `summary) (display ": ") (displayln (progstate-summary expr))
                                     (newline)))]))

;; extract a list of constants from (choose* 1 2 3)
(define (extract-const-from-expr t)
  (foldl (lambda (x acc)
           (if (expression? x)
               (append acc (extract-const-from-expr x))
               (if (bv? x)
                   (append acc (list x))
                   acc)))
         (list)
         (match t
           [(expression op child ...) child]
           [_                      (list t)])))

(define transfer-limit (bv 2300 256))

(define solidity-simulator-rosette%
  (class simulator-rosette%
    (super-new)
    (init-field machine)
    (override interpret performance-cost get-constructor)

    (define (get-constructor) solidity-simulator-rosette%)

    (define/public (get-full-state)
      (let ([env (current-namespace)])
        (for/hash ([sym (namespace-mapped-symbols env)]
                   #:when (regexp-match? #rx"^:" (symbol->string sym)))
          (values sym (eval sym env)))))



    (define verbose #t)
    (define BV? (bitvector 256))
    (define ONE? (bv 1 BV?))
    (define ZERO? (bv 0 BV?))
    (define (keccak256 s)
      (define cmd (format "cast keccak 0x~a" (bv->str s)))
      (str->bv (string-trim (with-output-to-string (lambda () (system cmd)))))
      )
    (define-symbolic blockhash-app (~> BV? BV?))
    ;;do not lift by Rosette.

    (define (get-store-var)
      (define-symbolic* store-var BV?)
      store-var)

    (define (get-callret-var)
      (define-symbolic* call-ret-var BV?)
      call-ret-var)

    (define (check-interfere src sink)
      ;; (pretty-display `("checking interfere:", src, sink))
      (define-symbolic s1 BV?)
      (define-symbolic s2 BV?)
      ;;substitution in Rosette.
      (define expr1 (evaluate sink (sat (hash src s1))))
      (define expr2 (evaluate sink (sat (hash src s2))))
      ;; (printf "e1=~a e2=~a" expr1 expr2)
      ;; (define formula (and (not (bveq s1 s2)) (bveq expr1 expr2)))
      ;; (unsat? (solve (assert formula)))
      ;; checking two exprs are identical. hacky.
      (expression? (equal? expr1 expr2)))

    ;;;;;;;;;;;;;;;;;;;;;;;;;;; Helper functions ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Truncate x to 'bit' bits and convert to signed number.
    ;; Always use this macro when interpreting an operator.
    ; (define-syntax-rule (finitize-bit x) (finitize x bit))
    ;; (define-syntax-rule (finitize-bit x) x)

    ;; (define-syntax-rule (bvuop op)
    ;;   (λ (x) (finitize-bit (op x))))
    ;; (define-syntax-rule (bvop op)
    ;; (λ (x y) (finitize-bit (op x y))))
    (define (iszero a) (if (bveq a ZERO?) ONE? ZERO?))
    ;; (define (snot a) (finitize-bit (not a)))
    (define (eq a) a)
    (define (vlt a b) (if (bvult a b) ONE? ZERO?))
    (define (vgt a b) (if (bvugt a b) ONE? ZERO?))
    (define (vslt a b) (if (bvslt a b) ONE? ZERO?))
    (define (vsgt a b) (if (bvsgt a b) ONE? ZERO?))

    (define (veqcmp a b) (if (bveq a b) ONE? ZERO?))


    ;; Binary operation.
    ;;Unary operation.
    (define self-parser #f)
    (define self-printer #f)
    (define atk? #f)
    (define self-addr->block (list))
    (define self-id->addr (list))
    (define self-addr->id (list))
    (define self-codebin #f)
    (define (get-keys assns) (map car assns))
    (define (get-values assns) (map cdr assns))
    ;;; from James
    (define MAX-DEPTH 1024) ;; maximum depth of the path we would explore.
    ;;Get an item from an associate list.
    (define (get-item list key)
      (match list
        [(list) null]
        ;; [(list) #f]
        [(list cur rest ...)
         (if (equal? (car cur) key) (cdr cur) (get-item rest key))
         ]))


    ;;Convert hashtable to assn-list for Rosette
    (define (hashtable-to-assnlist h-table)
      (foldl (λ (x result)
               (append result (list (cons x
                                          (hash-ref h-table x)))))
             `() (hash-keys h-table)))

    (define storage-out #f)

    (define G #f)
    (define P #f)
    ;;; (global-attr G)
    ;;; (set-global-attr! G val
    (define (custom-print expr)
      (let ([s (format "E[~a]" ((global-get-val-in-old-assms G) expr))])
        (shorten-bv-in-string s)))

    (define-syntax (pp stx)
      (syntax-case stx ()
        [(_ expr) (syntax/loc stx (begin (newline) (pretty-print-depth #f) (displayln `expr) (printf "~a" (custom-print expr)) (newline)))]))



    (define/public (init-analyzer cfg-file-loc parser-arg printer-arg cfg-json global-shared pvt atk? [ref #f])
      (set! self-parser parser-arg)
      (set! self-printer printer-arg)
      (set! G global-shared)
      (set! P pvt)
      (set! atk? atk?)
      (set! self-codebin (private-code P))
      (set! storage-out (private-storage-out P))
      (define addr-block-hash (make-hash))
      (define blocks-raw (hash-ref cfg-json 'blocks))

      (set! self-id->addr (map (λ (x y) (cons x (hash-ref y `address))) (range (length blocks-raw))
                               blocks-raw))


      (set! self-addr->id (map (λ (x y) (cons (hash-ref y `address) x)) (range (length blocks-raw))
                               blocks-raw))

      (for ([blk-json blocks-raw])
        (begin
          (let ([cur-blk (basic-block (get-item self-addr->id (hash-ref blk-json `address))
                                      (hash-ref blk-json `insts)
                                      (map (λ (x) (get-item self-addr->id x)) (hash-ref blk-json `succs))
                                      (hash-ref blk-json `empty_pops)
                                      (hash-ref blk-json `remaining_stack)
                                      )])
            (hash-set! addr-block-hash (basic-block-address cur-blk) cur-blk)))
        )

      (set! self-addr->block (hashtable-to-assnlist addr-block-hash))

      )
    (define/public (get-code) (code self-printer self-parser self-addr->block self-id->addr self-addr->id (send machine get-config) self-codebin))




    (define (table-ref tbl key)
      (tbl key))

    (define (table-set tbl key value)
      (lambda (k)
        (if (equal? k key)
            value
            (tbl k))))

    (define-symbolic create-app (~> BV? BV? BV? BV?))

    ;;A program is a list of method calls, represented by a list of root blockId
    (define/public (interpret-program state calldata callvalue caller origin delegatecode #:name-caller [name-caller #f])
      (set-progstate-storage! state storage-out); just for viewing, program-storage is not used in the simulator.
      (define printer self-printer)
      (define parser self-parser)
      (define addr->block self-addr->block)
      (define id->addr self-id->addr)
      (define addr->id self-addr->id)
      (define regs-out #f)
      (define maxreg #f)
      (define codebin self-codebin)
      (printf "selfmaxreg=~a\n" maxreg)
      (when (not delegatecode)
        (set! maxreg (send machine get-config))
        ;should use own counter
        (set! regs-out (build-vector maxreg (lambda (x) (gen-reg))))
        )
      ;;; (define regs-out (vector-copy (progstate-regs state)))
      (when delegatecode
        (set! printer (code-printer delegatecode))
        (set! parser (code-parser delegatecode))
        (set! addr->block (code-addr->block delegatecode))
        (set! id->addr (code-id->addr delegatecode))
        (set! addr->id (code-addr->id delegatecode))
        ;;; (set! maxreg (send (get-field machine (private-interpreter ((global-addr->P G) caller))) get-config))
        (set! maxreg (code-maxreg delegatecode))
        (set! codebin (code-bin delegatecode))
        (printf "delegatecode maxreg=~a\n" maxreg)
        (set! regs-out (build-vector maxreg (lambda (x) (gen-reg))))
        )
      (ppstate state)
      ;; Copy vector before modifying it because vector is mutable, and
      ;; we don't want to mutate the input state.
      (define success-return ONE?)
      (define return-val #f)
      (define RETURNDATASIZE ZERO?)
      (define RETURNDATA #f)
      (define stack-vars '()); this is a tricky implementation of vandal pop empty var. It record all remaining var and we get var from the stack when meet pop

      (define met-stop-cmd #f)
      (define met-revert-cmd #f)
      (define met-return-cmd #f)
      (define met-selfdestruct-cmd #f)
      (define (run-end) (|| met-stop-cmd met-revert-cmd met-return-cmd met-selfdestruct-cmd))

      (define (make-update-stack-func _translate-stack-vars _remaining-stack)
        (lambda ()
          (begin
            (printf "remaining_stack to be add ~a\n" _remaining-stack)
            (printf "before stack-vars:")
            (map printval stack-vars)
            (set! stack-vars
                  (foldr (lambda (x acc)
                           (append (list (_translate-stack-vars x)) acc ))
                         stack-vars
                         _remaining-stack))
            )
          (printf "\nafter stack-vars:")
          
          (map printval stack-vars)
          )
        )


      (define (printval val #:sig [sig "V"])
        (if (&& (concrete? val) (bv? val))
            (printf "~a " (custom-print val))
            (if (&& (concrete? val) (integer? val) )
                (if (&&(bv? (vector-ref regs-out val)) (concrete? (vector-ref regs-out val)))
                    (printf "~a~a=~a " sig val (custom-print(vector-ref regs-out val))) ;1. some will be S and mem
                    (printf "~a~a=~a " sig val (custom-print (vector-ref regs-out val)))
                    )
                ;;; (printf "~a " val)
                (printf "~a " (custom-print val)))))


      ; (pretty-display `("working on cfg:", root))
      ;; Set mem = #f for now.
      (define mem #f)



      ;; (set! block->count (foldl (lambda (x res) (append res (list (cons x 0)))) (list) (get-keys id->addr)))

      (define contract-out (vector-copy (progstate-contract state)))
      (pp contract-out)
      (define sink-out (vector-copy (progstate-sink state)))
      (vector-fill! sink-out #f)
      (define sink-idx (box 0))
      (define sink-pos (unbox sink-idx))
      (define cost (progstate-cost state))

      ;; Call this function when we want to reference mem. This function will clone the memory.
      ;; We do this instead of cloning memory at the begining
      ;; because we want to avoid creating new memory object when we can.
      (define (prepare-mem)
        ;; When referencing memory object, use send* instead of send to make it compatible with Rosette.
        (unless mem
          (set! mem (send* (progstate-memory state) clone))))
      ;;; (and ref (progstate-memory ref))

      (define (interpret-inst code parent-block bound update-stack-func translate-stack-vars)
        ;; (define successors (basic-block-succs parent-block))
        ;; (pretty-display `("interpret@@@@@@ inst----: ", inst-str))
        ;; (define pre-condition (foldl (lambda (x res) (and x res)) #t (asserts)))
        ;;; (printf "stack-vars:")
        ;;; (map printval stack-vars)
        (define my-inst (vector-ref (send printer encode code) 0))

        ;;; (when verbose
        ;;; (send printer print-syntax code))
        (define op-name #f)
        (for ([i code])(set! op-name (string->symbol (inst-op i))))
        (define op (inst-op my-inst))
        ;;; (define op-name (vector-ref opcodes op))
        (define args (inst-args my-inst))

        (define retrieve-var translate-stack-vars)

        (define op_args (inst-args (vector-ref code 0)))

        (define (get-arg-val idx) (retrieve-var (vector-ref op_args idx)))
        (define (print-inst)
          (printf "~a " op-name)
          ;;; (printf "op_args=~a\n" op_args)
          (for ([i (range 0 (vector-length args))])
            (define val (vector-ref args i))
            (define op_arg (vector-ref op_args i))
            ; if op_arg is composed of Snum, then extract val
            (if (&& (string-prefix? op_arg "S") (char-numeric? (string-ref op_arg 1)))
                (begin
                  (define v  (retrieve-var op_arg))
                  (printf "~a=~a " op_arg (custom-print v))
                  )

                (printval val)
                )
            )
          (printf "\n")
          )


        (define (concretize-val val)
          (if (concrete? val)
              val
              (begin
                (printf "Concretizing-val: val=~a\n" val)
                (when (sat? (solve (assert (not (equal? val ((global-get-val-in-old-assms G) val))))))
                  (printf "Warning: concretize-val: val=~a is not always true\n" val)
                  (assume (equal? val ((global-get-val-in-old-assms G) val)))
                  )
                ((global-get-val-in-old-assms G) val)
                ))
              )

        
        (define (rrr f)
          (define val (f (get-arg-val 2) (get-arg-val 3)))
          (vector-set! regs-out (vector-ref args 1) val))

        (define (rr f)
          (define val (f (get-arg-val 2)))
          (vector-set! regs-out (vector-ref args 1) val))

        (define (ri f)
          (define d (vector-ref args 1))
          (define b (vector-ref args 2))
          (define a
            (cond
              [(equal? b "RETURNDATASIZE") RETURNDATASIZE]
              [(equal? b "CALLVALUE") callvalue]
              [(equal? b "CALLER") (if delegatecode (begin (printf "delegatecode, name-caller=~a\n" name-caller) name-caller) caller)]
              [(equal? b "ORIGIN") origin]
              [(equal? b "MSIZE") (send* mem get-size)]
              [(equal? b "CALLDATASIZE") (bv (/(bv-length calldata) 8) 256)]
              [(string? b) (begin (printf "b=~a\n" b)
                            (vector-ref contract-out (index-of contract-out-str b)))]
              [else b]
              )
            )
          (define val (f a)) ;; reg const
          (vector-set! regs-out d val))

        (define (stop)
          (set! met-stop-cmd #t)
          (displayln "STOP"))

        (define (revert)
          (set! met-revert-cmd #t)
          (define a (get-arg-val 1))
          (define b (bitvector->natural (get-arg-val 2)))
          (set! success-return ZERO?)
          (set! return-val (send* mem load a #:n b))
          (displayln "Revert")
          (displayln "Revert value: ")
          (displayln return-val)
          )
        (define (return)
          (set! met-return-cmd #t)
          (define a (get-arg-val 1))
          (define b (bitvector->natural (get-arg-val 2)))

          (set! return-val (send* mem load a #:n b))
          (displayln "Return value: ")
          (displayln return-val)
          )

        (define (load)
          (displayln "load: ")
          (define op_args (inst-args (vector-ref code 0)))
          (define d (vector-ref args 1))
          (define a (concretize-val (get-arg-val 2)))
          (prepare-mem)
          ;; When referencing memory object, use send* instead of send to make it compatible with Rosette.
          (vector-set! regs-out d (send* mem load a)))

        (define (sload)
          (define op_args (inst-args (vector-ref code 0)))
          (define d (vector-ref args 1))
          (define a (concretize-val (get-arg-val 2)))
          (define val (table-ref storage-out a))
          (printf "sload d=~a a=~a val=~a\n" d a val)
          (vector-set! regs-out d val))

        (define (store)
          (define op_args (inst-args (vector-ref code 0)))
          (define addr (get-arg-val 1))
          (define val (concretize-val (get-arg-val 2)))
          (prepare-mem)
          (send* mem store addr val)
          (printf "M[~a]=~a \n" (custom-print addr) (custom-print val))

          )
        (define (store8)
          (define op_args (inst-args (vector-ref code 0)))
          (define addr (get-arg-val 1))
          (define val (concretize-val (get-arg-val 2)))
          (set! val (extract 63 0 val))
          (prepare-mem)
          (send* mem store addr val)
          (printf "M8[~a]=~a \n" (custom-print addr) (custom-print val))

          )

        (define (sstore)
          (define op_args (inst-args (vector-ref code 0)))
          (define addr (get-arg-val 1))
          (define val (concretize-val (get-arg-val 2)))
          (set! storage-out (table-set storage-out addr val))
          (printf "slot[~a]=~a \n" (custom-print addr) (custom-print val))
          )

        (define (vsha3 a b)
          (define datatobesha (send* mem load a #:n (bitvector->natural b)))
          (keccak256 datatobesha)
          )

        (define (byte i x)
          (zero-extend (srclenextract (* 8 (bitvector->natural i)) 8 x) BV?)
          )

        ;;; sign extends x from (b + 1) * 8 bits to 256 bits.
        (define (signextend b x)
          (sign-extend (extract (- (* (+ (bitvector->natural b) 1) 8) 1) 0 x) (bitvector 256))
          )


        ;; Jump to addr if cond holds.
        (define (jumpi)
          ; (pretty-print args)
          (define dest (send printer get-addr-id (get-arg-val 1)))
          (define dest-id (concretize-val (get-item addr->id dest)))
          (define cond-val (get-arg-val 2))

          (define blk-id (basic-block-address parent-block))
          ;;; (define pred (bveq cond-val ZERO?))
          ;;; (pp pred)
          ;;; (define neg-pred (not pred))


          (define vcbefore (vc-assumes (vc)))
          (printf "vcbefore: ~a\n" (custom-print vcbefore))
          (printf "cond-val: ~a\n" (custom-print cond-val))
          (define previous-cond-val ((global-get-val-in-old-assms G) cond-val))
          (printf "previous-cond-val: ~a\n" (custom-print previous-cond-val))

          (when (not atk?)
            (assume (equal? (bvzero? cond-val) (bvzero? previous-cond-val)))
            )
          (when atk?
            (printf "attack jump assume\n")
            )
          (define vcafter (vc-assumes (vc)))
          (printf "vcafter: ~a\n" (custom-print vcafter))
          (define curr-succs (basic-block-succs parent-block))
          (define neg-succ (first (filter (lambda (x) (equal? dest-id x)) curr-succs)))
          (define pos-succ (first (filter (lambda (x) (not (equal? dest-id x))) curr-succs)))
          ; to check both branches if use pred. Check only one branch if use previous-cond-val.
          (update-stack-func)
          (if (bveq previous-cond-val ZERO?)
              (interpret-block pos-succ (sub1 bound))
              (interpret-block neg-succ (sub1 bound)))
          )


        (define (jump)
          (define dest (send printer get-addr-id (get-arg-val 1)))
          (define dest-id (concretize-val (get-item addr->id dest)))
          (printf "succs=~a\n" (basic-block-succs parent-block))
          (printf "dest=~a\n" dest)
          (printf "dest-id=~a\n" dest-id)
          ;;; (define curr-one-succ (list-ref (basic-block-succs parent-block) 0)) ; only has one successor.
          (update-stack-func)
          (interpret-block dest-id (sub1 bound))
          )

        (define throw jump)

        (define (extcodesize)
          (define dest (vector-ref args 1))
          (define val (get-arg-val 2))
          (define extP ((global-addr->P G) val))
          (printf "extP=~a\n" extP)
          (define code (private-code extP))
          (unless code
            (printf "Warning: extcodesize: code=~a\n" code)
            )
          (if code
              (vector-set! regs-out dest (bv (bv-length code) 256))
              (vector-set! regs-out dest ZERO?))
          )

        (define (extcodecopy)
          (define val (concretize-val (get-arg-val 1)))
          (define extP ((global-addr->P G) val))
          (define a1 (get-arg-val 2))
          (define a2 (* 8 (bitvector->natural (concretize-val (get-arg-val 3)))))
          (define a3 (* 8 (bitvector->natural (concretize-val (get-arg-val 4)))))
          (define code-to-be-extracted (private-code extP))
          (define value #f)
          (if code-to-be-extracted
            (set! value (srclenextract a2 a3 code-to-be-extracted))
            (begin
              (printf "Warning: extcodesize: code-to-be-extracted=~a\n" code-to-be-extracted)
              (set! value (bv 0 a3))
              )
            )
          (send mem store a1 value)
          )

        (define (extcodehash)
          (define dest (vector-ref args 1))
          (define val (concretize-val (get-arg-val 2)))
          (define extP ((global-addr->P G) val))
          (define code (private-code extP))
          (if code
              (vector-set! regs-out dest (keccak256 code))
              (if ((global-accountexist? G) val)
                  (vector-set! regs-out dest (bv #xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 256))
                  (begin (printf "Warning Account not exist: extcodehash: account=~a does not exist\n" val) (vector-set! regs-out dest ZERO?) ))
              )
          ;TODO should be 0 if this address doesn't exist, but now just not implement that part.
          )


        (define (selfdestruct)
          (printf "ERROR: selfdestruct not implemented\n")
          (set! met-selfdestruct-cmd #t)
          ;;; (vector-set! sink-out sink-pos (get-arg-val 1))
          ;;; (set-box! sink-idx (add1 sink-pos))
          )

        (define (calldataload)
          (define a (vector-ref args 1))
          (define b (* 8 (bitvector->natural (concretize-val (get-arg-val 2)))))
          (define len (bv-length calldata))
          (define paded-calldata calldata)
          (if (> (+ b 256) len)
              (begin               
                (printf "calldataload: b+256 > len, concat calldata with many0\n")
                (printf "len=~a\n" len)
                (printf "(get-arg-val 2)=~a\n" (get-arg-val 2))
                
                (set! paded-calldata (concat calldata (bv 0 256)))
                )
              (void)
              )
          (define val (srclenextract b 256 paded-calldata))
          (vector-set! regs-out a val))

        (define (calldatacopy)
          (define a (concretize-val (get-arg-val 1)))
          (define b (* 8 (bitvector->natural (concretize-val (get-arg-val 2)))))
          (define c (* 8 (bitvector->natural (concretize-val (get-arg-val 3)))))
          (define val (srclenextract b c calldata))
          (printf "calldatacopy: a=~a b=~a c=~a val=~a\n" a b c val)
          (send* mem store a val))

        (define (create)
          (define dest (vector-ref args 1))
          (define value (vector-ref args 2))
          (define offset (get-arg-val 3))
          (define len (get-arg-val 4))
          (vector-set! regs-out dest (create-app value offset len))
          )

        (define (delegatecall)

          (printf "delegatecall\n")
          (define op_args (inst-args (vector-ref code 0)))
          (define dest (vector-ref args 1))
          (define gas (get-arg-val 2))
          (define addr (concretize-val (get-arg-val 3)))
          ;;; (define callvalue-call (get-arg-val 4)) // callvalue always 0 in delegatecall
          (define args-offset (concretize-val (get-arg-val 4)))
          (define args-len (bitvector->natural (concretize-val (get-arg-val 5))))
          (define ret-offset (concretize-val (get-arg-val 6)))
          (define ret-len (bitvector->natural (concretize-val (get-arg-val 7))))
          (define calldata-call (send mem load args-offset #:n args-len))
          (define-values (success-return-call ret-val-call) ((global-call G)
                                                             addr
                                                             calldata-call
                                                             callvalue
                                                             (vector-ref contract-out (index-of contract-out-str "ADDRESS"))
                                                             origin
                                                             #t
                                                             #:name-caller
                                                             caller))
          (pp ret-val-call)
          (set! RETURNDATASIZE (bv (/ (bv-length ret-val-call) 8) 256))
          (set! RETURNDATA ret-val-call)
          ;;; (when (> (bv-length ret-val-call) (* 8 ret-len))
          ;;;   (printf "ret-len not match, truncate ret-val-call\n")
          ;;;   (printf "bv-length ret-val-call=~a\n" (bv-length ret-val-call))
          ;;;   (printf "ret-len (8*)=~a\n" (* 8 ret-len))
          ;;;   (set! ret-val-call (srclenextract 0 (* 8 ret-len) ret-val-call))
          ;;;   (pp ret-val-call)

          ;;;       )
          (vector-set! regs-out dest success-return-call)
          (unless (equal? ret-val-call #f)
            (send mem store ret-offset ret-val-call)
            )
          )
        (define (call)
          (printf "Call\n")
          (define op_args (inst-args (vector-ref code 0)))
          (define dest (vector-ref args 1))
          (define gas (get-arg-val 2))
          (define addr (concretize-val (get-arg-val 3)))
          (define callvalue-call (get-arg-val 4))
          (define args-offset (concretize-val (get-arg-val 5)))
          (define args-len (bitvector->natural (concretize-val (get-arg-val 6))))
          (define ret-offset (concretize-val (get-arg-val 7)))
          (define ret-len (bitvector->natural (concretize-val (get-arg-val 8))))
          (define calldata-call (send mem load args-offset #:n args-len))
          (define-values (success-return-call ret-val-call) ((global-call G)
                                                             addr
                                                             calldata-call
                                                             callvalue-call
                                                             (vector-ref contract-out (index-of contract-out-str "ADDRESS"))
                                                             origin
                                                             #f))
          (pp ret-val-call)
          (set! RETURNDATASIZE (bv (/ (bv-length ret-val-call) 8) 256))
          (set! RETURNDATA ret-val-call)
          ;;; (when (> (bv-length ret-val-call) (* 8 ret-len))
          ;;;   (printf "ret-len not match, truncate ret-val-call\n")
          ;;;   (printf "bv-length ret-val-call=~a\n" (bv-length ret-val-call))
          ;;;   (printf "ret-len (8*)=~a\n" (* 8 ret-len))
          ;;;   (set! ret-val-call (srclenextract 0 (* 8 ret-len) ret-val-call))
          ;;;   (pp ret-val-call)

          ;;;       )
          (vector-set! regs-out dest success-return-call)
          (unless (equal? ret-val-call #f)
            (send mem store ret-offset ret-val-call)
            )
          )

        (define (staticcall)
          (printf "staticcall\n")
          (define op_args (inst-args (vector-ref code 0)))
          (define dest (vector-ref args 1))
          (define gas (get-arg-val 2))
          (define addr (concretize-val (get-arg-val 3)))
          ;;; (define callvalue-call (get-arg-val 4)) // callvalue always 0 in delegatecall
          (define args-offset (concretize-val (get-arg-val 4)))
          (define args-len (bitvector->natural (concretize-val (get-arg-val 5))))
          (define ret-offset (concretize-val (get-arg-val 6)))
          (define ret-len (bitvector->natural (concretize-val (get-arg-val 7))))
          (define calldata-call (send mem load args-offset #:n args-len))
          (define-values (success-return-call ret-val-call) ((global-call G)
                                                             addr
                                                             calldata-call
                                                             ZERO?
                                                             (vector-ref contract-out (index-of contract-out-str "ADDRESS"))
                                                             origin
                                                             #f))
          (pp ret-val-call)
          (set! RETURNDATASIZE (bv (/ (bv-length ret-val-call) 8) 256))
          (set! RETURNDATA ret-val-call)
          ;;; (when (> (bv-length ret-val-call) (* 8 ret-len))
          ;;;   (printf "ret-len not match, truncate ret-val-call\n")
          ;;;   (printf "bv-length ret-val-call=~a\n" (bv-length ret-val-call))
          ;;;   (printf "ret-len (8*)=~a\n" (* 8 ret-len))
          ;;;   (set! ret-val-call (srclenextract 0 (* 8 ret-len) ret-val-call))
          ;;;   (pp ret-val-call)

          ;;;       )
          (vector-set! regs-out dest success-return-call)
          (unless (equal? ret-val-call #f)
            (send mem store ret-offset ret-val-call)
            )
          )

        (define (returndatacopy)
          (define op_args (inst-args (vector-ref code 0)))
          (define a1 (get-arg-val 1))
          (define a2 (* 8 (bitvector->natural (concretize-val (get-arg-val 2)))))
          (define a3 (* 8 (bitvector->natural (concretize-val (get-arg-val 3)))))
          (define value (srclenextract a2 a3 RETURNDATA))
          (printf "returndatacopy: a1=~a a2=~a a3=~a RETURNDATA=~a value=~a\n" a1 a2 a3 RETURNDATA value)
          (send mem store a1 value)

          )

        (define (codecopy)
          (define op_args (inst-args (vector-ref code 0)))
          (define a1 (get-arg-val 1))
          (define a2 (* 8 (bitvector->natural (concretize-val (get-arg-val 2)))))
          (define a3 (* 8 (bitvector->natural (concretize-val (get-arg-val 3)))))
          (define value (srclenextract a2 a3 codebin))
          (send mem store a1 value)
          )

        (define (balance)
          (define d (vector-ref args 1))
          (define addr (concretize-val (get-arg-val 2)))
          (define val (table-ref (global-balance G) addr))
          (vector-set! regs-out d val))

        (define (selfbalance)
          (define d (vector-ref args 1))
          (define addr (concretize-val (private-address P)))
          (define val (table-ref (global-balance G) addr))
          (vector-set! regs-out d val))

        (define (blockhash)
          (define d (vector-ref args 1))
          (define addr (concretize-val (get-arg-val 2)))
          (define val (blockhash-app addr))
          (vector-set! regs-out d val))
        (print-inst)
        
        (cond
          [(equal? op-name `nop)   (void)]
          [(equal? op-name `stop)   (stop)]
          [(equal? op-name `revert)   (revert)]
          [(equal? op-name `return)   (return)]
          [(equal? op-name `jumpi)   (jumpi)]
          [(equal? op-name `create)   (create)]
          [(equal? op-name `throw)   (throw)]
          [(equal? op-name `jump)   (jump)]
          [(equal? op-name `extcodesize)   (extcodesize)]
          [(equal? op-name `extcodehash)   (extcodehash)]
          [(equal? op-name `extcodecopy)   (extcodecopy)]
          [(equal? op-name `calldataload)   (calldataload)]
          [(equal? op-name `calldatacopy)   (calldatacopy)]
          [(equal? op-name `returndatacopy)   (returndatacopy)]
          [(equal? op-name `selfdestruct)   (selfdestruct)]
          [(equal? op-name `add)   (rrr bvadd)]
          [(equal? op-name `mod)   (rrr bvumod)]
          [(equal? op-name `smod)   (rrr bvsmod-evm)]
          [(equal? op-name `addmod)   (rrr bvaddmod)]
          [(equal? op-name `mulmod)   (rrr bvmulmod)]
          [(equal? op-name `byte)  (rrr byte)]
          [(equal? op-name `xor)   (rrr bvxor)]
          [(equal? op-name `shr)  (rrr bvlshr)]
          [(equal? op-name `shl)  (rrr bvshl)]
          [(equal? op-name `sar)  (rrr bvashr)]
          [(equal? op-name `signextend)  (rrr signextend)]
          [(equal? op-name `store) (store)]
          [(equal? op-name `store8) (store8)]
          [(equal? op-name `load)  (load)]
          [(equal? op-name `sstore) (sstore)]
          [(equal? op-name `sload)  (sload)]
          [(equal? op-name `sha3)  (rrr vsha3)]
          [(equal? op-name `iszero)  (rr iszero)]
          [(equal? op-name `snot)  (rr bvnot)]
          [(equal? op-name `sub)   (rrr bvsub)]
          [(equal? op-name `lt)   (rrr vlt)]
          [(equal? op-name `slt)   (rrr vslt)]
          [(equal? op-name `gt)   (rrr vgt)]
          [(equal? op-name `sgt)   (rrr vsgt)]
          [(equal? op-name `and)  (rrr bvand)]
          [(equal? op-name `or)  (rrr bvor)]
          [(equal? op-name `exp)  (rrr vexp)]
          [(equal? op-name `div)  (rrr bvudiv-evm)]
          [(equal? op-name `sdiv)  (rrr bvsdiv-evm)]
          [(equal? op-name `mul)  (rrr bvmul)]
          [(equal? op-name `eqcmp)  (rrr veqcmp)]
          [(equal? op-name `eq)  (rr eq)]
          [(equal? op-name `eq#) (ri eq)]
          [(equal? op-name `call)  (call)]
          [(equal? op-name `staticcall)  (staticcall)]
          [(equal? op-name `codecopy)  (codecopy)]
          [(equal? op-name `balance)  (balance)]
          [(equal? op-name `selfbalance)  (selfbalance)]
          [(equal? op-name `blockhash)  (blockhash)]

          [(equal? op-name `delegatecall)  (delegatecall)]
          [else (assert #f (format "simulator: undefine instruction ~a" op))])
        op-name
        )


      (define (interpret-block worker K)
        ;; (assert (> K 0) "bound!")
        (define blockrandkey (random 10000000 100000000))
        (when (run-end)
          (displayln "run-end")
          (printf "address: ~a\n" (private-address P))
          )
        (define stack-vars-str "")
        (unless (run-end)
          (printf "\n\nstart block stack-vars:")
          (set! stack-vars-str
                (with-output-to-string
                  (lambda ()
                    (for-each printval stack-vars))))
          (printf "~a" stack-vars-str)

          (define blk-obj (get-item addr->block worker))
          ;;; (printf "blk-obj: ~a\n" blk-obj)
          (define empty_pops (basic-block-empty_pops blk-obj))
          (printf "\nempty_pops: ~a\n" empty_pops)
          (define remaining_stack (basic-block-remaining_stack blk-obj))
          ;;; (printf "remaining_stack: ~a\n" remaining_stack)
          (define sns #f)
          (set!-values (sns stack-vars) (split-at stack-vars empty_pops))
          (define (translate-stack-vars var)
            (cond
              [(string-prefix? var "V") (vector-ref regs-out (string->number (substring var 1)))]
              [(string-prefix? var "S") (list-ref sns (string->number (substring var 1)))]
              [(string-prefix? var "0x")
               (bv (string->number (string-replace var "0x" "#x")) BV?)]
              [else (raise (format "Undefined argument for ~a" var))]))
          (define update-stack-func (make-update-stack-func translate-stack-vars remaining_stack))
          (define (parse-code inst-str)
            (define code
              (with-handlers ([ (lambda (v) #t)
                                (lambda (e)
                                  (printf "Parser error: ~a\n" (exn-message e))
                                  (set! met-stop-cmd #t)
                                  'parser-error) ])
                (send parser ir-from-string inst-str)))
            code)
          (when verbose
            (pretty-display `("interpret block----: ", blockrandkey, (get-item id->addr worker))))

          (append-debug-step
           (make-hash (list (cons 'block-idx (- MAX-DEPTH K))
                            (cons 'pc (get-item id->addr worker))
                            ;;; (cons 'code_section_idx code_section_idx)
                            ;;; (cons 'op op)
                            ;;; (cons 'op-name op-name)
                            (cons 'blockrandkey blockrandkey)
                            (cons 'contract (format-address (private-address P))) ; not considering delegatecall
                            (cons 'stack stack-vars-str)
                            )))
          (define last-op (for/last ([x (basic-block-insts blk-obj)] #:break (run-end))
                            (define inst-code (parse-code x))
                            (unless (equal? 'parser-error inst-code)
                              ;;; (printf "start block2 stack-vars: ~a\n" stack-vars)

                              (interpret-inst inst-code blk-obj K update-stack-func translate-stack-vars))
                            ))

          ;;; (printf "why can anyone go here\n")
          ;;; (printf "last-op: ~a\n" last-op)
          (define successors (basic-block-succs blk-obj))
          (unless (or (empty? successors) (equal? 'jump last-op) (equal? 'jumpi last-op))
            (update-stack-func)
            (interpret-block (first successors) (sub1 K)))

          )
        (printf "ending block----: ~a ~a ~a\n" blockrandkey (get-item id->addr worker) stack-vars-str)

        )

      (define (exe-m)
        (interpret-block 0 MAX-DEPTH)
        )

      (exe-m)
      (printf "address: ~a\n" (private-address P))

      ; construct return value
      ; first hack: return the value of slot0
      ;;; (table-ref storage-out ZERO?)
      (start-new-debug-chapter)
      (values success-return return-val)
      )

    ;;;;;;;;;;;;;;;;;;;;;;;;;;; Required methods ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Interpret a given program from a given state.
    ;; 'program' is a vector of 'inst' struct.
    ;; 'ref' is optional. When given, it is an output program state returned from spec.
    ;; We can assert something from ref to terminate interpret early.
    ;; This can help prune the search space.
    (define (interpret program state [ref #f])
      (void)
      )

    ;; Estimate performance cost of a given program.
    (define (performance-cost program)
      ; ? ;; modify this function
      (void))


    )
  )
