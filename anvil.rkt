#lang rosette
(require json net/http-client)
(require "./utils.rkt")
(provide (all-defined-out))

; addr (str): server address | port (int): anvil port | uri (str): anvil uri
(struct serv (addr port uri) #:mutable #:transparent #:reflection-name 'anvil-server)

; encode hasheq object into string
(define (rpc-cmd method params id)
    (jsexpr->string (make-hash (list
        (cons 'jsonrpc "2.0")
        (cons 'method method)
        (cons 'params params)
        (cons 'id id)
    )))
)

; generic remote procedural call for anvil server
; return: status in bool, result in json
(define (rpc sv data)
    (define-values (status headers in) (http-sendrecv
        (serv-addr sv) (serv-uri sv)
        #:port (serv-port sv)
        #:version "1.1"
        #:method "POST"
        #:headers (list "Content-Type: application/json")
        #:data data
    ))
    (define ok? (equal? #"HTTP/1.1 200 OK" status))
    (define body (string->jsexpr (port->string in)))
    (close-input-port in)
    (values ok? body)
)

(define (unwrap ok? res)
    (if (&& ok? (hash-has-key? res 'result))
        (hash-ref res 'result)
        (error 'unwrap (format "invalid status, response: ~a" res))
    )
)

; ==================================== ;
; ==== anvil's eth json rpc calls ==== ;
; ==================================== ;
; ref: https://ethereum.org/en/developers/docs/apis/json-rpc/

; return (int): block number
(define (eth_blockNumber sv [id 67] #:raw? [raw? #f]) 
    (define-values (ok? res) (rpc sv (rpc-cmd "eth_blockNumber" null id)))
    (if raw? (values ok? res) (hexstr->number (unwrap ok? res)))
)

; n (int): block number | fo? (bool): return full object (#t) or tx hashes (#f)
; return (json)
(define (eth_getBlockByNumber sv n [fo? #t] [id 67] #:raw? [raw? #f]) 
    (define-values (ok? res) (rpc sv (rpc-cmd "eth_getBlockByNumber" (list (format "0x~x" n) fo?) id)))
    (if raw? (values ok? res) (unwrap ok? res))
)

; mine a single block
; return (int): 0x0
(define (evm_mine sv [id 67] #:raw? [raw? #f])
    (define-values (ok? res) (rpc sv (rpc-cmd "evm_mine" null id)))
    (if raw? (values ok? res) (hexstr->number (unwrap ok? res)))
)

; FIXME: this method currently doesn't work
; return (hexstr): tx hash
; (define (eth_sendTransaction sv tx [id 67] #:raw? [raw? #f])
;     ; (define-values (ok? res) (rpc sv (rpc-cmd "eth_sendTransaction" (list tx) id)))
;     (define tx0 (make-hash (list
;         (cons 'from (hash-ref tx 'from))
;         (cons 'to (hash-ref tx 'to))
;         (cons 'gas (hash-ref tx 'gas))
;         (cons 'gasPrice (hash-ref tx 'gasPrice))
;         (cons 'value (hash-ref tx 'value))
;         (cons 'input (hash-ref tx 'input))
;     )))
;     (define-values (ok? res) (rpc sv (rpc-cmd "eth_sendTransaction" (list tx0) id)))
;     (if raw? (values ok? res) (unwrap ok? res))
; )

; return (hexstr): tx hash
(define (eth_sendUnsignedTransaction sv tx [id 67] #:raw? [raw? #f])
    (define tx0 (make-hash (list
        (cons 'from (hash-ref tx 'from))
        (cons 'to (hash-ref tx 'to))
        (cons 'gas (hash-ref tx 'gas))
        (cons 'gasPrice (hash-ref tx 'gasPrice))
        (cons 'value (hash-ref tx 'value))
        (cons 'input (hash-ref tx 'input))
    )))
    (define-values (ok? res) (rpc sv (rpc-cmd "eth_sendUnsignedTransaction" (list tx0) id)))
    (if raw? (values ok? res) (unwrap ok? res))
)

; addr (hexstr)
; return (int): balance
(define (eth_getBalance sv addr [bn "latest"] [id 67] #:raw? [raw? #f])
    (define-values (ok? res) (rpc sv (rpc-cmd "eth_getBalance" (list addr bn) id)))
    (if raw? (values ok? res) (hexstr->number (unwrap ok? res)))
)

; (new method) reset server's block number
; bn (int): block number
; return (null)
(define (anvil_resetBlockNumber sv bn [id 67] #:raw? [raw? #f])
    ; the original method takes blockNumber as integer, not hexstr
    (define-values (ok? res) (rpc sv (rpc-cmd "anvil_reset" (list 
        (make-hash (list (cons 'forking (make-hash (list (cons 'blockNumber bn))))))) id)))
    (if raw? (values ok? res) (unwrap ok? res))
)

; on? (bool): whether to enable automine or not
; return (null)
(define (evm_setAutomine sv on? [id 67] #:raw? [raw? #f])
    (define-values (ok? res) (rpc sv (rpc-cmd "evm_setAutomine" (list on?) id)))
    (if raw? (values ok? res) (unwrap ok? res))
)

; hash (hexstr): tx hash
; return (json)
(define (eth_getTransactionReceipt sv hash [id 67] #:raw? [raw? #f])
    (define-values (ok? res) (rpc sv (rpc-cmd "eth_getTransactionReceipt" (list hash) id)))
    (if raw? (values ok? res) (unwrap ok? res))
)
;;; curl https://docs-demo.quiknode.pro/ \
;;;   -X POST \
;;;   -H "Content-Type: application/json" \
;;;   --data '{"method":"eth_getTransactionReceipt","params":["0x85d995eba9763907fdf35cd2034144dd9d53ce32cbec21349d4b12823c6860c5"],"id":1,"jsonrpc":"2.0"}'

;;; curl https://docs-demo.quiknode.pro/ \
;;;   -X POST \
;;;   -H "Content-Type: application/json" \
;;;   --data '{"method":"eth_getTransactionByHash","params":["0xb1fac2cb5074a4eda8296faebe3b5a3c10b48947dd9a738b2fdf859be0e1fbaf"],"id":1,"jsonrpc":"2.0"}'


;;; ; hash (hexstr): tx hash
;;; ; return (json)
;;; (define (eth_getTransactionByHash sv hash [id 67] #:raw? [raw? #f])
;;;     (define-values (ok? res) (rpc sv (rpc-cmd "eth_getTransactionByHash" (list hash) id)))
;;;     (if raw? (values ok? res) (unwrap ok? res))
;;; )

; addr (hexstr) | bal (int)
; return (null)
(define (anvil_setBalance sv addr bal [id 67] #:raw? [raw? #f])
    (define-values (ok? res) (rpc sv (rpc-cmd "anvil_setBalance" (list addr (number->hexstr bal 0)) id)))
    (if raw? (values ok? res) (unwrap ok? res))
)




;; ================
;; existing code...
;; ================

;; Suppose we have the `serv` struct and the RPC machinery from your snippet:
;; (struct serv (addr port uri) #:mutable #:transparent #:reflection-name 'anvil-server)
;; (define (rpc-cmd method params id) ...)
;; (define (rpc sv data) ...)
;; (define (unwrap ok? res) ...)
;; (define (hexstr->number s) ...)  ; from ./utils.rkt or similar
;;
;; plus the anvil methods: eth_blockNumber, eth_getBlockByNumber, evm_mine, etc.

;; -------------
;; 1) balanceOf
;; -------------

;; Standard "balanceOf(address) → uint256".
;; - `sv` is your anvil server struct.
;; - `token` is the token contract address (e.g. "0x1234abcd...").
;; - `user` is the user address.
;; - We default to block="latest".
;; - If #:raw? #t, we just return the raw JSON result instead of an integer.

; see https://ethereum.stackexchange.com/questions/25265/get-the-balance-of-an-erc20-token-at-an-ethereum-address
(define (balanceOf sv token user
                   [block "latest"]
                   [id 67]
                   #:raw? [raw? #f])
  ;; Function selector for `balanceOf(address)`:
  (define func-selector "0x70a08231")

  ;; Strip off "0x" (if present) from the user address, downcase, then pad to 64 hex digits.
  ;; ERC-20 expects a 32-byte address input in the call data.
  (define user-trim (string-downcase (string-trim user "0x" #:left? #t)))
  (define padded-user (string-append (make-string 24 #\0) user-trim))
  
  ;; Final call data = 4-byte selector + 32-byte address
;;;   (define call-data (string-append func-selector padded-user))
  (define call-data (string-append func-selector padded-user))

  ;; Perform `eth_call`.
  (define-values (ok? res)
    (rpc sv (rpc-cmd "eth_call"
                     (list (make-hash (list
                                       (cons 'to token)
                                       (cons 'input call-data)))
                           block)
                     id)))

  ;; If raw? => return raw JSON; otherwise parse as big integer
  (if raw?
      (values ok? res)
      (hexstr->number (unwrap ok? res))))

