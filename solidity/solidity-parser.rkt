#lang racket

(require parser-tools/lex
         (prefix-in re- parser-tools/lex-sre)
         parser-tools/yacc
	 "../parser.rkt" "../inst.rkt")

(provide solidity-parser%)

;; This is a Racket Lex Yacc parser.
;; Refer to the follow resources to complete this file.
;; - Lexer:   http://docs.racket-lang.org/parser-tools/Lexers.html
;; - Parser:  http://docs.racket-lang.org/parser-tools/LALR_1__Parsers.html
;; - Example: https://gist.github.com/danking/1068185
(define solidity-parser%
  (class parser%
    (super-new)
    (inherit-field asm-parser asm-lexer)
    (init-field [compress? #f])
    
    (define-tokens a (VAR WORD NUM REG CONTR)) ;; add more tokens
    (define-empty-tokens b (EOF EQ HOLE BLOCKHASH EQCMP COMMA CREATE THROW THROWI NOP LOG BALANCE SELFBALANCE ISZERO SGT GT SLT LT SHA3 DELEGATECALL CALLCODE CALL STATICCALL NOT OR
                            SELFDESTRUCT MSIZE NUMBER CALLDATACOPY CODECOPY SUB TIMESTAMP EXP DIV SDIV RETURNDATACOPY MUL AND ADD REVERT STOP RETURNDATASIZE
                            CODESIZE EXTCODECOPY EXTCODEHASH EXTCODESIZE MOD SMOD ADDMOD MULMOD XOR DIFFICULTY BYTE SHR SHL SAR SIGNEXTEND
                            RETURN COLON ORIGIN CALLVALUE JUMP JUMPI SLP LC RC LP LP8 RP ADDRESS CALLDATASIZE CALLDATALOAD)) ;; add more tokens

    (define-lex-abbrevs
      (digit10 (char-range "0" "9"))
      (number10 (number digit10))
      (snumber10 (re-or number10 (re-seq "-" number16)))
      (number16 (re-or (char-range "0" "9") (char-range "a" "f")))

      (snumber16 (re-+ "0x" number16))

      (identifier-characters (re-or (char-range "A" "Z") (char-range "a" "z")))
      (identifier-characters-ext (re-or digit10 identifier-characters "_"))
      (identifier (re-seq identifier-characters 
                          (re-* (re-or identifier-characters digit10))))
      (var (re-: "%" (re-+ (re-or identifier-characters digit10))))
      (reg (re-seq (re-or "V" "S") number10))
      (contr (re-: "CALL" (re-+ (re-or identifier-characters digit10))))

      )

    ;; Complete lexer
    (set! asm-lexer
      (lexer-src-pos
       ; ? ;; add more tokens
       ("M["         (token-LP))
       ("M8["         (token-LP8))
       ("S["         (token-SLP))
       ("]"         (token-RP))
       ("}"         (token-RC))
       ("{"         (token-LC))
       ("LT"         (token-LT))
       ("SLT"         (token-SLT))
       ("GT"         (token-GT))
       ("SGT"         (token-SGT))
       (":"         (token-COLON))
       ("ADD"       (token-ADD))
       ("BYTE"       (token-BYTE))
       ("XOR"       (token-XOR))
       ("SHR"       (token-SHR))
       ("SHL"       (token-SHL))
       ("SAR"       (token-SAR))
       ("MOD"       (token-MOD))
       ("SMOD"       (token-SMOD))
       ("ADDMOD"       (token-ADDMOD))
       ("MULMOD"       (token-MULMOD))
       ("NOT"       (token-NOT))
       ("OR"       (token-OR))
       ("AND"       (token-AND))
       ("DIV"       (token-DIV))
       ("SDIV"       (token-SDIV))
       ("MUL"       (token-MUL))
       ("REVERT"       (token-REVERT))
       ("SUB"       (token-SUB))
       ("CREATE"       (token-CREATE))
       ("EXP"       (token-EXP))
       ("SELFDESTRUCT" (token-SELFDESTRUCT))
       ("CALLVALUE"  (token-CONTR lexeme))
       ("MSIZE"  (token-CONTR lexeme))
       ("NUMBER"  (token-CONTR lexeme))
       ("ORIGIN"  (token-CONTR lexeme))
       ("GAS"  (token-CONTR lexeme))
       ("COINBASE"  (token-CONTR lexeme))
       ("DIFFICULTY"  (token-CONTR lexeme))
       ("GASPRICE"  (token-CONTR lexeme))
       ("GASLIMIT"  (token-CONTR lexeme))
       ("TIMESTAMP"  (token-CONTR lexeme))
       ("ADDRESS"  (token-CONTR lexeme))
       ("RETURNDATASIZE"  (token-CONTR lexeme))
       ("CODESIZE"  (token-CONTR lexeme))
       ("RETURNDATACOPY"  (token-RETURNDATACOPY))
       ("CALLDATASIZE"  (token-CONTR lexeme))
       ("CALLDATALOAD"  (token-CALLDATALOAD))
       ("CODECOPY"         (token-CODECOPY))
       ("EXTCODECOPY"         (token-EXTCODECOPY))
       ("JUMPDEST"  (token-NOP))
       ("INVALID"  (token-REVERT)) ;FIXME: actually revert has return value. This should be changed later
       ("LOG"       (token-LOG))
       ("BALANCE"  (token-BALANCE))
       ("SELFBALANCE"  (token-SELFBALANCE))
       ("BLOCKHASH"  (token-BLOCKHASH))
       ("JUMPI"     (token-JUMPI))
       ("JUMP"     (token-JUMP))
       ("THROWI"     (token-THROWI))
       ("THROW"     (token-THROW))
       ("SHA3"     (token-SHA3))
       ("SIGNEXTEND"     (token-SIGNEXTEND))
       ("EXTCODESIZE"   (token-EXTCODESIZE))
       ("EXTCODEHASH"   (token-EXTCODEHASH))
       ("CALL"     (token-CALL))
       ("STATICCALL"     (token-STATICCALL))
       ("CALLCODE"   (token-CALLCODE))
       ("DELEGATECALL" (token-DELEGATECALL))
       ("CALLDATACOPY" (token-CALLDATACOPY))
       ("ISZERO"    (token-ISZERO))
       ("RETURN"    (token-RETURN))
       ("STOP"    (token-STOP))
       ("NOP"    (token-NOP))
       ("EQ"         (token-EQCMP))
       ("="         (token-EQ))
       ("?"         (token-HOLE))
       (","         (token-COMMA))
       (reg         (token-REG lexeme))
       (contr       (token-CONTR lexeme))
       (snumber10   (token-NUM lexeme))
       (snumber16   (token-NUM lexeme))
       (identifier  (token-WORD lexeme))
       (whitespace   (position-token-token (asm-lexer input-port)))
       ((eof) (token-EOF))))

    ;; Complete parser
    (set! asm-parser
      (parser
       (start program)
       (end EOF)
       (error
        (lambda (tok-ok? tok-name tok-value start-pos end-pos)
          (raise-syntax-error 'parser
                              (format "syntax error at '~a' in src l:~a c:~a"
                                      tok-name
                                      (position-line start-pos)
                                      (position-col start-pos)))))
       (tokens a b)
       (src-pos)
       (grammar

        ; ? ;; add more grammar rules
        (arg  ((REG) $1)
              ((NUM) $1))

        (args ((arg) (list $1))
              ((arg args) (cons $1 $2))
              ((arg COMMA args) (cons $1 $3)))
        (call-params 
          ((arg arg arg arg arg arg arg) (list $1 $2 $3 $4 $5 $6 $7)))
        (instruction
          ((NUM COLON WORD args)    (inst $3 (list->vector $4)))
         ;; when parsing ?, return (inst #f #f) as an unknown instruction
         ;; (a place holder for synthesis)
        ((HOLE)         (inst #f #f))
          ((NUM COLON REG EQ LT arg arg) (inst "lt" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ SLT arg arg) (inst "slt" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ GT arg arg) (inst "gt" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ SGT arg arg) (inst "sgt" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ SUB arg arg) (inst "sub" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ ADD arg arg) (inst "add" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ XOR arg arg) (inst "xor" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ SHR arg arg) (inst "shr" (vector $1 $3 $7 $6))); because evm input shift, value and output value op shift
          ((NUM COLON REG EQ SHL arg arg) (inst "shl" (vector $1 $3 $7 $6))); because evm input shift, value and output value op shift
          ((NUM COLON REG EQ SAR arg arg) (inst "sar" (vector $1 $3 $7 $6))); because evm input shift, value and output value op shift
          ((NUM COLON REG EQ MOD arg arg) (inst "mod" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ SMOD arg arg) (inst "smod" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ ADDMOD arg arg arg arg) (inst "addmod" (vector $1 $3 $6 $7 $8)))
          ((NUM COLON REG EQ MULMOD arg arg arg arg) (inst "mulmod" (vector $1 $3 $6 $7 $8)))
          ((NUM COLON REG EQ DIV arg arg) (inst "div" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ SDIV arg arg) (inst "sdiv" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ MUL arg arg) (inst "mul" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ SHA3 arg arg) (inst "sha3" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ AND arg arg) (inst "and" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ OR arg arg) (inst "or" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ EXP arg arg) (inst "exp" (vector $1 $3 $6 $7)))
          ((NUM COLON REG EQ EQCMP arg arg) (inst "eqcmp" (vector $1 $3 $6 $7)))


    ;;; ((NUM COLON REG EQ CALL call-params)
    ;;;  (inst "call"
    ;;;        (vector $1   ; 原始的 NUM
    ;;;                $3   ; REG
    ;;;                ;; 这里把 call-params 列表中的各个元素依次取出
    ;;;                (list-ref $6 0) ; gas
    ;;;                (list-ref $6 1) ; address
    ;;;                (list-ref $6 2) ; value
    ;;;                (list-ref $6 3) ; argsOffset
    ;;;                (list-ref $6 4) ; argsLength
    ;;;                (list-ref $6 5) ; retOffset
    ;;;                (list-ref $6 6)))) ; retLength
          
          ((NUM COLON REG EQ CALL arg arg arg arg arg arg arg) (inst "call" (vector $1 $3 $6 $7 $8 $9 $10 $11 $12)))
          ((NUM COLON REG EQ STATICCALL arg arg arg arg arg arg) (inst "staticcall" (vector $1 $3 $6 $7 $8 $9 $10 $11)))
          ((NUM COLON REG EQ DELEGATECALL arg arg arg arg arg arg) (inst "delegatecall" (vector $1 $3 $6 $7 $8 $9 $10 $11)))
          ((NUM COLON REG EQ LP arg RP) (inst "load" (vector $1 $3 $6)))
          ((NUM COLON LP arg RP EQ arg) (inst "store" (vector $1 $4 $7)))
          ((NUM COLON LP8 arg RP EQ arg) (inst "store8" (vector $1 $4 $7)))
          ((NUM COLON REG EQ SLP arg RP) (inst "sload" (vector $1 $3 $6)))
          ((NUM COLON SLP arg RP EQ arg) (inst "sstore" (vector $1 $4 $7)))
          ((NUM COLON REG EQ CALLDATALOAD arg) (inst "calldataload" (vector $1 $3 $6))) ; FIXME!!
          ; ((NUM COLON REG EQ CALLVALUE) (inst "eq#" (vector $1 $3)))
          ((NUM COLON REG EQ CONTR) (inst "eq#" (vector $1 $3 $5)))
          ((NUM COLON REG EQ NUM) (inst "eq#" (vector $1 $3 $5)))
          ((NUM COLON REG EQ REG) (inst "eq" (vector $1 $3 $5)))
          ((NUM COLON REG EQ LC NUM COMMA NUM COMMA NUM RC) (inst "eq#" (vector $1 $3 $6)))
          ((NUM COLON REG EQ LC NUM COMMA NUM COMMA NUM COMMA NUM RC) (inst "eq#" (vector $1 $3 $6)))
          ((NUM COLON REG EQ LC NUM COMMA NUM RC) (inst "eq#" (vector $1 $3 $6)))
          ((NUM COLON REG EQ ISZERO arg) (inst "iszero" (vector $1 $3 $6)))
          ((NUM COLON REG EQ ISZERO LC arg COMMA arg RC) (inst "iszero" (vector $1 $3 $7)))
          ((NUM COLON REG EQ BLOCKHASH arg) (inst "blockhash" (vector $1 $3 $6))) 
          ((NUM COLON REG EQ BALANCE arg) (inst "balance" (vector $1 $3 $6))) 
          ((NUM COLON REG EQ SELFBALANCE) (inst "selfbalance" (vector $1 $3))) 
          ((NUM COLON RETURNDATACOPY arg arg arg) (inst "returndatacopy" (vector $1 $4 $5 $6)))
          ((NUM COLON REG EQ NOT arg) (inst "snot" (vector $1 $3 $6)))
          ((NUM COLON CODECOPY arg arg arg)      (inst "codecopy" (vector $1 $4 $5 $6)))
          ((NUM COLON EXTCODECOPY arg arg arg arg)      (inst "nop" (vector $1)))
          ((NUM COLON REVERT arg arg)        (inst "revert" (vector $1 $4 $5))) ;FIXME: haven't implement return value
          ((NUM COLON STOP)        (inst "stop" (vector $1)))
          ((NUM COLON RETURN arg arg)        (inst "return" (vector $1 $4 $5))) ;FIXME: haven't implement return value
          ((NUM COLON LOG arg arg arg)          (inst "nop" (vector $1)))
          ((NUM COLON LOG arg arg arg arg)          (inst "nop" (vector $1)))
          ((NUM COLON LOG arg arg arg arg arg)          (inst "nop" (vector $1)))
          ((NUM COLON LOG args)          (inst "nop" (vector $1)))
          ((NUM COLON NOP)        (inst "nop" (vector $1))) 
          ((NUM COLON JUMPI arg REG) (inst "jumpi" (vector $1 $4 $5)))
          ((NUM COLON THROWI REG) (inst "throw" (vector $1 $4)))
          ((NUM COLON THROW) (inst "revert" (vector $1))) ;FIXME: haven't implement return value
          ((NUM COLON THROW NUM) (inst "revert" (vector $1))) ;FIXME: haven't implement return value
          ((NUM COLON JUMP arg) (inst "jump" (vector $1 $4)))
          ((NUM COLON REG EQ CREATE NUM REG arg) (inst "create" (vector $1 $3 $6 $7 $8)))
          ((NUM COLON REG EQ EXTCODESIZE arg) (inst "extcodesize" (vector $1 $3 $6)))
          ((NUM COLON REG EQ EXTCODEHASH arg) (inst "extcodehash" (vector $1 $3 $6)))
          ((NUM COLON EXTCODECOPY arg arg arg arg) (inst "extcodecopy" (vector $1 $4 $5 $6 $7)))
          ((NUM COLON REG EQ SIGNEXTEND arg arg) (inst "signextend" (vector $1 $3 $6 $7)))
          ((NUM COLON CALLDATACOPY arg arg arg) (inst "calldatacopy" (vector $1 $4 $5 $6))) ;;FIXME:
          ((NUM COLON REG EQ BYTE NUM REG) (inst "byte" (vector $1 $3 $7 $6)))
          ;; comp_ec2_12_15.txt:"parser error: 0x49d8: V4833 = EQ 0x0 0x0"
          ;; comp_ec2_12_15.txt:"parser error: 0x1511: V2183 = SIGNEXTEND 0x13 V2138"
          ;; comp_ec2_12_15.txt:"parser error: 0x1ed: V124 = CREATE S9 V122 V123"
          ;; comp_ec2_12_15.txt:"parser error: 0x1da: V183 = CREATE S5 V179 V182"
          ;; comp_ec2_12_15.txt:"parser error: 0x8f4: CODECOPY V798 0x0 V786"
          ((NUM COLON SELFDESTRUCT arg) (inst "selfdestruct" (vector $1 $4)))
         ) 
        
        (code   
         (() (list))
         ((instruction code) (cons $1 $2)))

        (program
         ((code) (list->vector $1)))
       )))


    ;;;;;;;;;;;;;;;;;;;;;;;;; For cooperative search ;;;;;;;;;;;;;;;;;;;;;;;
    #|
    ;; Required method if using cooperative search driver.
    ;; Read from file and convert file content into the format we want.
    ;; Info usually includes live-out information.
    ;; It can also contain extra information such as precondition of the inputs.
    (define/override (info-from-file file)
      ? ;; modify this function

      ;; Example
      ;; read from file
      (define lines (file->lines file))
      (define live-out (string-split (first lines) ","))
      live-out)
    |#

    ))

