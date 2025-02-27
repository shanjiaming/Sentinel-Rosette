#lang rosette

(require racket/string
         racket/list)

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

(define (custom-print expr)
  (let ([s (format "~a" expr)])
    (shorten-bv-in-string s)))

(define expr
  '(ite (bvult (bvadd arg$113 arg$114) arg$113)
        (bv #x0000000000000000000000000000000000000000000000000000000000000001 256)
        (bv #x0000000000000000000000000000000000000000000000000000000000000000 256)))

(printf "~a\n" (custom-short-print expr))
