#lang rosette
;;; https://docs.racket-lang.org/rosette-guide/ch_syntactic-forms_rosette.html#%28form._%28%28lib._rosette%2Fquery%2Fform..rkt%29._solve%29%29
(define-symbolic x y integer?)
; This query maximizes x + y while ensuring that y - x < 1 whenever x < 2:
(assume (< (+ y x) 25))
(assume (> x 0))
(assume (> y 0))
(assume (< x 100))
(assume (< y 100))
(define model (optimize #:maximize (list (* x y)) #:guarantee `()))
(display model)
