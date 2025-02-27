#lang rosette

(require "special.rkt" "memory-racket.rkt" "ops-rosette.rkt" "utils.rkt")
(provide (all-defined-out))


; way of optimization:
; 模仿项目原来那个实现，但是要加上assert：
; 1. load src-len一定和store的src-len 完美匹配（？

;;; (define (bv-length bv)
  ;;; (length (bitvector->bits bv)))

(define (addr->idx addr)
  (bitvector->integer addr))

;; 修改后的工具函数：将一个 bitvector 拆分为 n 个 8 位的字节，反转列表确保高低字节顺序正确
(define (bv->bytes bv n)
  (reverse
   (for/list ([i (in-range n)])
     (extract (+ (* i 8) 7) (* i 8) bv))))

;; 工具函数：将一个字节列表拼接成一个 bitvector
(define (bytes->bv bytes)
  (apply concat bytes))

;; 全局内存大小（以字节为单位），默认 32 字节
(define memory-size 32)
(define (init-memory-size)
  (set! memory-size 32))
(define (increase-memory-size new-size)
  (when (> new-size 1000000)
    (raise "memory-rosette: memory size is too large."))
  (pretty-display (format "Increase memory size to ~x" new-size))
  (set! memory-size new-size))
(define (finalize-memory-size)
  (set! memory-size (add1 memory-size))
  (pretty-display (format "Finalize memory size ~x" memory-size)))

;; 内存模型类，满足 equal<%> 和 printable<%> 接口
(define memory-rosette%
  (class* special% (equal<%> printable<%>)
    (super-new)
    (init-field get-fresh-val
                [size memory-size]
                [mem (make-vector memory-size (bv 0 8))]
                [ref #f])

    (define/public (get-size)
      (vector-length mem))
          
    ;; 实现 equal<%> 接口方法
    (define/public (equal-to? other recur)
      (and (is-a? other memory-rosette%)
           (equal? mem (get-field* mem other))))
    (define/public (equal-hash-code-of hash-code)
      (hash mem))
    (define/public (equal-secondary-hash-code-of hash-code)
      (hash mem))

    (define/public (custom-print port depth)
      (print `(memory% ,(vector->list mem)) port depth))
    (define/public (custom-write port)
      (write `(memory% ,(vector->list mem)) port))
    (define/public (custom-display port)
      (display `(memory% ,(vector->list mem)) port))

    ;; 内部辅助函数：扩展内存大小以满足要求
    (define (ensure-memory-size required)
      (when (> required (vector-length mem))
        (define current (vector-length mem))
        (define new-size (if (zero? (remainder required 32))
                             required
                             (+ required (- 32 (remainder required 32)))))
        (pretty-display (format "Expanding memory from ~x to ~x" current new-size))
        (define new-mem (make-vector new-size (bv 0 8)))
        (for ([i (in-range current)])
          (vector-set! new-mem i (vector-ref mem i)))
        (set! mem new-mem)))

    ;; 从地址 addr 加载 n 字节，n==1 返回一个 8 位 bitvector，n>1 时将连续 n 个字节拼接
    (define (load-bytes addr n)
      (if (= n 0)
          #f
          (begin
            (ensure-memory-size (+ addr n))
            (define bytes (for/list ([i (in-range n)])
                            (vector-ref mem (+ addr i))))
            (if (= n 1)
                (first bytes)
                (bytes->bv bytes))
            )
          )
      )

    ;; 从地址 addr 存储 n 字节
    (define (store-bytes addr n val)
      (ensure-memory-size (+ addr n))
      (printf "store-bytes: addr=~a n=~a val=~a\n" addr n val)
      
      (printf "memory-size ~a\n" (vector->list mem))
      (if (= n 1)
          (vector-set! mem addr val)
          (let ([bytes (bv->bytes val n)])
            (for ([i (in-range n)])
              (vector-set! mem (+ addr i) (list-ref bytes i))))))

    (define/public (load addr #:n [n 32])
      ;;; (printf "addr: ~a\n" addr)
      ;;; (printf "n: ~a\n" n)
      ;;; (printf "addr->idx: ~a\n" (addr->idx addr))
      (load-bytes (addr->idx addr) n))

    (define/public (store addr val)
      (define n (/ (bv-length val) 8))
      (store-bytes (addr->idx addr) n val))

    (define/public (clone)
      (new memory-rosette%
           [get-fresh-val get-fresh-val]
           [size (vector-length mem)]
           [mem (list->vector (vector->list mem))]
           [ref ref]))))

;; 测试函数，演示单字节与 32 字节 load/store 操作
(define (test)
  (set! memory-size 32)
  (define get-fresh (lambda () (define-symbolic* val (bitvector 8)) val))
  (define mem (new memory-rosette% [get-fresh-val get-fresh]))
  (assert (equal? (send mem load 9) (bv 0 8)) "mem: load 9 should be 0")
  (send mem store 2 (bv 222 8))
  (assert (equal? (send mem load 2) (bv 222 8)) "mem: load 2 should be 222")
  (define word32
    (bv #x112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00 256))
  (send mem store 9 word32 #:n 32)
  (assert (equal? (send mem load 9 #:n 32) word32)
          "mem: load 9 (32 bytes) should equal word32")
  (pretty-display `(mem ,(send mem load 0 #:n 64)))
  (define mem2 (send mem clone))
  (assert (equal? (send mem2 load 9 #:n 32) word32)
          "mem2: load 9 (32 bytes) should equal word32")
  (pretty-display `(mem2 ,(send mem2 load 0 #:n 64))))

;;; (test)
