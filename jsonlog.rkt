#lang racket
(provide init-debug-arena
         append-debug-step
         start-new-debug-chapter
         set-chapter-props!
         current-last-step
         write-debug-arena-json
         append-debug-step-debug)

(require json)

;; Global state: debug-arena is a box holding a list of chapters.
;; Each chapter is a mutable hash table with keys:
;;   'steps         -- a list of log steps
;;   'chapter-props -- fixed chapter properties (optional)
(define debug-arena (box '()))

;; Ensure a current chapter exists; if not, start one.
(define (ensure-current-chapter)
  (when (null? (unbox debug-arena))
    (start-new-debug-chapter)))

;; Clear debug-arena.
(define (init-debug-arena)
  (set-box! debug-arena '()))

;; Append a log step to the current chapter.
;; Merges current chapter's fixed properties (if any) into step-data.
(define (append-debug-step step-data)
  (ensure-current-chapter)
  (define current (last (unbox debug-arena)))
  (define chapter-props (hash-ref current 'chapter-props '()))
  (when (hash? chapter-props)
    (for ([key (in-hash-keys chapter-props)])
      (hash-set! step-data key (hash-ref chapter-props key))))
  (define current-steps (hash-ref current 'steps))
  (hash-set! current 'steps (append current-steps (list step-data))))

;; Append a debug step with fixed keys.
(define (append-debug-step-debug depth pc code_section_idx op contract stack)
  (append-debug-step
    (make-hash (list (cons 'depth depth)
                     (cons 'pc pc)
                     (cons 'code_section_idx code_section_idx)
                     (cons 'op op)
                     (cons 'contract contract)
                     (cons 'stack stack)))))

;; Start a new chapter by appending a new chapter (with empty steps) to debug-arena.
(define (start-new-debug-chapter)
  (define new-chapter (make-hash (list (cons 'steps '()))))
  (set-box! debug-arena (append (unbox debug-arena) (list new-chapter))))

;; Set fixed properties for the current chapter.
(define (set-chapter-props! props)
  (ensure-current-chapter)
  (define current (last (unbox debug-arena)))
  (hash-set! current 'chapter-props props))

;; Return the last step of the current chapter.
(define (current-last-step)
  (ensure-current-chapter)
  (define current (last (unbox debug-arena)))
  (define steps (hash-ref current 'steps))
  (if (null? steps) '() (last steps)))

;; Write the entire debug_arena data to a file as JSON.
;; Chapters with an empty 'steps list are filtered out.
(define (write-debug-arena-json filepath)
  (define chapters (filter (lambda (chap)
                             (not (null? (hash-ref chap 'steps))))
                           (unbox debug-arena)))
  (define final-data (hash 'debug_arena chapters))
  (with-output-to-file filepath
    (lambda () (write-json final-data))
    #:exists 'replace)
  (displayln (format "debug_arena JSON written to: ~a" filepath)))
