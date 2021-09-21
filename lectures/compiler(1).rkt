#lang racket
(require racket/set racket/stream)
(require racket/fixnum)
(require racket/trace)
(require "interp-Rint.rkt")
(require "interp-Rvar.rkt")
(require "interp-Cvar.rkt")
(require "interp.rkt")
(require "utilities.rkt")
(provide (all-defined-out))

; redefine the gensym function in Racket
(define gensym
  (let ([n -1])
    (lambda (s)
      (set! n (add1 n))
      (string->symbol
       (string-append (symbol->string s) "." (number->string n))))))

;; parser
(define parse
  (λ (exp)
    (define I (λ (x) x))
    (define Z (λ (x) (Program '() x)))
    (define f
      (λ (exp C)
        (match exp
          [(? symbol? x) (C (Var x))]
          [(? fixnum? x) (C (Int x))]
          [(? boolean? x) (C (Bool x))]
          [`(let ([,x ,e]) ,b)
           (f e
              (λ (e@)
                (f b
                   (λ (b@)
                     (C (Let x e@ b@))))))]
          [`(if ,e0 ,e1 ,e2)
           (f e0
              (λ (e@0)
                (C (If e@0
                       (f e1 I)
                       (f e2 I)))))]
          [`(read) (C (Prim 'read '()))]
          [`(- ,e)
           (f e
              (λ (e@)
                (C (Prim '- `(,e@)))))]
          [`(,op ,e1 ,e2)
           (match op
             [(or '+ '< '<= '> '>= 'eq?)
              (f e1
                 (λ (e@1)
                   (f e2
                      (λ (e@2)
                        (C (Prim op `(,e@1 ,e@2)))))))])])))
    (f exp Z)))

;; unparser
(define unparse
  (λ (exp)
    (match exp
      [(Var x) x]
      [(Int x) x]
      [(Let x e b)
       `(let ([,x ,(unparse e)])
          ,(unparse b))]
      [(If e0 e1 e2)
       `(if ,(unparse e0)
            ,(unparse e1)
            ,(unparse e2))]
      [(Prim op es)
       `(,op ,@(map unparse es))]
      [(Program _ e) (unparse e)])))


;; partial evaluation
(define (pe-neg r)
  (match r
    [(Int n) (Int (fx- 0 n))]
    [(Prim '+ `(,(Int n1) ,e2))
     (Prim '+ `(,(Int (fx- 0 n1)) ,(pe-exp (Prim '- `(,e2)))))]
    [(Prim '+ `(,e1 ,e2))
     (let ([e@1 (pe-exp (Prim '- `(,e1)))]
           [e@2 (pe-exp (Prim '- `(,e2)))])
       (Prim '+ `(,e@1 ,e@2)))]
    [(Prim '- `(,e)) e]
    [else (Prim '- (list r))]))

(define (pe-add r1 r2)
  (match* (r1 r2)
    [((Int n1) (Int n2))
     (Int (fx+ n1 n2))]
    [((Int n1) (Prim '+ `(,(Int n2) ,e2)))
     (let ([n@ (Int (fx+ n1 n2))])
       (Prim '+ `(,n@ ,e2)))]
    [((Prim '+ `(,(Int n1) ,e1)) (Int n2))
     (let ([n@ (Int (fx+ n1 n2))])
       (Prim '+ `(,n@ ,e1)))]
    [((Prim '+ `(,(Int n1) ,e1))
      (Prim '+ `(,(Int n2) ,e2)))
     (let ([n@ (Int (fx+ n1 n2))]
           [e@ (Prim '+ `(,e1 ,e2))])
       (Prim '+ `(,n@ ,e@)))]
    [(e1 (Prim '+ `(,(Int n2) ,e2)))
     (pe-exp
      (Prim '+ `(,(Int n2) ,(pe-exp (Prim '+ `(,e1 ,e2))))))]
    [((Prim '+ `(,(Int n1) ,e1)) e2)
     (pe-exp
      (Prim '+ `(,(Int n1) ,(pe-exp (Prim '+ `(,e1 ,e2))))))]
    [(_ _) (Prim '+ (list r1 r2))]))

(define (pe-exp e)
  (match e
    [(Int n) (Int n)]
    [(Var x) (Var x)]
    [(Prim 'read '())
     (Prim 'read '())]
    [(Prim '- (list e1))
     (pe-neg (pe-exp e1))]
    [(Prim '+ (list e1 e2))
     (let ([e@1 (pe-exp e1)]
           [e@2 (pe-exp e2)])
       (match e@2
         [(Int n) (pe-add e@2 e@1)]
         [_ (pe-add e@1 e@2)]))]
    [(Let x e@ b)
     (Let x (pe-exp e@) (pe-exp b))]))

(define (pe p)
  (match p
    [(Program info e)
     (Program info (pe-exp e))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Compiler Passes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; uniquify : R1 -> R1
(define (uniquify p)
  (define mt-env '())
  (define ext-env
    (λ (x v env)
      `((,x . ,v) . ,env)))
  (define u
    (λ (env)
      (λ (exp)
        (match exp
          [(Var x)
           (Var (lookup x env))]
          [(Int n) (Int n)]
          [(Let x e b)
           (let* ([x@ (gensym x)]
                  [env@ (ext-env x x@ env)])
             (Let x@
                  ((u env) e)
                  ((u env@) b)))]
          [(Prim op es)
           (Prim op (map (u env) es))]
          ;; conditional
          [(If e0 e1 e2)
           (let ([e@0 ((u env) e0)]
                 [e@1 ((u env) e1)]
                 [e@2 ((u env) e2)])
             (If e@0 e@1 e@2))]))))
  (match p
    [(Program info e)
     (Program info ((u mt-env) e))]))

;; remove-complex-opera* : R1 -> R1
(define remove-complex-opera*
  (λ (exp)
    (define I (λ (x) x))
    (define anf
      (λ (exp ctx C)    ;; context for current call
        (match exp
          [(Let x e b)
           (anf e 'lhs
                (λ (v)
                  (Let x v (anf b ctx C))))]
          #;
          [(If e0 e1 e2)
           (anf e0 'cnd
                (λ (e@0)
                  (C (If e@0
                         (anf e1 'id I)
                         (anf e2 'id I)))))]
          [(Prim op es)
           (anf es 'args
                (λ (es@)
                  (cond
                    [(or (eqv? ctx 'id)
                         (eqv? ctx 'lhs))
                     (C (Prim op es@))]
                    [else (let ([v@ (gensym 'tmp)])
                            (Let v@ (Prim op es@)
                                 (C (Var v@))))])))]
          [`(,a ,as ...)
           (anf a 'arg
                (λ (v)
                  (anf as 'args
                       (λ (vs)
                         (C `(,v ,@vs))))))]
          [(Program info e)
           (Program info (anf e 'id C))]
          ;; including '()
          [e (C e)])))
    (anf exp 'id I)))   

;; type checker

;; explicate-control : R1 -> C0
(define explicate-control
  (λ (exp)
    (define vars '())
    (define I (λ (x) x))
    (define r->c
      (λ (exp C)
        (match exp
          [(Let x e b)
           (r->c e
                 (λ (e@)
                   (let* ([x@ (Var x)]
                          [stmt (Assign x@ e@)])
                     (set! vars (cons `(,x) vars))
                     (Seq stmt (r->c b C)))))]
          ;; assume no unbound variables
          [(or (? Int? x)
               (? Var? x)
               (? Prim? x))
           (if (eqv? C I)
               (C (Return exp))
               (C exp))]
          [(Program info e) (r->c e C)])))
    (let* ([tail (r->c exp I)]
           [info `((local-types . ,vars))])
      (CProgram info `((start . ,tail))))))

;; uncover-live-block
(define uncover-live-bl*
  (λ (label)
    (define st '())    ;; list of reg-status
    (define le '())    ;; list of reg-ending
    (define cc 1)
    (define reverse-seq
      (λ (s ls)
        (match s
          [(Seq stmt tail)
           (reverse-seq tail (cons stmt ls))]
          [(Return e) (cons s ls)])))
    (define uncover-ls!
      (λ (ls)    ;; reversed sequence
        (match ls
          ['() '()]
          [`(,a . ,d)
           (cond
             [(uncover! a)
              => (λ (!) `(,! . ,(uncover-ls! d)))]
             [else (uncover-ls! d)])])))
    (define uncover!
      (λ (!)
        (match !
          [(Assign (Var x) e)
           (cond
             [(not (assv x st)) #f]    ;; dead code
             [else (uncover-assign! x e) !])]
          [(Return e) (uncover-return! e) !])))
    (define uncover-assign!
      (λ (x e)
        (let ([s (var! x '())])
          (match e
            [(Int n) (push-le! s)]
            [(Var y)
             (let ([s@ (var! y s)])
               (push-le! s@))]
            [(Prim op es)
             (match op
               ['read (inc-cc!) (push-le! s)]
               [else (let ([s@ (vars! es s)])
                       (push-le! s@))])]))))
    (define uncover-return!
      (λ (e)
        (match e
          [(Int n) (push-le! '())]
          [(Var x) (let ([s (var! x '())])
                     (push-le! s))]
          [(Prim op es)
           (match op
             ['read (inc-cc!) (push-le! '())]
             [else (let ([s (vars! es '())])
                     (push-le! s))])])))
    (define push-le! (λ (s) (set! le (cons s le))))
    (define inc-cc! (λ () (set! cc (add1 cc))))
    (define vars!
      (λ (ls s)
        (match ls
          ['() s]
          [`(,a . ,d)
           (match a
             [(Var x) (let ([s@ (var! x s)])
                        (vars! d s@))]
             [else (vars! d s)])])))
    (define var!
      (λ (x s)
        (let ([pr (assv x st)])
          (cond
            [(not pr)    ;; variable not in store
             (let ([pr@ `(,x . ,(box cc))])
               (set! st (cons pr@ st))
               (cons x s))]
            [(not (unbox (cdr pr))) s]
            [(= cc (unbox (cdr pr))) s]
            [else (set-box! (cdr pr) #f) s]))))
    (define reconstruct
      (λ (ss)
        (match ss
          [`(,t) #:when (Return? t) t]
          [`(,a . ,d) (Seq a (reconstruct d))])))
    (match label
      [`(,name . ,s)
       (let* ([s@ (reverse-seq s '())]
              [ss (uncover-ls! s@)]
              [sq (reconstruct (reverse ss))])
         (values st le `(,name . ,sq)))])))


;; structure for a Model
(struct Model (reg-map fv-map) #:transparent)

;; register allocation before finalizing instructions
(define allocate
  (λ (p)
    (define R `([rcx . ,(box #t)]
                [rdx . ,(box #t)]
                [rsi . ,(box #t)]
                [rdi . ,(box #t)]
                [r8  . ,(box #t)]
                [r9  . ,(box #t)]
                [r10 . ,(box #t)]
                [r11 . ,(box #t)]
                [rbx . ,(box #t)]
                [r12 . ,(box #t)]
                [r13 . ,(box #t)]
                [r14 . ,(box #t)]
                [r15 . ,(box #t)]))
    (define caller-saved
      (let ([r0 (assv 'rcx R)]
            [r1 (assv 'rdx R)]
            [r2 (assv 'rsi R)]
            [r3 (assv 'rdi R)]
            [r4 (assv 'r8 R)]
            [r5 (assv 'r9 R)]
            [r6 (assv 'r10 R)]
            [r7 (assv 'r11 R)])
        `(,r0 ,r1 ,r2 ,r3 ,r4 ,r5 ,r6 ,r7)))
    (define callee-saved
      (let ([r0 (assv 'rbx R)]
            [r1 (assv 'r12 R)]
            [r2 (assv 'r13 R)]
            [r3 (assv 'r14 R)]
            [r4 (assv 'r15 R)])
        `(,r0 ,r1 ,r2 ,r3 ,r4)))
    (define offset/fv 0)
    (define genfv
      (λ (s)
        (set! offset/fv (add1 offset/fv))
        (string->symbol
         (string-append
          (symbol->string s) "." (number->string offset/fv)))))
    ;; model transformer semantics + static cache replacement
    (define allocate-block
      (λ (block)
        (define inst '())
        (define vs '())
        (define ve '())
        (define init-m (Model '() '()))
        (define t!
          (λ (e model ctx)
            (match* (e ctx)
              [((Int n) _) (values (Int n) model)]
              [((Var x) `(,(Var y) . lhs))
               (cond
                 [(eqv? y x) (values #f model)]
                 [else (let* ([m (load! model e)]
                              [r (find-reg x m)])
                         (values (Var r) m))])]
              [((Var x) _)
               #:when (die-imm? x)
               (values #f (remv-var-model x model))]
              [((Var x) ctx)
               (match ctx
                 [(Int n) (t-lhs! x '() model ctx)]
                 [(Var r) (t-lhs! x `(,(Var r)) model ctx)]
                 [(Prim op es) (t-lhs! x es model ctx)]
                 [#f (values #f model)])]
              [((Prim 'read '()) _) (values e model)]
              [((Prim '- `(,arg)) _)
               (match arg
                 [(Int n) (values (Int (fx- 0 n)) model)]
                 [(Var x) (t-rhs! e arg model)])]
              [((Prim '+ `(,a1 ,a2)) _)
               (match* (a1 a2)
                 [((Int n1) (Int n2))
                  (values (Int (fx+ n1 n2)) model)]
                 [(_ _) (t-rhs! e `(,a1 ,a2) model)])]
              [((Assign (Var x) e*) _)
               (let-values ([(v m) (t! e* model `(,(Var x) . lhs))])
                 (let-values ([(v m) (t! (Var x) (remv-death m (car ve)) v)])
                   (if (not v) 'do-nothing (emit! v))
                   (values #f m)))]
              [((Return e*) _)
               (let-values ([(v m) (t! e* model `(,(Var 'end) . lhs))])
                 (emit! (Return v))
                 (values #f m))]
              [((Seq stmt tail) _)
               (let-values ([(v m) (t! stmt model 'nt)])
                 (set! ve (cdr ve))
                 (t! tail m ctx))])))
        ;; transformer for lhs (Var x)
        (define t-lhs!
          (λ (x es model ctx)
            (match es
              ['()
               (let* ([m (load! model (Var x))]
                      [v (rewrite (Assign (Var x) ctx) m)])
                 (values v m))]
              [`(,a . ,a*)
               (match a
                 [(Int n) (t-lhs! x a* model ctx)]
                 [(Var r)
                  (if (not (in-model-reg? r model))
                      (let* ([m (bind-reg x r model)]
                             [v (Assign (Var r) ctx)])
                        (values (if (Var? ctx) #f v) m))
                      (t-lhs! x a* model ctx))])])))
        ;; transformer for rhs (Prim) etc.
        (define t-rhs!
          (λ (e vars model)
            (let* ([m (load! model vars)]
                   [v (rewrite e m)])
              (values v m))))
        ;; rewrite variables with reg/fv(s)
        (define rewrite
          (λ (exp m)
            (match exp
              [(Var x) (Var (find-reg x m))]
              [(Assign (Var x) *done*)
               (Assign (Var (find-reg x m)) *done*)]
              [(Prim op es)
               (Prim op (rewrite es m))]
              [`(,a . ,d)
               `(,(rewrite a m) . ,(rewrite d m))]
              [o o])))
        (define save!
          (λ (model var)
            (match var
              [(Var x)
               (cond
                 [(in-fvs-var? x model) model]
                 [(in-regs-var? x model)
                  => (λ (pr)
                       (match* (pr model)
                         [(`(,x . ,r) (Model regs fvs))
                          (let ([fv (genfv 'fv)])
                            (emit! (Assign (Var fv) (Var r)))
                            (Model regs `((,x . ,fv) . ,fvs)))]))]
                 [else (error 'save! "cannot save.")])])))
        (define load!
          (λ (model vars)
            (define load-p!
              (λ (model vars p)
                (match vars
                  [(Int n) model]
                  [(Var x)
                   (cond
                     [(in-regs-var? x model) model]
                     [(in-fvs-var? x model)
                      => (λ (pr)
                           (let-values ([(m r) (select! model x p)])
                             (match pr
                               [`(,x . ,fv)
                                (emit! (Assign (Var r) (Var fv)))
                                (bind-reg x r m)])))]
                     [else (let-values ([(m r) (select! model x p)])
                             (bind-reg x r m))])]
                  [`(,a1 ,a2)
                   (let ([m (load-p! model a1 a2)])
                     (load-p! m a2 a1))])))
            (load-p! model vars #f)))
        (define select!
          (λ (m x policy)
            (let ([R@ (call-live? x)])
              (cond
                [(available? R@) => (λ (r) (values m r))]
                [else (let* ([regs (Model-reg-map m)]
                             [victim (select-victim regs policy)])
                        (match victim
                          [`(,x . ,r)
                           (let ([m@ (save! m (Var x))])
                             (values m@ r))]))]))))
        (define select-victim
          (λ (regs policy)
            (define select
              (λ (ls x)
                (cond
                  [(null? ls) (error "no victim.")]
                  [(eqv? x (caar ls)) (select (cdr ls) x)]
                  [else (car ls)])))
            (match policy
              [#f (last regs)]
              [(Var x) (select (reverse regs) x)])))
        (define available?
          (λ (R)
            (match R
              ['() #f]
              [`((,r . ,b) . ,R*)
               (if (unbox b) r (available? R*))])))
        (define call-live?
          (λ (x)
            (let ([pr (assv x vs)])
              (cond
                [(not (unbox (cdr pr))) callee-saved]
                [else R]))))
        (define in-regs-var?
          (λ (x m) (assv x (Model-reg-map m))))
        (define in-fvs-var?
          (λ (x m) (assv x (Model-fv-map m))))
        (define die-imm?
          (λ (x) (memq x (car ve))))
        (define find-reg
          (λ (x m)
            (match m
              [(Model regs fvs)
               (lookup x regs)])))
        (define remv-var-model
          (λ (x m)
            (match m
              [(Model regs fvs)
               (let* ([pr-regs (assv x regs)]
                      [pr-fvs (assv x fvs)]
                      [regs@ (remove pr-regs regs)]
                      [fvs@ (remove pr-fvs fvs)])
                 (cond
                   [(not pr-regs) (Model regs@ fvs@)]
                   [else (set-reg-status! (cdr pr-regs) #t)
                         (Model regs@ fvs@)]))])))
        (define remv-death
          (λ (m ls)
            (match ls
              ['() m]
              [`(,a . ,d)
               (remv-death (remv-var-model a m) d)])))
        (define emit!
          (λ (i) (set! inst `(,@inst ,i))))
        (define in-model-reg?
          (λ (r m)
            (define in?
              (λ (r ls)
                (match ls
                  ['() #f]
                  [`(,a . ,d)
                   (if (eqv? (cdr a) r) a (in? r d))])))
            (match m
              [(Model regs fvs) (in? r regs)])))
        (define bind-reg
          (λ (x r m)
            (match m
              [(Model regs fvs)
               (let ([regs@ (remove (in-model-reg? r m) regs)])
                 (set-reg-status! r #f)
                 (Model `((,x . ,r) . ,regs@) fvs))])))
        (define set-reg-status!
          (λ (r on/off)
            (let ([b (cdr (assv r R))])
              (set-box! b on/off))))
        (define reconstruct
          (λ (inst)
            (match inst
              [`(,t) #:when (Return? t) t]
              [`(,a . ,d) (Seq a (reconstruct d))])))
        ;; *end-of-definition*
        (let-values ([(st le bl) (uncover-live-bl* block)])
          (set! vs st)
          (set! ve le)
          (let-values ([(v m) (t! (cdr bl) init-m 'tail)])
            `(,(car bl) . ,(reconstruct inst))))))
    ;; stack-space
    (define get-space-x86
      (λ (c)
        (let* ([s (* 8 c)]
               [r (remainder s 16)])
          (+ s r))))
    (define allocate-cfg
      (λ (ls)
        (cond
          [(null? ls) '()]
          [else (cons (allocate-block (car ls))
                      (allocate-cfg (cdr ls)))])))
    (match p
      [(CProgram info cfg)
       (let* ([cfg@ (allocate-cfg cfg)]
              [space (get-space-x86 offset/fv)])
         (CProgram `((stack-space . ,space)) cfg@))])))

;; finalize instructions
(define select-instr
  (λ (p)
    (define t
      (λ (e)
        (match e
          [(Int x) (Imm x)]
          [(Var x)
           (let* ([s (symbol->string x)]
                  [l (string-split s ".")])
             (match (cdr l)
               ['() (Reg x)]
               [`(,ns) (let ([n (string->number ns)])
                         (Deref 'rbp (* n -8)))]))])))
    (define select
      (λ (tail)
        (match tail
          [(Return e)
           (match e
             [(or (? Int?) (? Var?))
              (let ([i (Instr 'movq `(,(t e) ,(Reg 'rax)))])
                `(,i))]
             [(Prim '+ `(,arg1 ,arg2))
              (let ([i1 (Instr 'movq `(,(t arg1) ,(Reg 'rax)))]
                    [i2 (Instr 'addq `(,(t arg2) ,(Reg 'rax)))])
                `(,i1 ,i2))]
             [(Prim '- `(,arg))
              (let ([i1 (Instr 'movq `(,(t arg) ,(Reg 'rax)))]
                    [i2 (Instr 'negq `(,(Reg 'rax)))])
                `(,i1 ,i2))]                     
             [(Prim 'read '())
              (let ([i (Callq 'read_int 0)])
                `(,i))])]
          [(Seq stmt tl)
           (match stmt
             [(Assign (Var x) e)
              (match e
                [(Var v) #:when (eqv? v x) (select tl)]
                [(or (? Int?) (? Var?))
                 (let ([i (Instr 'movq `(,(t e) ,(t (Var x))))])
                   `(,i ,@(select tl)))]
                [(Prim 'read '())
                 (let ([i1 (Callq 'read_int 0)]
                       [i2 (Instr 'movq `(,(Reg 'rax) ,(Reg x)))])
                   `(,i1 ,i2 ,@(select tl)))]
                [(Prim '- `(,a))
                 (match a
                   [(Var v)
                    #:when (eqv? v x)
                    (let ([i (Instr 'negq `(,(Reg x)))])
                      `(,i ,@(select tl)))]
                   [a (let ([i1 (Instr 'movq `(,(t a) ,(Reg x)))]
                            [i2 (Instr 'negq `(,(Reg x)))])
                        `(,i1 ,i2 ,@(select tl)))])]
                [(Prim '+ `(,a1 ,a2))
                 (match* (a1 a2)
                   [((Var v1) a2)
                    #:when (eqv? v1 x)
                    (let ([i (Instr 'addq `(,(t a2) ,(Reg x)))])
                      `(,i ,@(select tl)))]
                   [(a1 (Var v2))
                    #:when (eqv? v2 x)
                    (let ([i (Instr 'addq `(,(t a1) ,(Reg x)))])
                      `(,i ,@(select tl)))]
                   [(a1 a2)
                    (let ([i1 (Instr 'movq `(,(t a1) ,(Reg x)))]
                          [i2 (Instr 'addq `(,(t a2) ,(Reg x)))])
                      `(,i1 ,i2 ,@(select tl)))])])])])))
    (define select-cfg
      (λ (cfg)
        (match cfg
          ['() '()]
          [`((,label . ,tail) . ,d)
           `((,label . ,(Block '() (select tail)))
             . ,(select-cfg d))])))
    (match p
      [(CProgram info cfg)
       (let ([cfg@ (select-cfg cfg)])
         (X86Program info cfg@))])))

;; prelude-and-conclusion : x86 -> x86
(define prelude-and-conclusion
  (λ (p)
    (define build-main
      (λ (space)
        (let* ([i1 (Instr 'pushq `(,(Reg 'rbp)))]
               [i2 (Instr 'movq `(,(Reg 'rsp) ,(Reg 'rbp)))]
               [i3 (Instr 'subq `(,(Imm space) ,(Reg 'rsp)))]
               [i4 (Jmp 'start)]
               [b (Block '() `(,i1 ,i2 ,i3 ,i4))])
          `(main . ,b))))
    (define build-conc
      (λ (space)
        (let* ([i1 (Instr 'addq `(,(Imm space) ,(Reg 'rsp)))]
               [i2 (Instr 'popq `(,(Reg 'rbp)))]
               [i3 (Retq)]
               [b (Block '() `(,i1 ,i2 ,i3))])
          `(conclusion . ,b))))
    (define last-jmp
      (λ (cfg)
        (match cfg
          ['() '()]
          [`((,label . ,tail) . ,d)
           (match tail
             [(Block info ls)
              (cond
                [(not (Jmp? (last ls)))
                 (let* ([jmp-c (Jmp 'conclusion)]
                        [ls@ `(,@ls ,jmp-c)]
                        [tl@ (Block info ls@)])
                   `((,label . ,tl@)
                     . ,(last-jmp d)))]
                [else
                 `((,label . ,tail)
                   . ,(last-jmp d))])])])))
    (match p
      [(X86Program info cfg*)
       (let* ([pr (assq 'stack-space info)]
              [space (cdr pr)]
              [main (build-main space)]
              [conc (build-conc space)]
              [cfg (last-jmp cfg*)]
              [cfg@ `(,main ,@cfg ,conc)])
         (X86Program info cfg@))])))

(define summary
  (λ (exp)
    (select-instr
     (allocate
      (explicate-control
       (remove-complex-opera*
        (uniquify
         (parse exp))))))))
(define alloc
  (λ (exp)
    (allocate
     (explicate-control
      (remove-complex-opera*
       (uniquify
        (parse exp)))))))

;; Define the compiler passes to be used by interp-tests and the grader
;; Note that your compiler file (the file that defines the passes)
;; must be named "compiler.rkt"
(define compiler-passes
  `(("uniquify" ,uniquify ,interp-Rvar)
    ;;("partial evaluation" ,pe ,interp-Rvar)
    ("remove complex opera*" ,remove-complex-opera* ,interp-Rvar)
    ("explicate control" ,explicate-control ,interp-Cvar)
    ("register allocation" ,allocate ,interp-Cvar)
    ("finalize instruction" ,select-instr ,interp-x86-0)
    ("prelude-and-conclusion" ,prelude-and-conclusion ,interp-x86-0)
    ))

