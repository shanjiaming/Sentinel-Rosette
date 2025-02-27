#lang rosette

(provide (all-defined-out))


(struct global (get-val-in-old-assms call balance addr->P accountexist?)
  #:mutable #:transparent)

(struct private (address interpreter input-state storage-out onmainnet code)
  #:mutable #:transparent)

(struct code (printer parser addr->block id->addr addr->id maxreg bin)
  #:mutable #:transparent)
(struct basic-block (address insts succs empty_pops remaining_stack) #:transparent)

(define (make-table from to)
  (define-symbolic* tbl (~> from to))
  tbl)

(define (bv-length bvn)
  (if (equal? bvn #f)
      0
      (length (bitvector->bits bvn))))


(define (srclenextract src len b)
  (printf "src=~a len=~a b=~a\n" src len b)
  (when (not (equal? len 0))
    (if (equal? b #f)
        (set! b (bv 0 len))
        (if (> (+ len src) (bv-length b))
            (begin
              (printf "srclenextract: len+src > b, concat b with many0\n")
              (set! b (concat b (bv 0 (- (+ src len) (bv-length b)))))
              (printf "end")
              )
            (void)
            )
        )
    )
  (printf "now\n")
  (if (> len 0)
      (begin
        (define blen (bv-length b))
        (printf "blen=~a\n" blen)
        (extract (- (- blen src) 1) (- (- blen src) len) b))
      #f))

(define (str->bv str)
  (define clean-str (string-trim str))
  (define replaced-str (string-replace clean-str "0x" "#x"))
  (define bitlen (* 4 (- (string-length replaced-str) 2)))
  (bv (string->number replaced-str) bitlen))

(define (bv->str bvn)
  (substring (format "~a" bvn) 6 (+ 6 (/ (bv-length bvn) 4))))


(define (format-address bvn)
  (when (not (equal? (bv-length bvn) 256))
    (raise (string-append "bv-length is not 256: ~a" bvn)))
  (substring (format "~a" bvn) 30 70))

(define-syntax-rule (while test body ...)
  (call/cc (lambda (exit)
             (for ([dummy (in-naturals)])
               (unless test (exit 'done))
               body ...))))

(define (gen-reg)
  (define-symbolic* reg (bitvector 256))
  reg)

(define (bv-even? exp)
  (bvzero? (bit 0 exp)))

(define (vexp base exp)
  (cond
    [(bvzero? exp) (bv 1 256)]
    [(bv-even? exp)
     (let ([half-exp (bvudiv exp (bv 2 256))])
       (let ([half (vexp base half-exp)])
         (bvmul half half)))]
    [else
     (bvmul base (vexp base (bvsub exp (bv 1 256))))]))

(define (abs a)
  (if (bvslt a (bv 0 256)) (bvneg a) a))

(define (sgn a)
  (if (bvslt a (bv 0 256)) (bv -1 256) (bv 1 256)))

(define (bvsmod-evm a b)
  (bvmul (sgn a) (bvumod (abs a) (abs b))))

(define (bvumod a b)
  (if (bvzero? b) (bv 0 256) (bvsub a (bvmul b (bvudiv a b)))))

(define (bvudiv-evm a b)
  (if (bvzero? b) (bv 0 256) (bvudiv a b)))

(define (bvsdiv-evm a b)
  (if (bvzero? b) (bv 0 256) (bvsdiv a b)))
(define (bvaddmod a b c)
  (define a-256 (concat (bv 0 256) a))
  (define b-256 (concat (bv 0 256) b))
  (define c-256 (concat (bv 0 256) c))
  (if (bvzero? c) (bv 0 256) (extract 255 0 (bvumod (bvadd a-256 b-256) c-256))))

(define (bvmulmod a b c)
  (define a-256 (concat (bv 0 256) a))
  (define b-256 (concat (bv 0 256) b))
  (define c-256 (concat (bv 0 256) c))
  (if (bvzero? c) (bv 0 256) (extract 255 0 (bvumod (bvmul a-256 b-256) c-256))))