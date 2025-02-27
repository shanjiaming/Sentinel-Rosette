#lang racket
(require racket/control)

(define-syntax with-return
  (syntax-rules ()
    [(_ body ...)
     (reset
      (let ([return (lambda (v) (abort-current-continuation return v))])
        body ...))]))

;; 使用示例
(define (test x)
  (with-return
    (when (> x 10)
      (return (string-append "太大了：" (number->string x))))
    (string-append "数字：" (number->string x))))

(displayln (test 5))    ; 输出 "数字：5"
(displayln (test 20))   ; 输出 "太大了：20"