#lang racket
(require racket/set racket/stream)
(require racket/fixnum)
(require racket/dict)
(require "interp-Rint.rkt")
(require "interp-Rvar.rkt")
(require "interp-Cvar.rkt")
(require "interp.rkt")
(require "utilities.rkt")
(require "priority_queue.rkt")
(require "type-check-Cvar.rkt")
(require rackunit)
(require graph)
(provide (all-defined-out))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Rint examples
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; The following compiler pass is just a silly one that doesn't change
;; anything important, but is nevertheless an example of a pass. It
;; flips the arguments of +. -Jeremy
(define (flip-exp e)
  (match e
    [(Var x) e]
    [(Prim 'read '()) (Prim 'read '())]
    [(Prim '- (list e1)) (Prim '- (list (flip-exp e1)))]
    [(Prim '+ (list e1 e2)) (Prim '+ (list (flip-exp e2) (flip-exp e1)))]))

(define (flip-Rint e)
  (match e
    [(Program info e) (Program info (flip-exp e))]))


;; Next we have the partial evaluation pass described in the book.
(define (pe-neg r)
  (match r
    [(Int n) (Int (fx- 0 n))]
    [else (Prim '- (list r))]))

(define (pe-add r1 r2)
  (match `(,r1 ,r2)
    [`(,(Int n1) ,(Int n2)) (Int (fx+ n1 n2))]
    [(or `(,(Int n) ,other)
         `(,other ,(Int n))) (pe-add-reduce (Prim '+ (list (Int n) other)))]
    [`(,_ ,_) (Prim '+ (list r1 r2))]))

(define (pe-add-reduce add-expr)
  (match add-expr
    [(Prim '+ (list (Int n-out) (Prim '+ (list (Int n-in) other))))
     (Prim '+ (list (Int (fx+ n-out n-in)) other))]
    [(Prim '+ (list (Int n) other)) (Prim '+ (list (Int n) other))]))

(define (pe-exp env) ;To support variable bindings, add a parameter for the environment
  (lambda (e)
    (match e
      [(Int n) (Int n)]
      [(Prim 'read '()) (Prim 'read '())]
      [(Prim '- (list e1)) (pe-neg ((pe-exp env) e1))]
      [(Prim '+ (list e1 e2)) (pe-add ((pe-exp env) e1) ((pe-exp env) e2))]
      [(Let y rhs body) (let ([pe-rhs ((pe-exp env) rhs)]) ;Evaluate the binding first
                          (match pe-rhs
                            [(Int n) ((pe-exp (dict-set env y (Int n))) body)]
                            [else (Let y pe-rhs ((pe-exp env) body))]))]
      [(Var x) (if (dict-has-key? env x) (dict-ref env x) (Var x))])))

(define (partial-evaluator p)
  (match p
    [(Program info e) (Program info ((pe-exp '()) e))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HW1 Passes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(define (uniquify-exp env)
  (lambda (e)
    (match e
      [(Var x)
       ;remember to always return an Expression
       (Var (dict-ref env x))]
      [(Int n) (Int n)]
      [(Let x v body)
       ;use let* so the values can reference one another
       (let* ([u-v ((uniquify-exp env) v)] ;evaluate the definition of the let first
              [u-x (gensym x)] ;generate a unique uninterned symbol with x as a base
              [u-env (dict-set env x u-x)]
              [u-body ((uniquify-exp u-env) body)])
         (Let u-x u-v u-body))]
      [(Prim op es)
       (Prim op (for/list ([e es]) ((uniquify-exp env) e)))])))

;; uniquify : R1 -> R1
(define (uniquify p)
  (match p
    [(Program info e) (Program info ((uniquify-exp '()) e))]))


(define (dict-set-left dict key value)
  (cons (cons key value) dict))

(define (rco-atom e)
  (match e
    [(Var x) (values (Var x) '())]
    [(Int n) (values (Int n) '())]
    [(Let x a body)
     (define-values (body-atm body-tmps) (rco-atom body))
     (define let-tmps (dict-set body-tmps x (rco-exp a)))
     (values body-atm let-tmps)]
    [(Prim 'read '())
     (define r-x (gensym))
     (values (Var r-x) (dict-set '() r-x (Prim 'read '())))]
    [(Prim '- (list e1))
     (define-values (e1-atm e1-tmps) (rco-atom e1))
     (define minus-e1 (gensym '-))
     (values (Var minus-e1) (dict-set-left e1-tmps minus-e1 (Prim '- (list e1-atm))))]
    [(Prim '+ (list e1 e2))
     (define-values (e1-atm e1-tmps) (rco-atom e1))
     (define-values (e2-atm e2-tmps) (rco-atom e2))
     (define plus-e1-e2 (gensym '+))
     (define e1-e2-tmps (append e1-tmps e2-tmps))
     (values (Var plus-e1-e2) (dict-set-left e1-e2-tmps plus-e1-e2 (Prim '+ (list e1-atm e2-atm))))]))

(define (wrap-lets e tmps)
  (for/fold ([wrapped-e e]) ([tmp tmps])
    (match tmp
      [`(,x . ,a) (Let x a wrapped-e)])))


(define (rco-exp e)
  (match e
    [(Var x) (Var x)]
    [(Int n) (Int n)]
    [(Let x a body) (Let x (rco-exp a) (rco-exp body))]
    [(Prim 'read '()) (Prim 'read '())]
    [(Prim '- (list e1))
     (define-values (e1-atm e1-tmps) (rco-atom e1))
     (wrap-lets (Prim '- (list e1-atm)) e1-tmps)]
    [(Prim '+ (list e1 e2))
     (define-values (e1-atm e1-tmps) (rco-atom e1))
     (define-values (e2-atm e2-tmps) (rco-atom e2))
     (define e1-e2-tmps (append e1-tmps e2-tmps))
     (wrap-lets (Prim '+ (list e1-atm e2-atm)) e1-e2-tmps)]
    ))

;; remove-complex-opera* : R1 -> R1
(define (remove-complex-opera* p)
  (match p
    [(Program info e) (Program info (rco-exp e))]
    [else (error "remove-complex-opera* unhandled case" p)]))

(define (explicate-tail e)
  (match e
    [(Var x) (Return (Var x))]
    [(Int n) (Return (Int n))]
    [(Let x rhs body) (explicate-assign rhs x (explicate-tail body))]
    [(Prim op es) (Return (Prim op es))]
    [else (error "explicate-tail unhandled case" e)]))
(define (explicate-assign e x cont)
  (match e
    [(Var y) (Seq (Assign (Var x) (Var y)) cont)]
    [(Int n) (Seq (Assign (Var x) (Int n)) cont)]
    [(Let y rhs body) (explicate-assign rhs y (explicate-assign body x cont))]
    [(Prim op es) (Seq (Assign (Var x) (Prim op es)) cont)]
    [else (error "explicate-assign unhandled case" e)]))

;; explicate-control : R1 -> C0
(define (explicate-control p)
  (match p
    [(Program info body) (CProgram '() `((start . ,(explicate-tail body))))]
    [else (error "explicate-control unhandled case" p)]))

(define (sel-instr-tail tail)
  (match tail
    [(Return expr) (append (sel-instr-assign (Assign (Reg 'rax) expr)) `(,(Jmp 'conclusion)))]
    [(Seq assign tail) (append (sel-instr-assign assign)
                               (sel-instr-tail tail))]
    [else (error "sel-instr-tail unhandled case" tail)]))
(define (sel-instr-assign assign)
  (match assign
    [(Assign var/reg atm) #:when (atm? atm) `(,(Instr 'movq `(,(sel-instr-atm atm) ,var/reg)))]
    [(Assign var/reg (Prim 'read '())) `(,(Callq 'read_int 0)
                                         ,(Instr 'movq `(,(Reg 'rax) ,var/reg)))]
    [(Assign var/reg (Prim '- `(,atm))) `(,(Instr 'movq `(,(sel-instr-atm atm) ,var/reg))
                                          ,(Instr 'negq `(,var/reg)))]
    [(Assign var/reg (Prim '+ `(,var/reg ,atm2))) `(,(Instr 'addq `(,(sel-instr-atm atm2) ,var/reg)))]
    [(Assign var/reg (Prim '+ `(,atm1 ,var/reg))) `(,(Instr 'addq `(,(sel-instr-atm atm1) ,var/reg)))]
    [(Assign var/reg (Prim '+ `(,atm1 ,atm2))) `(,(Instr 'movq `(,(sel-instr-atm atm1) ,var/reg))
                                                 ,(Instr 'addq `(,(sel-instr-atm atm2) ,var/reg)))]
    [else (error "sel-instr-assign unhandled case" assign)]))
(define (sel-instr-atm atm)
  (match atm
    [(Int n) (Imm n)]
    [(Var v) (Var v)]
    [else (error "sel-instr-atm unhandled case" atm)]))

;; select-instructions : C0 -> pseudo-x86
(define (select-instructions p)
  (match p
    [(CProgram info `((,label . ,tail))) (X86Program info `((,label . ,(Block '() (sel-instr-tail tail)))))]
    [else (error "select-instructions unhandled case" p)]))

(define (arg-locations arg)
  (match arg
    [(Imm int) (set)]
    [(Reg reg) (set arg)]
    [(Var var) (set arg)]
    [else (error "arg-locations unhandled case" arg)]))

(define (instr-reads instr)
  (match instr
    [(Instr 'addq `(,a1 ,a2))
     (set-union (arg-locations a1) (arg-locations a2))]
    [(Instr 'subq `(,a1 ,a2))
     (set-union (arg-locations a1) (arg-locations a2))]
    [(Instr 'movq `(,a1 ,a2)) (arg-locations a1)]
    [(Instr 'negq `(,a)) (arg-locations a)]
    ; unsure about pushq, popq, retq, jmp
    [(Instr 'pushq a) (set-union (arg-locations a) (set (Reg 'rsp)))]
    [(Instr 'popq a) (set (Reg 'rsp))]
    [(Retq) (set (Reg 'rsp))]
    [(Jmp l) (set)]
    [(Callq label arity)
     (define argument-passing-registers
       '((Reg 'rdi)
         (Reg 'rsi)
         (Reg 'rdx)
         (Reg 'rcx)
         (Reg 'r8)
         (Reg 'r9)))
     (list->set (take argument-passing-registers arity))]
    [else (error "instr-reads unhandled case" instr)]))

(define (instr-writes instr)
  (match instr
    [(Instr 'addq `(,a1 ,a2)) (arg-locations a2)]
    [(Instr 'subq `(,a1 ,a2)) (arg-locations a2)]
    [(Instr 'movq `(,a1 ,a2)) (arg-locations a2)]
    [(Instr 'negq `(,a)) (arg-locations a)]
    ; unsure about pushq, popq, retq, jmp
    [(Instr 'pushq a) (set (Reg 'rsp))]
    [(Instr 'popq a) (set-union (arg-locations a) (set (Reg 'rsp)))]
    [(Retq) (set (Reg 'rsp))]
    [(Jmp l) (set)]
    [(Callq label arity)
     ; caller saved registers
     (set (Reg 'rax)
          (Reg 'rcx)
          (Reg 'rdx)
          (Reg 'rsi)
          (Reg 'rdi)
          (Reg 'r8)
          (Reg 'r9)
          (Reg 'r10)
          (Reg 'r11))]
    [else (error "instr-writes unhandled case" instr)]))

(define (uncover-live-before instr live-after label->live)
  (match instr
    [(Jmp label) (if (dict-has-key? label->live label)
                     (dict-ref label->live label)
                     (error "uncover-live-before label->live missing label" label))]
    [else (set-union (set-subtract live-after (instr-writes instr))
                     (instr-reads instr))]))

(define (uncover-live-instrs instrs live-after label->live)
  (foldr (λ (i l) (cons (uncover-live-before i (car l) label->live) l)) live-after instrs))

(define (uncover-live-block block label->live)
  (match block
    [(Block info instrs)
     (Block (dict-set info 'live-afters (cdr (uncover-live-instrs instrs `(,(set)) label->live))) instrs)]
    [else (error "uncover-live-block unhandled case" block)]))

(define (uncover-live p)
  (match p
    [(X86Program info blocks)
     (define label->live (dict-set '() 'conclusion (set (Reg 'rax) (Reg 'rsp))))
     (X86Program info (map (λ (b) (cons (car b) (uncover-live-block (cdr b) label->live))) blocks))]
    [else (error "uncover-live unhandled case" p)]))

(define (struct->sym s)
  (match s
    [(Reg r) r]
    [(Var v) v]
    [else (error "struct->sym unhandled case" s)]))

(define (build-interference-instrs instrs live-afters interference-graph)
  (for/list ([i instrs]
             [la live-afters])
    (for* ([d (set->list (instr-writes i))]
           [v (set->list la)])
      (match i
        [(Instr 'movq `(,s ,d))
         (if (or (equal? d v) (equal? s v)) #f (add-edge! interference-graph
                                                          (struct->sym d) (struct->sym v)))]
        [else (if (equal? d v) #f (add-edge! interference-graph
                                             (struct->sym d) (struct->sym v)))]))))

(define (build-interference-blocks blocks)
  (define interference-graph (undirected-graph '()))
  (for ([b blocks])
    (define live-afters (dict-ref (Block-info b) 'live-afters))
    (build-interference-instrs (Block-instr* b) live-afters interference-graph))
  interference-graph)

(define (build-interference p)
  (match p
    [(X86Program info blocks)
     (X86Program (dict-set info 'conflicts (build-interference-blocks (map cdr blocks))) blocks)]
    [else (error "build-interference unhandled case" p)]))

;; returns true iff the instruction is NOT a noop (example of a noop: moving a register to itself)
(define (not-noop? instr)
 (match instr
  [(Instr 'movq (list (Deref reg1 off1) (Deref reg1 off1))) #f]
  [(Instr 'movq (list (Reg reg1) (Reg reg1))) #f]
  [_ #t]))


(define (patch-instruction instr)
  (match instr
    [(Instr op (list (Deref reg1 off1) (Deref reg2 off2))) `(,(Instr 'movq `(,(Deref reg1 off1) ,(Reg 'rax)))
                                                             ,(Instr op `(,(Reg 'rax) ,(Deref reg2 off2))))]
    [else `(,instr)]))

;; patch-instructions : psuedo-x86 -> x86
(define (patch-instructions p)
  (match p
    [(X86Program info `((,label . ,(Block block-info instrs))))
     (define cleaned-instructions (filter not-noop? instrs)) ;; filter out noops before patching
     (define patched-instructions (append-map patch-instruction cleaned-instructions)) ;; patch instructions to avoid bad assigns
     (X86Program info `((,label . ,(Block block-info patched-instructions))))]
    [else (error "patch-instructions unhandled case" p)]))

;; prelude-and-conclusion : x86 -> x86
(define (prelude-and-conclusion p)
  (match p
    [(X86Program info blocks)
     (let* ([used-callee (set->list (dict-ref info 'used-callee))]
            [num-spills (dict-ref info 'num-spills)]
            [space-occupier-count (+ num-spills (length used-callee))]
            [stack-size (* 8 (- (if (odd? space-occupier-count)
                                       (add1 space-occupier-count)
                                       space-occupier-count)
                                   (length used-callee)))]
            [prelude `(main . ,(Block '()
                                      (append
                                       (list (Instr 'pushq (list (Reg 'rbp)))
                                             (Instr 'movq (list (Reg 'rsp) (Reg 'rbp))))
                                       (map (λ (x) (Instr 'pushq (list (Reg x)))) used-callee)
                                       (list (Instr 'subq (list (Imm stack-size) (Reg 'rsp)))
                                             (Jmp 'start)))))]
            [conclusion `(conclusion . ,(Block '()
                                               (append
                                                (list (Instr 'addq (list (Imm stack-size) (Reg 'rsp)))
                                                      (Instr 'popq (list (Reg 'rbp))))
                                                (map (λ (x) (Instr 'popq (list (Reg x))))
                                                     (reverse used-callee))
                                                (list (Retq)))))])
       (X86Program '() `(,prelude ,conclusion . ,blocks)))]
    [else (error "patch-instructions unhandled case" p)]))

; a comparator where #t and #f results are equally likely
(define (break-tie-randomly n1 n2)
  (> (random) .5))

(define (compare-color-nodes n1 n2) ;return the more saturated nodes
  (cond
    [(> (length (cdr n1)) (length (cdr n2))) #t]
    [(> (length (cdr n2)) (length (cdr n1))) #f]
    ;Add a third case to break ties
    ;Swap this out when you implement move biasing
    [else (break-tie-randomly n1 n2)]))

; The first argument (Var t) is more saturated, so the comparison returns true
(check-equal? (compare-color-nodes (cons 't '(1 2 3)) (cons 's '(1 2))) #t)
(check-equal? (compare-color-nodes (cons 't '(1 2)) (cons 's '(0 4 5 6))) #f)

(define (update-saturation pq nodes var color)
  (map (lambda (n)
         (define n-key (node-key n)) ;each node key is of the form (Pair Var (Listof Color))
         (set-node-key! n (cons (car n-key) (cons color (cdr n-key)))) ; add color to the (Listof Color) in the key
         (pqueue-decrease-key! pq n))
       nodes))


; Get the lowest available color
(define (lowest-available-color taken-colors)
  (define register 0)
  (while (memv register taken-colors)
    (set! register (add1 register)))
  register)


;; color-graph : InterferenceGraph (Listof ProgramVariables) -> (Listof (Pair Variable Number))
(define (color-graph graph program-variables)
  ; set the default values of the mapping
  (define mapping (make-hash))
  ; define the mapping to be returned (starts empty)
  (define pq (make-pqueue compare-color-nodes))
  ; define priority queue
  (define queue-nodes (map (lambda (u) (pqueue-push! pq (cons u '()))) program-variables))
  ; push each variable to the queue
  ; variables are stored with a list of adjacent colors
  (while (> (pqueue-count pq) 0) ; while loop will keep evaluating body until pq is empty
         (let* ( [u (pqueue-pop! pq)]
                 [var (car u)]
                 [taken-colors (cdr u)]
                 [neighbors (get-neighbors graph var)]
                 [adjacent-nodes (filter (lambda (n) (memv (car (node-key n)) neighbors)) queue-nodes)]
                 [var-color (lowest-available-color taken-colors)])
           (dict-set! mapping var var-color)
           (update-saturation pq adjacent-nodes var var-color)))
  mapping)

(define (allocate-registers-arg a homes)
  (match a
    [(Var name) (match (dict-ref homes name)
                    [(Deref s offset) (Deref s offset)]
                    [s #:when (symbol? s) (Reg s)])]
    [else a]))

(define (allocate-registers-instr i homes)
  (match i
    [(Instr 'addq `(,a1 ,a2))
     (Instr 'addq `(,(allocate-registers-arg a1 homes) ,(allocate-registers-arg a2 homes)))]
    [(Instr 'subq `(,a1 ,a2))
     (Instr 'subq `(,(allocate-registers-arg a1 homes) ,(allocate-registers-arg a2 homes)))]
    [(Instr 'movq `(,a1 ,a2))
     (Instr 'movq `(,(allocate-registers-arg a1 homes) ,(allocate-registers-arg a2 homes)))]
    [(Instr 'negq `(,a)) (Instr 'negq `(,(allocate-registers-arg a homes)))]
    [(Instr 'pushq a) (Instr 'pushq (allocate-registers-arg a homes))]
    [(Instr 'popq a) (Instr 'popq (allocate-registers-arg a homes))]
    [(Retq) (Retq)]
    [(Jmp l) (Jmp l)]
    [(Callq label arity) (Callq label arity)]
    [else (error "allocate-registers-instr unhandled case" i)]))

(define (allocate-registers-block b homes)
  (match b
    [(Block info instrs) (Block info (map (λ (i) (allocate-registers-instr i homes)) instrs))]
    [else (error "allocate-registers-block unhandled case" b)]))

(define (color->memory color)
 (if (< color (num-registers-for-alloc))
     (color->register color)
     (let ((offset (* 8 (- (num-registers-for-alloc) color))))
            (Deref 'rbp offset))))


(define (allocate-registers p)
  (match p
    [(X86Program info blocks)
     (define vars (map car (dict-ref info 'locals-types)))
     (define vars->colors
       (hash->list (color-graph (dict-ref info 'conflicts) vars)))
     (define vars->memory
       (map (λ (x) (cons (car x) (color->memory (cdr x)))) vars->colors))
     (define used-memory (map cdr vars->memory))
     (define used-registers (filter (lambda (m) (not (Deref? m))) used-memory))
     (define used-callee (set-intersect (callee-save-for-alloc) (list->set used-registers)))
     (define num-spills (count Deref? used-memory))
     (X86Program
      (dict-set (dict-set info 'used-callee used-callee) 'num-spills num-spills)
      (map (λ (b) (cons (car b) (allocate-registers-block (cdr b) vars->memory))) blocks))]
    [else (error "allocate-registers unhandled case" p)]))


(define test
  (X86Program
   '((locals-types
      (tmp26851 . Integer)
      (a26842 . Integer)
      (y26843 . Integer)
      (tmp26846 . Integer)
      (tmp26850 . Integer)
      (tmp26849 . Integer)
      (tmp26853 . Integer)
      (x26844 . Integer)
      (tmp26852 . Integer)
      (tmp26847 . Integer)
      (b26841 . Integer)
      (x26845 . Integer)
      (tmp26848 . Integer)
      (a26840 . Integer)))
   (list
    (cons
     'start
     (Block
      '()
      (list
       (Instr 'movq (list (Imm -12) (Var 'a26840)))
       (Instr 'movq (list (Var 'a26840) (Var 'tmp26846)))
       (Instr 'negq (list (Var 'tmp26846)))
       (Instr 'movq (list (Imm 10) (Var 'b26841)))
       (Instr 'addq (list (Imm 24) (Var 'b26841)))
       (Instr 'movq (list (Var 'a26840) (Var 'a26842)))
       (Instr 'addq (list (Var 'b26841) (Var 'a26842)))
       (Instr 'movq (list (Var 'a26842) (Var 'tmp26847)))
       (Instr 'negq (list (Var 'tmp26847)))
       (Instr 'movq (list (Imm 10) (Var 'tmp26848)))
       (Instr 'addq (list (Imm 20) (Var 'tmp26848)))
       (Instr 'movq (list (Var 'tmp26847) (Var 'tmp26849)))
       (Instr 'addq (list (Var 'tmp26848) (Var 'tmp26849)))
       (Instr 'movq (list (Var 'tmp26846) (Var 'tmp26850)))
       (Instr 'addq (list (Var 'tmp26849) (Var 'tmp26850)))
       (Callq 'read_int 0)
       (Instr 'movq (list (Reg 'rax) (Var 'y26843)))
       (Instr 'movq (list (Imm 30) (Var 'x26844)))
       (Instr 'addq (list (Var 'y26843) (Var 'x26844)))
       (Instr 'movq (list (Imm 5) (Var 'x26845)))
       (Instr 'movq (list (Var 'x26845) (Var 'tmp26851)))
       (Instr 'addq (list (Var 'x26845) (Var 'tmp26851)))
       (Instr 'movq (list (Var 'x26844) (Var 'tmp26852)))
       (Instr 'addq (list (Var 'tmp26851) (Var 'tmp26852)))
       (Instr 'movq (list (Var 'tmp26852) (Var 'tmp26853)))
       (Instr 'negq (list (Var 'tmp26853)))
       (Instr 'movq (list (Var 'tmp26850) (Reg 'rax)))
       (Instr 'addq (list (Var 'tmp26853) (Reg 'rax)))
       (Jmp 'conclusion)))))))

(define (test-pass p pass-func source-interp target-interp)
  (let ([expected-result (source-interp p)]
        [result (target-interp (pass-func p))])
    (if (equal? result expected-result)
        `(,result == ,expected-result)
        (error "Different result than expected" `(,result =/= ,expected-result)))))

;; Define the compiler passes to be used by interp-tests and the grader
;; Note that your compiler file (the file that defines the p
;; must be named "compiler.rkt"
(define compiler-passes
  `( ("partial evaluator" ,partial-evaluator ,interp-Rvar)
     ("uniquify" ,uniquify ,interp-Rvar)
     ("remove complex opera*" ,remove-complex-opera* ,interp-Rvar)
     ("explicate control" ,explicate-control ,interp-Cvar ,type-check-Cvar)
     ("instruction selection" ,select-instructions ,interp-x86-0)
     ("liveness analysis" ,uncover-live ,interp-x86-0)
     ("build interference graph" ,build-interference ,interp-x86-0)
     ("allocate registers" ,allocate-registers ,interp-x86-0)
     ("patch instructions" ,patch-instructions ,interp-x86-0)
     ("prelude-and-conclusion" ,prelude-and-conclusion ,interp-x86-0)
     ))
