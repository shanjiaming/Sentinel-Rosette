#lang rosette
(struct storage-item (key value) #:transparent)

;; 创建实例并打印
(define item (storage-item #x1234 #xabcd))
(printf "完整结构体: ~a\n" item)
(printf "键: ~a\n" (storage-item-key item))
(printf "值: ~a\n" (storage-item-value item))