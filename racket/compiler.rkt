#lang racket
(require racket/set racket/stream racket/fixnum racket/match racket/promise)
(require "utilities.rkt")
(require "interp.rkt")
(require "interp-Rvar.rkt")
(require "interp-Cvar.rkt")
(require "type-check-Rvar.rkt")
(require "type-check-Cvar.rkt")
(require "runtime-config.rkt")

(provide compiler-passes compile-Rvar)

(define compile-Rvar
  (class object%
    (super-new)

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Challenge exercise: partial evaluator (simple version)
    
    (define (pe-neg r)
      (match r
        [(Int n) (Int (fx- 0 n))]
        [else (Prim '- (list r))]))
    
    (define (pe-add r1 r2)
      (match* (r1 r2)
        [((Int n1) (Int n2)) (Int (fx+ n1 n2))]
        [(_ _) (Prim '+ (list r1 r2))]))
    
    (define/public (pe-exp env)
      (lambda (e)
        (debug "Rvar/pe-exp: " e)
        (match e
          [(Var x) (lookup x env e)]
          [(Int n) (Int n)]
          [(Prim 'read '()) (Prim 'read '())]
          [(Prim '- (list e1)) (pe-neg ((pe-exp env) e1))]
          [(Prim '+ (list e1 e2)) (pe-add ((pe-exp env) e1) ((pe-exp env) e2))]
          [(Let x e body)
           (let ([r ((pe-exp env) e)])
             (match r
               [(or (Int _) (Var _))
                ((pe-exp (dict-set env x r)) body)]
               [else
                (Let x r ((pe-exp env) body))]))]
          [else (error "pe-exp unmatched: " e)])))
    
    (define/public (partial-eval p)
      (match p
        [(Program info e)
         (cond [(optimize)
                (define new-e ((pe-exp '()) e))
                (debug "Rvar/partial-eval: " new-e)
                (Program info new-e)]
               [else (Program info e)])]))

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
    ;; uniquify-exp : env -> exp -> exp
    (define/public (uniquify-exp env)
      (lambda (e)
        (copious "uniquify-exp: " e)
	(define recur (uniquify-exp env))
	(match e
          [(Var x) (Var (dict-ref env x))]
          [(Int n) (Int n)]
          [(Let x rhs body)
           (define new-rhs (recur rhs))
           (define new-x (gensym (racket-id->c-id x)))
           (Let new-x new-rhs
                ((uniquify-exp (dict-set env x new-x)) body))]
          [(Prim op args)
           (Prim op (for/list ([arg args]) (recur arg)))]
          [else (error "uniquify-exp couldn't match" e)]
          )))
    
    ;; uniquify : Rvar -> Rvar
    (define/public (uniquify e)
      (match e
        [(Program info body) (Program info ((uniquify-exp '()) body))]
        [else (error "uniquify couldn't match" e)]))

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Challenge exercise: improved partial evaluator

    (define (ipe-neg r)
      (match r
        [(Int n) (Int (fx- 0 n))]
        [(Prim '+ (list e1 e2)) ;; - (e1 + e2) = (- e1) + (- e2)
         (ipe-add (ipe-neg e1) (ipe-neg e2))]
        [(Prim '- (list e)) e]  ;; - (- e) = e
        [else (Prim '- (list r))]))

    (define (ipe-add r1 r2)
      (match r1
        [(Int n1)
         (match r2
           [(Int n2) (Int (fx+ n1 n2))]
           [(Prim '+ (list (Int n2) e)) ;; n1 + (n2 + e) = (n1 + n2) + e
            (Prim '+ (list (Int (+ n1 n2)) e))]
           [else (Prim '+ (list r1 r2))])]
        [(Prim '+ (list (Int n1) e1))
         (match r2
           [(Int n2) ;; (n1 + e1) + n2 = (n1 + n2) + e1
            (Prim '+ (list (Int (fx+ n1 n2)) e1))]
           [(Prim '+ (list (Int n2) e2))
            ;; (n1 + e1) + (n2 + e2) = (n1 + n2) + (e1 + e2)
            (Prim '+ (list (Int (fx+ n1 n2)) (Prim '+ (list e1 e2))))]
           [else ;; (n1 + e1) + r2 = n1 + (e1 + r2)
            (Prim '+ (list (Int n1) (Prim '+ (list e1 r2))))])]
        [else
         (match r2
           [(Int n2) ;; r1 + n2 = n2 + r1
            (Prim '+ (list (Int n2) r1))]
           [(Prim '+ (list (Int n2) e2)) ;; r1 + (n2 + e2) = n2 + (r1 + e2)
            (Prim '+ (list (Int n2) (Prim '+ (list r1 e2))))]
           [else (Prim '+ (list r1 r2))])]))

    (define (inert? e)
      (match e
        [(Var x) #t]
        [(Prim 'read '()) #t]
        [(Prim '- (list (Var x))) #t]
        [(Prim '- (list (Prim 'read '()))) #t]
        [(Prim '+ (list e1 e2)) (and (inert? e1) (inert? e2))]
        [(Let x e1 e2) (and (residual? e1) (residual? e2))]
        [else #f]))

    (define (residual? e)
      (match e
        [(Int n) #t]
        [(Prim '+ (list (Int n) i)) (inert? i)]
        [else (inert? e)]))
    
    (define/public (ipe-exp env)
      (lambda (e)
        (let ([result
               (match e
                 [(Var x) (lookup x env e)]
                 [(Int n) (Int n)]
                 [(Prim 'read '()) (Prim 'read '())]
                 [(Prim '- (list e1)) (ipe-neg ((ipe-exp env) e1))]
                 [(Prim '+ (list e1 e2))
                  (ipe-add ((ipe-exp env) e1) ((ipe-exp env) e2))]
                 [(Let x e1 e2)
                  (define r1 ((ipe-exp env) e1))
                  (match r1
                    [(Int n1) ((ipe-exp (dict-set env x r1)) e2)]
                    [(Var y) ((ipe-exp (dict-set env x r1)) e2)]
                    [else
                     (define r2 ((ipe-exp env) e2))
                     (Let x r1 r2)])])])
          (debug "ipe-exp" e result)
          (cond [(residual? result) result]
                [else (error 'ipe-exp "not in residual form ~a" result)]))))

    (define/public (improved-partial-eval p)
      (match p
        [(Program info e)
         (cond [(optimize) (Program info ((ipe-exp '()) e))]
               [else (Program info e)])]))
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;; rco-atom : exp -> exp * (var * exp) list
    (define/public (rco-atom e)
      (define-values (result ss)
      (match e
        [(Var x) (values (Var x) '())]
        [(Int n) (values (Int n) '())]
        [(Let x rhs body)
         (define new-rhs (rco-exp rhs))
         (define-values (new-body body-ss) (rco-atom body))
         (values new-body (append `((,x . ,new-rhs)) body-ss))]
        [(Prim op es) 
         (define-values (new-es sss)
           (for/lists (l1 l2) ([e es]) (rco-atom e)))
         (define ss (append* sss))
         (define tmp (gensym 'tmp))
         (values (Var tmp)
                 (append ss `((,tmp . ,(Prim op new-es)))))]
        [else (error "Rvar/rco-atom unhandled match case" e)]))
      (verbose "Rvar/rco-atom" e result)
      (values result ss))

    ;; rco-exp : exp -> exp
    (define/public (rco-exp e)
      (define result
      (match e
        [(Var x) (Var x)]
        [(Int n) (Int n)]
        [(Let x rhs body)
         (Let x (rco-exp rhs) (rco-exp body))]
        [(Prim op es)
         (define-values (new-es sss)
           (for/lists (l1 l2) ([e es]) (rco-atom e)))
         (make-lets (append* sss) (Prim op new-es))]
        [else (error "Rvar/rco-exp unhandled match case" e)]))
      (verbose "Rvar/rco-exp" e result)
      result)

    ;; remove-complex-opera* : Rvar -> Rvar
    (define/public (remove-complex-opera* p)
      (match p
        [(Program info e) (Program info (rco-exp e))]))

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    (define/public (basic-exp? e)
      (match e
        [(or (Var _) (Int _)) #t]
        [(Prim op arg*) #t]
        [else #f]))

    ;; explicate-tail : exp -> tail
    (define/public (explicate-tail e)
      (match e
        [(? basic-exp?) (Return e)]
        [(Let x rhs body) (explicate-assign rhs x (explicate-tail body))]
        [else (error "explicate-tail unhandled match case" e)]))

    ;; explicate-assign : exp * var * tail -> tail
    (define/public (explicate-assign e x cont-block)
      (match e
        [(? basic-exp?) (Seq (Assign (Var x) e) cont-block)]
        [(Let y rhs body)
         (define new-body (explicate-assign body x cont-block))
         (explicate-assign rhs y new-body)]
        [else (error "Rvar/explicate-assign unhandled match case" e)]))

    ;; explicate-control : Rvar -> Cvar
    (define/public (explicate-control p)
      (match p
        [(Program info body)
         (define new-body (explicate-tail body))
         (CProgram info (list (cons 'start new-body)))]))
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; select-instructions : Cvar -> psuedo-x86

    (define/public (binary-op->inst op)
      (match op
         ['+ 'addq]
	 [else (error "in binary-op->inst unmatched" op)]))

    (define/public (unary-op->inst op)
      (match op
        ['- 'negq] [else (error "in unary-op->inst unmatched" op)]))

    (define/public (commutative? op)
      (match op
         ['+ #t]
         [else #f]))

    ;; select-instr-arg : arg -> imm
    (define/public (select-instr-arg e)
      (verbose 'select-instr "arg" e)
      (match e
        [(Var x) (Var x)]
        [(Int n) (Imm n)]
        [(Reg r) (Reg r)] ;; This makes (Return e) below easier. -Jeremy
        [else (error "Rvar/select-instr-arg unhandled case in match" e)]))

    ;; select-instr-stmt : stmt -> instr list
    (define/public (select-instr-stmt e)
      (verbose 'select-instr "stmt" e)
      (match e
        [(Assign lhs (Prim 'read '()))
         (define new-lhs (select-instr-arg lhs))
         (list (Callq 'read_int 0)
               (Instr 'movq (list (Reg 'rax) new-lhs)))]
        [(Assign lhs (Var x))
         (define new-lhs (select-instr-arg lhs))
         (cond [(equal? (Var x) new-lhs) '()]
               [else (list (Instr 'movq (list (Var x) new-lhs)))])]
        [(Assign lhs (Int n))
         (define new-lhs (select-instr-arg lhs))
         (list (Instr 'movq (list (Imm n) new-lhs)))]
        [(Assign lhs (Prim op (list e1 e2)))
         (define new-lhs (select-instr-arg lhs))
         (define new-e1 (select-instr-arg e1))
         (define new-e2 (select-instr-arg e2))
         (define inst (binary-op->inst op))
         (cond [(equal? new-e1 new-lhs)
                (list (Instr inst (list new-e2 new-lhs)))]
               [(and (commutative? op) (equal? new-e2 new-lhs))
                (list (Instr inst (list new-e1 new-lhs)))]
               ;; The following can shorten the live range of e2. -JGS
               [(and (commutative? op) (integer? e1) (symbol? e2))
                (list (Instr 'movq (list new-e2 new-lhs))
                      (Instr inst (list new-e1 new-lhs)))]
               [else (list (Instr 'movq (list new-e1 new-lhs))
                           (Instr inst (list new-e2 new-lhs)))])]
        [(Assign lhs (Prim op (list e1)))
         (define new-lhs (select-instr-arg lhs))
         (define new-e1 (select-instr-arg e1))
         (define inst (unary-op->inst op))
         (cond [(equal? new-e1 new-lhs)
                (list (Instr inst (list new-lhs)))]
               [else (list (Instr 'movq (list new-e1 new-lhs))
                           (Instr inst (list new-lhs)))])]
        [else (error "Rvar/select-instr-stmt unhandled case in match" e)]))

    ;; select-instr-tail : tail -> instr list
    (define/public (select-instr-tail t)
      (verbose 'select-instr "tail" t)
      (match t
        [(Return e)
         (append (select-instr-stmt (Assign (Reg 'rax) e))
                 (list (Jmp 'conclusion)))]
        [(Seq s t2)
         (append (select-instr-stmt s) (select-instr-tail t2))]
        [else (error "Rvar/select-instr-tail unhandled case in match" t)]))

    (define/public (select-instructions p)
      (verbose 'select-instr "program" p)
      (match p
        [(CProgram info blocks)
         (define new-blocks
           (for/list ([(label tail) (in-dict blocks)])
             (cons label (Block '() (select-instr-tail tail)))))
         (X86Program info new-blocks)]
        [else (error "Rvar/select-instructions, unmatched " p)]))

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; assign-homes : homes -> pseudo-x86 -> pseudo-x86
    ;;
    ;; Replace variables with stack locations. Later versions of this pass
    ;; will assign some variables to registers. 

    (define/public (variable-size) 8)

    (define/public (first-offset num-callee-used)
      (* 1 (variable-size)))

    (define/public (instructions)
      (set 'addq 'subq 'negq 'movq))

    ;; assign-homes-imm :: imm -> imm
    (define/public (assign-homes-imm homes)
      (lambda (e)
	(match e
          [(Var x) (hash-ref homes x)]
          [(Imm n) (Imm n)]
          [(Reg r) (Reg r)]
          [(Deref r n) (Deref r n)]
          [else
           (error "Rvar/assign-homes-imm unhandled match case" e)])))

    ;; assign-homes-instr :: (hashmap var imm) -> instr -> instr
    (define/public (assign-homes-instr homes)
      (lambda (e)
        (verbose "Rvar/assign-homes-instr" e)
	(match e
          [(Callq f n) (Callq f n)]
          [(Jmp label) (Jmp label)]
          [(Instr instr-name as)
           (Instr instr-name (map (assign-homes-imm homes) as))]
          [else (error "Rvar/assign-homes-instr unmatched" e)])))
  
    (define/public (assign-homes-block homes)
      (lambda (e)
        (verbose "Rvar/assign-homes-block" e)
	(match e
          [(Block info ss) (Block info (map (assign-homes-instr homes) ss))]
          [else (error "Rvar/assign-homes-block unmatched" e)])))

    (define/public (assign-homes e)
      (verbose "assign-homes" e)
      (match e
        [(X86Program info blocks)
         (define locals (dict-keys (dict-ref info 'locals-types)))
         (define (make-stack-loc i)
           (Deref 'rbp (- (+ (first-offset 0) (* (variable-size) i)))))
         (define homes
           (for/hash ([x locals] [i (in-range 0 (length locals))])
             (values x (make-stack-loc i))))
         (define new-blocks
           (for/list ([(label block) (in-dict blocks)])
             (cons label ((assign-homes-block homes) block))))
         (define stack-space (align (* (length locals) (variable-size)) 16))
         (define new-info `((stack-space . ,stack-space)))
         (X86Program new-info new-blocks)]
        [else (error "Rvar/assign-homes, unmatched" e)]))
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; patch-instructions : psuedo-x86 -> x86
    ;; Uses register rax to patch things up

    (define/public (in-memory? a)
      (match a
        [(Deref reg n) #t]
        [else #f]))
    
    (define/public (patch-instr e)
      (match e
        ;; Large integers cannot be moved directly to memory. -andre 
        [(Instr 'movq (list (Imm n) (? in-memory? d)))
         #:when (> n (expt 2 32))
         (list (Instr 'movq (list (Imm n) (Reg 'rax)))
               (Instr 'movq (list (Reg 'rax) d)))]
        [(Instr 'movq (list s d))
         (cond [(equal? s d) '()] ;; trivial move, delete it
               [(and (in-memory? s) (in-memory? d))
                (list (Instr 'movq (list s (Reg 'rax)))
                      (Instr 'movq (list (Reg 'rax) d)))]
               [else (list (Instr 'movq (list s d)))])]
        [(Callq f n) (list (Callq f n))]
        [(Jmp label) (list (Jmp label))]
        [(Instr instr-name (list s d))
         (cond [(and (in-memory? s) (in-memory? d))	
                (debug 'patch-instr "spilling")
                (list (Instr 'movq (list s (Reg 'rax)))
                      (Instr instr-name (list (Reg 'rax) d)))]
               [else (list (Instr instr-name (list s d)))])]
        [(Instr instr-name (list d))
         (list (Instr instr-name (list d)))]
        ))
  
    (define/public (patch-block e)
      (match e
        [(Block info ss)
         (Block info (append* (map (lambda (s) (patch-instr s)) ss)))]
        [else
         (error "Rvar/patch-block unhandled" e)]))

    (define/public (patch-instructions e)
      (match e
        [(X86Program info blocks)
         (define new-blocks
           (for/list ([(label block) (in-dict blocks)])
             (cons label (patch-block block))))
         (X86Program info new-blocks)]
        ))
  
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; print-x86 : x86 -> string

    (define/public (print-x86-imm e)
      (match e
        [(Deref reg i)
         (format "~a(%~a)" i reg)]
        [(Imm n) (format "$~a" n)]
        [(Reg r) (format "%~a" r)]))
    
    (define/public (print-x86-instr e)
      (verbose "Rvar/print-x86-instr" e)
      (match e
        [(Callq f n)
         (format "\tcallq\t~a\n" (label-name (symbol->string f)))]
        [(Jmp label) (format "\tjmp ~a\n" (label-name label))]
        [(Instr instr-name (list s d))
         (format "\t~a\t~a, ~a\n" instr-name
                 (print-x86-imm s) 
                 (print-x86-imm d))]
        [(Instr instr-name (list d))
         (format "\t~a\t~a\n" instr-name (print-x86-imm d))]
        [else (error "Rvar/print-x86-instr, unmatched" e)]))
    
    (define/public (print-x86-block e)
      (match e
        [(Block info ss)
         (string-append* (for/list ([s ss]) (print-x86-instr s)))]
        [else (error "Rvar/print-x86-block unhandled " e)]))

    (define/public (print-x86 e)
      (match e
        [(X86Program info blocks)
         (define stack-space (lookup 'stack-space info))
         (string-append
          (string-append*
           (for/list ([(label block) (in-dict blocks)])
             (string-append (format "~a:\n" (label-name label))
                            (print-x86-block block))))
          "\n"
          (format "\t.globl ~a\n" (label-name "main"))
          (format "~a:\n" (label-name "main"))
          (format "\tpushq\t%rbp\n")
          (format "\tmovq\t%rsp, %rbp\n")
          (format "\tsubq\t$~a, %rsp\n" stack-space)
          (format "\tjmp ~a\n" (label-name 'start))
          (format "~a:\n" (label-name 'conclusion))
          (format "\taddq\t$~a, %rsp\n" stack-space)
          (format "\tpopq\t%rbp\n")
          (format "\tretq\n")
          )]
        [else (error "print-x86, unmatched" e)]
        ))
    
    )) ;; class compile-Rvar

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Description of Compiler Passes

(define compiler-passes
  (let ([compiler (new compile-Rvar)])
    (list 
     `("uniquify"
       ,(lambda (p) (send compiler uniquify p))
       ,interp-Rvar
       ,type-check-Rvar)
     `("partial-eval"
       ,(lambda (p) (send compiler improved-partial-eval p))
       ,interp-Rvar)
     `("remove-complex-opera*"
       ,(lambda (p) (send compiler remove-complex-opera* p))
       ,interp-Rvar
       ,type-check-Rvar)
     `("explicate-control"
       ,(lambda (p) (send compiler explicate-control p))
       ,interp-Cvar
       ,type-check-Cvar)
     `("select-instructions"
       ,(lambda (p) (send compiler select-instructions p))
       ,interp-pseudo-x86-0)
     `("assign-homes"
       ,(lambda (p) (send compiler assign-homes p))
       ,interp-x86-0)
     `("patch-instructions"
       ,(lambda (p) (send compiler patch-instructions p))
       ,interp-x86-0)
     `("print x86"
       ,(lambda (p) (send compiler print-x86 p))
       #f)
     )))
