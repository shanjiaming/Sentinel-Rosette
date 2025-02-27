#lang debug rosette

(require "solidity/solidity-parser.rkt" "solidity/solidity-printer.rkt" "solidity/solidity-machine.rkt"
         "solidity/solidity-interpret.rkt" "memory-racket.rkt" "utils.rkt"
         json racket/sandbox)
(require racket/pretty)
(require rosette/solver/smt/z3)
;;; (require debug/repl)
(require racket/path)
(require "jsonlog.rkt")

(define attackname "")

(current-solver (z3 #:logic 'QF_UFBV))
(define vandal-timeout 120)
(define synthesis-timeout 360);; 6mins

(dynamic-wind
 (lambda ()
   (init-debug-arena)
   )
 (lambda ()
   (define t1 (current-inexact-milliseconds))
   ;; Phase 0: Set up bitwidth for Rosette
   (define BV? (bitvector 256))
   (current-bitwidth #f)
   (define ADDRESSONE (bv #x1111111111111111111111111111111111111111 256))
   (define entry-funcname "")
   (define entry-funcsig #f)
   (define entryaddress (bv #x9f7cf1d1f558e57ef88a59ac3d47214ef25b6a06 256))
   (define BLOCKNUMBER 21848000)
   (define cheataddress (bv #x7109709ECfa91a80626fF3989D68f67F5b1DD12D 256))
   ;;; (define cheatP (private cheataddress #f #f #f #f #f))
   ;;; (define cheatP #f)
   (define cheatbinloc "out/CheatCodes.bin")
   (define EntryCallValue (bv #x0 256))
   (define EntryCaller (bv #x1804c8ab1f12e6bbf3894d4083f33e07309d1f38 256))
   (define EntryOrigin (bv #x1804c8ab1f12e6bbf3894d4083f33e07309d1f38 256))

   ;;; (define entrybinloc (vector-ref (current-command-line-arguments) 0))
   ;-----------------------------------------config start--------------------------------------
   ;-------------------------------------------------------------------------------------------


   
   (set! attackname (getenv "EXP_NAME"))

   ;;; (set! BLOCKNUMBER 10852715)
   ;;; (define entrybinloc "out/bzx.sol/bzx.bin")
   ;;; (set! entry-funcname "testExploit()")

   ;;; (define BLOCKNUMBER 10592516)
   ;;; (set! entryaddress AD)
   ;;; (define entrybinloc "out/Simple42.sol/Simple.bin")
   ;;; (set! entry-funcname "run()")

   ;;; (set! BLOCKNUMBER 10592516)
   ;;; (define entrybinloc "out/Opynifc.sol/ContractTest.bin")
   ;;; (set! entry-funcname "test_attack()")


   ;;; (set! BLOCKNUMBER 10307563)
   ;;; (define entrybinloc "out/Bancorifc.sol/BancorExploit.bin")
   ;;; (define entrybinloc "out/Bancorcheatfork.sol/BancorExploit.bin")
   ;;; (set! entry-funcname "testsafeTransfer()")
   ;(set! entry-funcsig #x3630ac4e)

   (define entrybinloc (string-append "out/" attackname "/Exploit.bin"))
   (set! entry-funcname "run()")


   (define binlocmap (hash
                      entryaddress entrybinloc
                      cheataddress cheatbinloc
                      ))

   (define balance-out (make-hash))

   (define (attack? address) (cond
                               ((bveq address entryaddress) #t)
                               (else #f)
                               ))

   (define DIGGINGTHRESHOLDLOW #x100)
   (define DIGGINGTHRESHOLDHIGH #x123456789012345678901234567890123)

   ;-----------------------------------------config end-----------------------------------------
   ;--------------------------------------------------------------------------------------------


   (define (get-balance address)
     (define cmd
       (format "cast balance 0x~a --block ~a --rpc-url https://eth-mainnet.g.alchemy.com/v2/P-x0L9coIqzuhfI091DXitR7BzYbABFA"
               (format-address address)
               BLOCKNUMBER))
     (printf "get-balance cmd: ~a\n" cmd)
     (define output (with-output-to-string (lambda () (system cmd))))
     (bv (string->number (string-trim output)) 256)
     )

   (define (get-nonce address)
     (define cmd
       (format "cast nonce 0x~a --block ~a --rpc-url https://eth-mainnet.g.alchemy.com/v2/P-x0L9coIqzuhfI091DXitR7BzYbABFA"
               (format-address address)
               BLOCKNUMBER))
     (printf "get-nonce cmd: ~a\n" cmd)
     (define output (with-output-to-string (lambda () (system cmd))))
     (bv (string->number (string-trim output)) 256)
     )

   (define (balance address)
     (if (bveq address cheataddress)
         (bv #x0 256)
         (begin
           (unless (hash-has-key? balance-out address)
             (hash-set! balance-out address (get-balance address)))
           (hash-ref balance-out address)
           )
         )
     )

   (define (get-blockdata sym)
     (define cmd
       (format "cast block ~a --json --rpc-url https://eth-mainnet.g.alchemy.com/v2/P-x0L9coIqzuhfI091DXitR7BzYbABFA"
               BLOCKNUMBER))
     (define output (with-output-to-string (lambda () (system cmd))))
     (define jsexpr (string->jsexpr output))
     (zero-extend (str->bv (hash-ref jsexpr sym)) BV?)
     )


   (define entry-funcsig-calc
     (if (string=? entry-funcname "")
         (bv entry-funcsig 32)
         (let ([cmd (string-append "cast sig '" entry-funcname "'")])
           (printf "cmd: ~a\n" cmd)
           (define output (with-output-to-string (lambda () (system cmd))))
           (printf "output: ~a\n" output)
           (printf "str->bv output: ~a\n" (str->bv output))
           (str->bv output))))


   (define increasing-counter ADDRESSONE)

   (define holes (mutable-set))

   ;;; (define calldataload-funcsig (bvshl (bv #xdf201a46 256) (bv 224 256))); simple(uint256) ; compare as 256 in simulator, no difference. Later when we change calldataload, this should be changed.
   ;;; (define calldataload-varnum 0)
   ;;; (define calldataload-funcsig (bvshl (bv #xd3227572 256) (bv 224 256))); simple(uint256) ; compare as 256 in simulator, no difference. Later when we change calldataload, this should be changed.
   ;;; (define calldataload-varnum 1)


   (define HOLEWID 256) ; for readability choose 256, 8 is also good, but for hole digging we will use 256

   ;;; (define )
   ;;; (define funcsig (bv #xd3227572 32)) ; 1
   ;(define funcsig (bv #x1d8a0cc8 32)) ; 2
   ;;; (define arg256num 1)
   ;;; (define calldata-concrete (concat funcsig (bv #x11 256) )); simple(uint256) ; compare as 256 in simulator, no difference. Later when we change calldata, this should be changed.


   (define (gen-hole)
     (define-symbolic* hole (bitvector HOLEWID))
     (set-add! holes hole)
     hole)
   ;;; (define entry-calldata
   ;;;   (apply concat
   ;;;          (cons funcsig
   ;;;                (build-list (/ (* 256 arg256num) HOLEWID) (λ (i) (gen-hole))))))



   (define assumptions #t)

   (define (get-val-in-old-assms expr)
     (define sol (solve (assume assumptions)))
     (evaluate expr sol))


   (define Ps (make-hash
               (list
                ;;; (cons cheataddress cheatP)
                )
               ))

   (define (addr->P address)
     (unless (hash-has-key? Ps address)
       (printf "enter init-contract-addr address: ~a\n" address)
       (init-contract-addr address)
       )
     (printf "startref Ps address: ~a\n" address)
     (hash-ref Ps address)
     )

   (define (accountexist? address)
     ;; Step 1: local check
     (or (hash-has-key? binlocmap address)
         (hash-has-key? balance-out address)
         (not (bvzero? (get-nonce address)))
         (not (bvzero? (balance address)))))

   (define G (global get-val-in-old-assms #f balance addr->P accountexist?))




   (define-values (aaa _ __) (split-path (string->path entrybinloc)))
   (define foldername-str (path->string aaa))
   (printf "foldername-str: ~a\n" foldername-str)

   (define (getslotval address slot blocknumber)
     (printf "getslotval address: ~a\n" address)
     (printf "getslotval slot: ~a\n" slot)
     (printf "getslotval blocknumber: ~a\n" blocknumber)
     (if (bveq address cheataddress)
         (begin
           (printf "cheat getslotval\n")
           (bv #x0 256)
           )
         (begin
           (define addr (format-address address))
           (printf "eth_getStorageAt addr: ~a\n" addr)
           (define endpoint "https://eth-mainnet.g.alchemy.com/v2/P-x0L9coIqzuhfI091DXitR7BzYbABFA")
           (define json-data
             (format "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getStorageAt\",\"params\":[\"0x~a\",\"0x~x\",\"0x~x\"],\"id\":1}"
                     addr
                     (bitvector->natural slot)
                     BLOCKNUMBER))
           (define cmd
             (format "curl -s -X POST -H \"Content-Type: application/json\" --data '~a' ~a"
                     json-data
                     endpoint))
           (printf "getslotval cmd: ~a\n" cmd)
           (define output (with-output-to-string (lambda () (system cmd))))
           (define jsexpr (string->jsexpr output))
           (str->bv (hash-ref jsexpr 'result))
           )
         )
     )



   (define (seems-address? address)
     (define zerocheck (bvzero? (extract 255 160 address)))
     (define nonzerocheck (bvugt address (bv #x1000000000000000010000000000000000 256)))
     (&& zerocheck nonzerocheck))

   (define (init-contract-addr address)
     (if (bveq address cheataddress)
         (begin
           (define private-own (private address #f #f #f #f (bv 0 1)))
           (printf "cheat init-contract-addr address: ~a\n" address)
           (hash-set! Ps address private-own)
           )
         (begin
           ;;; if address = #f: address = ++ increasing-counter
           (when (not address)
             (set! address increasing-counter)
             (set! increasing-counter (bvadd1 increasing-counter)))
           (define onmainnet #f)
           (define tbl (lambda (var) (bv 0 256)))
           (define binloc #f)
           (when (hash-has-key? binlocmap address)
             (set! binloc (hash-ref binlocmap address)))

           (unless binloc
             (set! binloc (getbinloc address))
             (set! onmainnet #t)
             (set! tbl
                   (lambda (var) (getslotval address var BLOCKNUMBER))
                   ))
           (define codestr (file->string binloc))
           (if (string=? codestr "0x")
               (begin
                 (define private-own (private address #f #f #f #f #f))
                 (printf "nocode init-contract-addr address: ~a\n" address)
                 (hash-set! Ps address private-own)
                 )
               (begin
                 (define code (str->bv codestr))

                 ; interpreter init parameters
                 (define cfg-file-loc binloc)
                 (define cmd (string-append "python smart_opt.py " cfg-file-loc))

                 (printf "cmd: ~a\n" cmd)
                 ; cache
                 (define cache-file-loc (string-append cfg-file-loc "-vandal-cache.json"))
                 (define cfg-str "")
                 (if #t ;(not (file-exists? cache-file-loc))
                     (begin
                       (pretty-display "create vandal")
                       (set! cfg-str
                             (with-handlers ([(lambda (v) #t) (lambda (v) 'timeout)])
                               (call-with-limits vandal-timeout #f (lambda () (with-output-to-string (λ() (system cmd)))))))
                       (when (equal? cfg-str 'timeout)  (assert #f (string-append "vandal timeout in 2 mins!!!-->" cfg-file-loc)))
                       (with-output-to-file cache-file-loc (lambda () (display cfg-str)) #:exists 'replace)
                       )
                     (set! cfg-str (file->string cache-file-loc))
                     )
                 (define cfg-json (string->jsexpr cfg-str))

                 (define parser (new solidity-parser%))
                 (define max-regs 0)
                 (let ([init-regs 0])
                   (for ([blk-json (hash-ref cfg-json `blocks)])
                     (for ([cur-inst (hash-ref blk-json `insts)])
                       (for ([var (filter (λ (str-arg) (string-prefix? str-arg "V")) (string-split cur-inst))])
                         (when (< max-regs (string->number (substring var 1)))
                           (set! max-regs (string->number (substring var 1)))))
                       ))
                   )

                 (define machine (new solidity-machine% [config (+ 1 max-regs)]))
                 (define printer (new solidity-printer% [machine machine]))

                 ;; Phase B: Interpret concrete program with concrete inputs
                 ;; (pretty-display "Phase B: interpret program using simulator writing in Rosette.")
                 ;; define number of bits used for generating random test inputs

                 (define (get-sym-func)
                   (lambda (#:min [min-v #f] #:max [max-v #f] #:const [const #f])
                     (define-symbolic* var BV?)
                     var))




                 (define input-state (send machine get-state (get-sym-func) #:concrete #f))
                 ;; define our own input test, but memory content is random
                 ;; modify program state to match your program state structure
                 ;;#;(define input-state (progstate (vector ?)
                 ; (new memory-racket% [get-fresh-val (get-rand-func test-bit)])))

                 (define contract-out-map (hash
                                           "GAS" (bv #x1ffffffffffffffffffffffffffffffffffff 256)
                                           "ADDRESS" address
                                           "TIMESTAMP" (get-blockdata 'timestamp)
                                           "NUMBER" (bv BLOCKNUMBER 256)
                                           "CODESIZE" (bv (/ (bv-length code) 8) 256)
                                           "GASPRICE" #f
                                           "GASLIMIT" (get-blockdata 'gasLimit)
                                           "DIFFICULTY" (get-blockdata 'difficulty)
                                           "COINBASE" #f
                                           ;;; "CHAINID" (get-blockdata 'chainId)
                                           ;;; "BLOBHASH" (get-blockdata 'blobHash)
                                           ;;; "BLOBBASEFEE" (get-blockdata 'blobBaseFee)
                                           ))

                 (define contract-out-map-vec
                   (apply vector
                          (map (lambda (key)
                                 (hash-ref contract-out-map key))
                               contract-out-str)))

                 (set-progstate-contract! input-state contract-out-map-vec)
                 (pretty-display contract-out-map-vec)
                 (define simulator-rosette (new solidity-simulator-rosette% [machine machine]))
                 (define private-own (private address simulator-rosette input-state tbl onmainnet code))
                 (printf "address: ~a\n" address)
                 (hash-set! Ps address private-own)
                 (send simulator-rosette init-analyzer cfg-file-loc parser printer cfg-json G private-own (attack? address))
                 )
               )
           )
         )
     )

   (define (getbinloc address)
     (define addr (format-address address))
     (printf "eth_getCode addr: ~a\n" addr)
     (define endpoint "https://eth-mainnet.g.alchemy.com/v2/P-x0L9coIqzuhfI091DXitR7BzYbABFA")
     (define json-data (format "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"0x~a\",\"0x~x\"],\"id\":1}" addr BLOCKNUMBER))
     (define cmd (format "curl -s -X POST -H \"Content-Type: application/json\" --data '~a' ~a" json-data endpoint))
     (printf "cmd: ~a\n" cmd)
     (define output (with-output-to-string (lambda () (system cmd))))
     (define jsexpr (string->jsexpr output))
     (define bytecode (hash-ref jsexpr `result))
     (define filename (path->string(build-path foldername-str (string-append addr ".bin"))))
     (call-with-output-file filename (lambda (out) (fprintf out "~a" bytecode)) #:exists 'replace)
     (printf "filename: ~a\n" filename)
     filename)

   ;;; (define private-own (private (make-table BV? BV?)))


   ;;; (getbinloc (bv #x951D51bAeFb72319d9FBE941E1615938d89ABfe2 256))
   ;;; curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_getStorageAt","params":["0x951D51bAeFb72319d9FBE941E1615938d89ABfe2","0x0","latest"],"id":1}' https://eth-mainnet.g.alchemy.com/v2/P-x0L9coIqzuhfI091DXitR7BzYbABFA


   (define cheat-nextprank-addr #f)
   (define cheat-startprank-addr #f) ;actually should be a map, but since cheat is usually used for entry function, so we just use one variable.
   (define cheat-nextprank-txorigin-addr #f)
   (define cheat-startprank-txorigin-addr #f)
   (define callcheat-addr #f)

   (define (run-call address calldata callvalue caller origin delegate? #:name-caller [name-caller #f])
     (define caller-attack? (attack? caller))
     ;;; (when (and cheat-startprank-addr (bveq caller callcheat-addr)) (set! caller cheat-startprank-addr))

     ;;; (define caller-P (hash-ref Ps caller))
     (define calldata-with-holes calldata)
     (define callvalue-with-holes callvalue)
     (define callerafterprank (if (and cheat-startprank-addr (bveq caller callcheat-addr)) cheat-startprank-addr (if cheat-nextprank-addr cheat-nextprank-addr caller)))
     (define callerafterprank-txorigin (if (and cheat-startprank-txorigin-addr (bveq caller callcheat-addr)) cheat-startprank-txorigin-addr (if cheat-nextprank-txorigin-addr cheat-nextprank-txorigin-addr origin)))
     (set! cheat-nextprank-addr #f)
     (set! cheat-nextprank-txorigin-addr #f)
     (printf "runcall\n")
     (printf "address: ~a\n" address)
     (printf "concrete calldata: ~a\n" (get-val-in-old-assms calldata))
     (printf "callvalue: ~a\n" callvalue)
     (printf "caller: ~a\n" caller)
     (printf "origin: ~a\n" origin)
     (printf "delegate?: ~a\n" delegate?)
     (printf "cheat-startprank-addr: ~a\n" cheat-startprank-addr)
     (printf "cheat-nextprank-addr: ~a\n" cheat-nextprank-addr)
     (printf "callcheat-addr: ~a\n" callcheat-addr)
     (printf "msg.send after cheat: ~a\n" callerafterprank)

     (start-new-debug-chapter)

     (if (bveq address cheataddress)
         (begin
           (set! callcheat-addr caller)

           (printf "cheatcodes\n")
           (define cheatsig (srclenextract 0 32 calldata))
           (define firstdata (srclenextract 32 256 calldata))
           (define seconddata (srclenextract 288 256 calldata))
           (define lastdata (extract 255 0 calldata))
           (printf "cheatcodes: ~a\n" cheatsig)
           (cond
             ((bveq cheatsig (bv #x06447d56 32))
              (printf "startPrank\n")
              (printf "who: ~a\n" lastdata)
              (set! cheat-startprank-addr lastdata)
              )
             ((bveq cheatsig (bv #x45b56078 32))
              (printf "startPrankwithtxOrigin\n")
              (printf "who1: ~a\n" firstdata)
              (printf "who2: ~a\n" seconddata)
              (set! cheat-startprank-addr firstdata)
              (set! cheat-startprank-txorigin-addr seconddata)
              )
             ((bveq cheatsig (bv #x71ee464d 32))
              ;createSelectFork(string,uint256)
              (printf "createSelectFork\n")
              (printf "blocknum: ~a\n" seconddata)
              (set! BLOCKNUMBER (bitvector->integer seconddata))
              )
             ((bveq cheatsig (bv #x07b8c65e 32))
              ;createSelectFork(uint256)
              (printf "createSelectFork\n")
              (printf "blocknum: ~a\n" lastdata)
              (set! BLOCKNUMBER (bitvector->integer lastdata))
              )
             ((bveq cheatsig (bv #xc959c42b 32))
              (printf "deal\n")
              (printf "amount: ~a\n" lastdata)
              (hash-set! balance-out firstdata lastdata)
              )
             ((bveq cheatsig (bv #xca669fa7 32))
              (printf "prank\n")
              (printf "who: ~a\n" lastdata)
              (set! cheat-nextprank-addr lastdata)
              )
             ((bveq cheatsig (bv #x47e50cce 32))
              (printf "prankwithtxOrigin\n")
              (printf "who1: ~a\n" firstdata)
              (printf "who2: ~a\n" seconddata)
              (set! cheat-nextprank-addr firstdata)
              (set! cheat-nextprank-txorigin-addr seconddata)
              )
             ;;; ((#x06447d56)
             ;;;   (printf "createSelectFork\n")
             ;;;   (define who (srclenextract 288 256 data))
             ;;;   (printf "who: ~a\n" who)
             ;;;   )
             (else
              (printf "unknown cheatcodes\n")
              )
             )
           (values (bv 1 256) (bv 1 256))

           )

         (begin
           (define P (addr->P (if delegate? caller address)))
           (define pcode (private-code P))
           (hash-set! balance-out address (bvadd (balance address) callvalue-with-holes))
           (hash-set! balance-out caller (bvsub (balance caller) callvalue-with-holes))
           
           (if (equal? pcode #f)
               (begin
                 (printf "no code, init-contract-addr\n")
                 (values (bv 1 256) #f)

                 )
               (begin
                 (when caller-attack?
                   (printf "dig hole\n")

                   (unless bvzero? callvalue
                     (set! callvalue-with-holes (gen-hole))
                     (set! assumptions (&& assumptions (bveq callvalue-with-holes callvalue)))
                     )

                   ; recognize hole, dig hole, use symbolic to replace.
                   ; How to recognize hole? 1. use abi (this is practical) 2. recognize address pattern (also practical and fast to implement, check zero num to decide, and search on the website to find the address) 3.using backward analysis to recognize which part may be used as key or funccall address.
                   ; now we just not filter address.
                   (define calldatalen (bv-length calldata))
                   (printf "calldatalen: ~a\n" calldatalen)
                   (define i 32)
                   (set! calldata-with-holes (srclenextract 0 32 calldata))
                   (while (<= (+ i 256) calldatalen)
                          (define calldata-concrete (srclenextract i 256 calldata))
                          (printf "calldata-concrete: ~a\n" calldata-concrete)
                          (define data-to-append calldata-concrete)
                          (when (and (bvugt calldata-concrete (bv DIGGINGTHRESHOLDLOW 256)) (bvult calldata-concrete (bv DIGGINGTHRESHOLDHIGH 256)) (not (seems-address? calldata-concrete)))
                            (define hole (gen-hole))
                            (printf "hole: ~a\n" hole)
                            (set! data-to-append hole)
                            (set! assumptions (&& assumptions (bveq hole calldata-concrete))))
                          (set! calldata-with-holes (concat calldata-with-holes data-to-append))
                          (set! i (+ i 256)))
                   )
                 (printf "calldata-with-holes: ~a\n" calldata-with-holes)

                 ;if address not initialized, then init it.
                 (define interpreter (private-interpreter P))
                 (define input-state (private-input-state P))
                 (define delegatecode #f)
                 (when delegate?
                   (set! delegatecode (send (private-interpreter (addr->P address)) get-code)))
                 (define-values (success-return ret-val)  (send interpreter
                                                                interpret-program
                                                                input-state
                                                                calldata-with-holes
                                                                callvalue-with-holes
                                                                callerafterprank
                                                                callerafterprank-txorigin
                                                                delegatecode
                                                                #:name-caller name-caller))
                 (values success-return ret-val)
                 )
               )

           )
         )
     )

   (set-global-call! G run-call)

   (define entry-calldata entry-funcsig-calc)
   (define-values (success-return ret-val) (run-call entryaddress entry-calldata EntryCallValue EntryCaller EntryOrigin #f))
   (printf "success-return: ~a\n" success-return)
   (printf "ret-val: ~a\n" ret-val)

   (define t2 (current-inexact-milliseconds))

   (define model (optimize #:maximize (list ret-val) #:guarantee `()))
   (printf "model: ~a\n" model)
   (printf "holes: ~a\n" holes)
   (printf "old assignment: ~a\n" assumptions)
   (define max-value (evaluate ret-val model))
   (printf "Maximum target value: ~a\n" max-value)

   (printf "FINAL RESULT:\n")

   (printf "~a -> ~a\n" (bitvector->natural (get-val-in-old-assms ret-val)) (bitvector->natural (evaluate ret-val model)))


   (printf "optimal assignments:\n")
   (for ([i (set->list holes)])
     (printf "~a -> ~a\n" (bitvector->natural (get-val-in-old-assms i)) (bitvector->natural (evaluate i model))))


   (define t3 (current-inexact-milliseconds))
   (printf "Running Evm time ~a\n" (- t2 t1))
   (printf "Solving MaxSMT time ~a\n" (- t3 t2))

   (define result-file (string-append "out/" attackname "/result.txt"))
   (define out-port (open-output-file result-file #:exists 'replace))

   (fprintf out-port "FINAL RESULT:\n")
   (fprintf out-port "~a -> ~a\n"
            (bitvector->natural (get-val-in-old-assms ret-val))
            (bitvector->natural (evaluate ret-val model)))

   (fprintf out-port "optimal assignments:\n")
   (for ([i (set->list holes)])
     (fprintf out-port "~a -> ~a\n"
              (bitvector->natural (get-val-in-old-assms i))
              (bitvector->natural (evaluate i model))))


   (fprintf out-port "Running Evm time ~a\n" (- t2 t1))
   (fprintf out-port "Solving MaxSMT time ~a\n" (- t3 t2))

   (close-output-port out-port)




   )(lambda ()
      (write-debug-arena-json (string-append "out/" attackname "/sentinel_trace.json"))
      ))
;00 00 00 00 00 00 00 00 00 00 00 00 9f 7c f1 d1 f5 58 e5 7e f8 8a 59 ac 3d 47 21 4e f2 5b 6a 06