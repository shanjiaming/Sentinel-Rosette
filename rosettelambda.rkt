#lang racket

;; --- 全局变量 ---
(define stack-vars '())

;; --- 闭包生成函数 ---
;; 接收两个参数：
;;   translate-stack-vars: 一个将单个元素转换为列表的函数
;;   remaining-stack: 待处理的列表
;; 返回的闭包在调用时会：
;;   1. 使用当前全局变量 stack-vars 作为初始值，
;;   2. 对 remaining-stack 中的每个元素调用 translate-stack-vars，
;;      并将结果追加到 stack-vars 后面，
;;   3. 输出更新后的 stack-vars。
(define (make-update-stack-func translate-stack-vars remaining-stack)
  (lambda ()
    (set! stack-vars
          (foldl (lambda (x acc)
                   (append acc (translate-stack-vars x)))
                 stack-vars
                 remaining-stack))
    ))

;; --- 定义全局的翻译函数和待处理列表 ---
;; 初始版本：对输入数字乘以2，并以列表返回；待处理列表为 (1 2 3)
(define double-translate (lambda (x) (list (* 2 x))))
(define test-remaining-stack (list 1 2 3))

;; 用当前的 double-translate 和 test-remaining-stack 创建闭包
(define update-stack-func
  (make-update-stack-func double-translate test-remaining-stack))

;; --- 第一次调用闭包 ---
(displayln "【第一次调用闭包】")
(displayln "预期：stack-vars 为空，调用后追加 (2 4 6)")
(displayln "初始 stack-vars:")
(displayln stack-vars)   ; 应该为空 '()
(update-stack-func)
;; 此时，stack-vars 由空变为 (2 4 6)

;; --- 修改全局变量 ---
;; 修改全局的 double-translate 和 test-remaining-stack：
;; 分别改为：对输入数字加 100；以及待处理列表改为 (10 20)
(set! double-translate (lambda (x) (list (+ x 100))))
(set! test-remaining-stack (list 10 20))

(displayln "【修改全局变量后，再次调用闭包】")
(displayln "注意：闭包内捕获的 translate-stack-vars 和 remaining-stack 已经固定为最初传入的版本")
(displayln "全局 double-translate 和 test-remaining-stack 已修改，但不会影响闭包")
(displayln "当前全局 double-translate 对 1 的计算结果为：")
(displayln ((lambda (x) double-translate) 1))  ; 实际上返回的是函数本身，这里只是表明全局绑定已变
(displayln "当前全局 test-remaining-stack 为：")
(displayln test-remaining-stack)  ; 应该显示 (10 20)

;; --- 再次调用闭包 ---
;; 由于闭包在创建时捕获了原来的 double-translate 和 test-remaining-stack，
;; 此次调用仍然使用“乘以2”以及 (1 2 3) 这两个值，
;; 而全局变量 stack-vars 此时为 (2 4 6)，调用后将追加 (2 4 6)。
(update-stack-func)
;; 最终输出的 stack-vars 应该为 (2 4 6 2 4 6)
