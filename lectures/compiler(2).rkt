#lang racket
(require racket/set racket/stream)
(require racket/fixnum)
(require "interp-Rint.rkt")
(require "interp-Rvar.rkt")
(require "interp-Cvar.rkt")
(require "type-check-Cvar.rkt")
(require "interp.rkt")
(require "utilities.rkt")
(require graph)
(require "graph-printing.rkt")
(require "priority_queue.rkt")
(provide (all-defined-out))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Group members: Marshal Gress, Weifeng Han, Garrett Robinson, Nick Irmscher
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
  (match* (r1 r2)
    [((Int n1) (Int n2)) (Int (fx+ n1 n2))]
    [(_ _) (Prim '+ (list r1 r2))]))

(define (pe-exp e)
  (match e
    [(Int n) (Int n)]
    [(Prim 'read '()) (Prim 'read '())]
    [(Prim '- (list e1)) (pe-neg (pe-exp e1))]
    [(Prim '+ (list e1 e2)) (pe-add (pe-exp e1) (pe-exp e2))]))

(define (pe-Rint p)
  (match p
    [(Program info e) (Program info (pe-exp e))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; uniquify

(define (uniquify-exp env)
  (lambda (e)
    (match e
      [(Var x)
       (Var (dict-ref env x))]
      [(Int n) (Int n)]
      [(Let x e body)
       (let* ([y (gensym x)]
              [new-env (dict-set env x y)])
         (Let y
              ((uniquify-exp new-env) e)
              ((uniquify-exp new-env) body)))]
      [(Prim op es)
       (Prim op (for/list ([e es]) ((uniquify-exp env) e)))])))

;; uniquify : R1 -> R1
(define (uniquify p)
  (match p
    [(Program info e) (Program info ((uniquify-exp '()) e))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; remove complex operands

; rco-exp : Exp -> Exp
(define (rco-exp e)
  (match e
    [(Var x) (Var x)]
    [(Int n) (Int n)]
    [(Let x e body)
     (let* ([newe    (rco-exp e)]
            [newbody (rco-exp body)])
       (Let x newe newbody))]
    [(Prim op es)
     (let* ([lopoad (map (λ (e) (rco-atom e)) es)]
            [newes (map (λ (pr) (car pr)) lopoad)]
            [dict (foldl (λ (pr l) (append (cdr pr) l)) '() lopoad)])
       (update (Prim op newes) dict))]))

; rco-atom : exp -> (Pair Atom (Listof (Pair Atom Exp)))
(define (rco-atom e)
  (match e
    [(Var x)
     (let* ([atm   (Var x)]
            [alist '()])
       (cons atm alist))]
    [(Int n)
     (let* ([atm   (Int n)]
            [alist '()])
       (cons atm alist))]
    [(Let x e body)
     (let* ([s (gensym 'tmp)]
            [newe    (rco-exp e)]
            [newbody (rco-exp body)]
            [atm (Var s)]
            [alist (dict-set (dict-set '() x newe)
                             s newbody)])
       (cons atm alist))]
    [(Prim op es)
     (let* ([s (gensym 'tmp)]
            [atm   (Var s)]
            [alist (let* ([key   s]
                          [lopoad (map (λ (e) (rco-atom e)) es)]
                          [newes (map (λ (pr) (car pr)) lopoad)]
                          [dict (foldl (λ (pr l) (append (cdr pr) l)) '() lopoad)]
                          [value (Prim op newes)])
                     (dict-set dict key value))])
       (cons atm alist))]))

; update : Exp Dictionary -> Exp
(define (update e dict)
  (cond
    [(dict-empty? dict) e]
    [else (let* ([x (car (car dict))]
                 [v (cdr (car dict))]
                 [body (update e (cdr dict))])
            (Let x v body))]))

; remove-complex-opera* : R1 -> R1
(define (remove-complex-opera* p)
  (match p
    [(Program info e) (Program info (rco-exp e))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; explicate control

;; explicate-control : R1 -> C0
(define (explicate-control p)
  (match p
    [(Program info body)
     (let ([r (explicate-tail body)])
       (CProgram info (list (cons 'start (car r)))))]))

(define (explicate-tail e)
  (match e
    [(Var x)
     (let* ([ctail (Return (Var x))]
            [vlist '()])
       (cons ctail vlist))]
    [(Int n)
     (let* ([ctail (Return (Int n))]
            [vlist '()])
       (cons ctail vlist))]
    [(Let x rhs body)
     (match-let ([(cons bodyctail bodyvlist) (explicate-tail body)])
       (match-let ([(cons rhsctail rhsvlist) (explicate-assign rhs x bodyctail)])
         (let* ([ctail rhsctail]
                [vlist (append (cons x rhsvlist) bodyvlist)])
           (cons ctail vlist))))]
    [(Prim op es)
     (let* ([ctail (Return (Prim op es))]
            [vlist '()])
       (cons ctail vlist))]
    [else (error "explicate_tail unhandled case" e)]))

(define (explicate-assign e x cont)
  (match e
    [(Var s) 
     (let* ([ctail (Seq (Assign (Var x) (Var s)) cont)]
            [vlist '()])
       (cons ctail vlist))]
    [(Int n)
     (let* ([ctail (Seq (Assign (Var x) (Int n)) cont)]
            [vlist '()])
       (cons ctail vlist))]
    [(Let s rhs body)
     (match-let ([(cons bodyctail bodyvlist) (explicate-assign body x cont)])
       (match-let ([(cons rhsctail rhsvlist) (explicate-assign rhs s bodyctail)])
         (let* ([ctail rhsctail]
                [vlist (append (cons s rhsvlist) bodyvlist)])
           (cons ctail vlist))))]
    [(Prim op es)
     (let* ([ctail (Seq (Assign (Var x) (Prim op es)) cont)]
            [vlist '()])
       (cons ctail vlist))]
    [else (error "explicate_tail unhandled case" e)]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; select instructions

#|
   C_Var Grammar
   atm ::= int | var

   exp ::= atm | (read) | (- atm) | (+ atm atm)

   stmt ::= var = exp; 

   tail ::= return exp; | stmt tail 

   C_Var ::= (label: tail)^+

   ===========================================================

   pseudo-x86 Grammar
   reg ::= rsp | rbp | rax | rbx | rcx | rdx | rsi | rdi |
           r8 | r9 | r10 | r11 | r12 | r13 | r14 | r15

   arg ::= (Imm int) | (Reg reg) | (Deref reg int) | (Var x)

   instr ::= (Instr addq (arg arg)) | (Instr subq (arg arg))
             | (Instr movq (arg arg)) | (Instr negq (arg))
             | (Callq label int) | (Retq) | (Pushq arg) | (Popq arg) | (Jmp label)

   block ::= (Block info (instr …))

   pseudo-x86 ::= (X86Program info ((label . block)…))
|#

; si-atm : atm -> pseudo-x86
(define si-atm
  (λ (atm)
    (match atm
      [(Int n) (Imm n)]
      [(Var x) (Var x)]
      [else (error "expected an atom for si-atm, instead got" atm)])))

; si-stmt : stmt -> pseudo-x86
(define si-stmt
  (λ (stmt)
    (match stmt
      [(Assign (Var x) exp)
       (match exp
         [(Prim '+ `(,atm1 ,atm2))
          (cond ; prevent needless code by seeing if x is an addend
            [(equal? (Var x) atm1)
             (list (Instr 'addq (list (si-atm atm2) (Var x))))]
            [(equal? (Var x) atm2)
             (list (Instr 'addq (list (si-atm atm1) (Var x))))]
            [else (append (si-exp exp)
                          (list (Instr 'movq (list (Reg 'rax) (Var x)))))])]
         [else (append (si-exp exp)
                       (list (Instr 'movq (list (Reg 'rax) (Var x)))))])]
      [else (error "expected a stmt for si-stmt, instead got" stmt)])))

; si-tail : tail -> pseudo-x86
(define si-tail
  (λ (tail)
    (match tail
      [(Return exp)
       (append (si-exp exp)
               (list (Jmp 'conclusion)))]
      [(Seq stmt tail)
       (append (si-stmt stmt)
               (si-tail tail))]
      [else (error "expected a tail for si-tail, instead got" tail)])))

; si-exp : exp -> pseudo-x86
(define si-exp
  (λ (exp)
    (match exp
      [(Prim read '())
       (list (Callq 'read_int 0))]
      [(Prim '- `(,atm))
       (list (Instr 'movq (list (si-atm atm)
                                (Reg 'rax)))
             (Instr 'negq (list (Reg 'rax))))]
      [(Prim '+ `(,atm1 ,atm2))
       (list (Instr 'movq (list (si-atm atm1)
                                (Reg 'rax)))
             (Instr 'addq (list (si-atm atm2)
                                (Reg 'rax))))]
      [else (list (Instr 'movq (list (si-atm exp) (Reg 'rax))))])))

;; select-instructions : C0 -> pseudo-x86
(define (select-instructions p)
  (match-let ([(CProgram types (list (cons label tail))) (type-check-Cvar p)])
    (X86Program types
                (list (cons label
                            (Block '() (si-tail tail)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; liveness analysis

; locations-arg : arg -> [Set arg]
(define (locations-arg arg)
  (match arg
    [(Imm int) (set)]
    [`,else (set arg)]))

; locations-call : [Listof Register] Integer -> [Set arg]
(define (locations-call regs arity)
  (cond
    [(= arity 0) (set)]
    [else (set-union (car regs)
                     (locations-call (cdr regs)
                                     (sub1 arity)))]))

; label->live : label -> [Set args]
(define (label->live label)
  (match label
    ['conclusion (set (Reg 'rax) (Reg 'rsp))]
    [`,else (set (Reg 'rsp))]))
     
; locations-read : instr -> [Set arg]
(define (locations-read instr)
  (match instr
    [(Instr 'movq `(,arg1 ,arg2))
     (locations-arg arg1)]
    [(Instr op `(,arg1 ,arg2)) ; add/subtract
     (set-union (locations-arg arg1)
                (locations-arg arg2))]
    [(Instr 'negq `(,arg))
     (locations-arg arg)]
    [(Callq `,label `,arity)
     ; rdi rsi rdx rcx r8 r9
     (define caller-saved
       (list (Reg 'rdi) (Reg 'rsi) (Reg 'rdx)
             (Reg 'rcx) (Reg 'r8) (Reg 'r9)))
     (locations-call caller-saved arity)]
    [(Retq) (set)]
    [`(,Pupq ,arg) (locations-arg arg)]
    [(Jmp `,label)
     (label->live label)]))
      
; locations-written : instr -> [Set arg]
(define (locations-written instr)
  (match instr
    [(Instr op `(,arg1 ,arg2)) ; add/subtract/move
     (locations-arg arg2)]
    [(Instr 'negq `(,arg))
     (locations-arg arg)]
    [(Callq `,label `,arity)
     ; caller-saved: rax rcx rdx rsi rdi r8 r9 r10 r11
     (set (Reg 'rax) (Reg 'rcx) (Reg 'rdx)
          (Reg 'rsi) (Reg 'rdi) (Reg 'r8)
          (Reg 'r9) (Reg 'r10) (Reg 'r11))]
    [(Retq) (set)]
    [`(,Pupq ,arg) (set)]
    [(Jmp `,label) (set)]))

; uncover-live-loi : [Listof instr] [Set arg] -> [Listof [Set arg]]
; returns list of live-after sets
(define (uncover-live-loi loi ila) ; ila = initial live after
  (foldr
   (λ (instr so-far)
     (cons (set-union
            (set-subtract
             (car so-far)
             (locations-written instr))
            (locations-read instr))
           so-far))
   (list ila)
   loi))

(define ex (list (Instr 'movq (list (Imm 1) (Var 'v)))
                 (Instr 'movq (list (Imm 42) (Var 'w)))
                 (Instr 'movq (list (Var 'v) (Var 'x)))
                 (Instr 'addq (list (Imm 7) (Var 'x)))
                 (Instr 'movq (list (Var 'x) (Var 'y)))
                 (Instr 'movq (list (Var 'x) (Var 'z)))
                 (Instr 'addq (list (Var 'w) (Var 'z)))
                 (Instr 'movq (list (Var 'y) (Var 't)))
                 (Instr 'negq (list (Var 't)))
                 (Instr 'movq (list (Var 'z) (Reg 'rax)))
                 (Instr 'addq (list (Var 't) (Reg 'rax)))
                 (Jmp 'conclusion)))

#;(uncover-live-loi ex
                  (set))
#;(uncover-live-loi (list
                   (Instr 'movq (list (Imm 10) (Var 'x13598))) ; rsp
                   (Instr 'movq (list (Imm 5) (Var 'tmp13600))) ; rsp, x13598
                   (Instr 'addq (list (Var 'x13598) (Var 'tmp13600))) ; rsp, tmp13600, x13598
                   (Instr 'movq (list (Imm 20) (Var 'y13599))) ; rsp, tmp13600
                   (Instr 'movq (list (Var 'y13599) (Var 'tmp13601))) ; rsp, tmp13600, y13599
                   (Instr 'addq (list (Imm 17) (Var 'tmp13601))) ; rsp, tmp13601, tmp13600
                   (Instr 'movq (list (Var 'tmp13600) (Reg 'rax))) ; rsp, tmp13601, tmp13600
                   (Instr 'addq (list (Var 'tmp13601) (Reg 'rax))) ; rsp, rax, tmp13601
                   (Jmp 'conclusion)) ; rsp, rax
                  (set))

; uncover-lives : x86Program -> x86Program
(define (uncover-lives p)
  (match p
    [(X86Program info `((,label . ,block)))
     (match block
       [(Block binfo loi)
        (X86Program info
                    (cons label
                          (Block (uncover-live-loi loi (set))
                                 loi)))])]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; build interference graph

; build-inter-graph : X86Program -> X86Program
(define (build-inter-graph p)
  (match p
    [(X86Program info `((,label . ,block)))
     (match block
       [(Block binfo loi)
        (X86Program (list `(conflicts . ,(big-loi loi binfo)))
                    (cons label block))])]))

#|
1. If instruction Ik is a move instruction, movq s, d, then add the edge (d, v) for
every v ∈ Lafter(k) unless v = d or v = s.
2. For any other instruction Ik, for every d ∈ W(k) add an edge (d, v) for every
v ∈ Lafter(k) unless v = d.
|#
; big-loi : [Listof instr] [Listof [Set arg]] -> Graph
(define (big-loi loi live-after)
  (define graph (undirected-graph '()))
  (for/list ([instr loi]
             [lak live-after])
    (match instr
      [(Instr 'movq `(,s ,d))
       (for/list ([v (set->list lak)]
                  #:when (not (or (arg-eq? v d)
                                  (arg-eq? v s))))
         (add-edge! graph d v))]
      [(Instr 'addq `(,s ,d))
       (for/list ([v (set->list lak)]
                  #:when (not (arg-eq? v d)))
         (add-edge! graph d v))]
      [(Instr 'subq `(,s ,d))
       (for/list ([v (set->list lak)]
                  #:when (not (arg-eq? v d)))
         (add-edge! graph d v))]
      [(Instr 'negq `(,d))
       (for/list ([v (set->list lak)]
                  #:when (not (arg-eq? v d)))
         (add-edge! graph d v))]
      [(Callq label n)
       (define caller-saved
         (list (Reg 'rdi) (Reg 'rsi) (Reg 'rdx)
               (Reg 'rcx) (Reg 'r8) (Reg 'r9)))
       (for/list ([d caller-saved])
         (for/list ([v (set->list lak)]
                    #:when (not (arg-eq? v d)))
           (add-edge! graph d v)))]
      [_ graph])) ; Pushq, Popq, Retq don't write
  graph)

; arg-eq? : arg arg -> Boolean
(define (arg-eq? arg1 arg2)
  (match arg1
    [(Imm n) #f] ; won't write to an Imm
    [(Reg r)
     (match arg2
       [(Reg r1) (eq? r r1)]
       [_ #f])]
    [(Var x)
     (match arg2
       [(Var y) (eq? x y)]
       [_ #f])]
    [(Deref r n)
     (match arg2
       [(Deref r1 n1)
        (and (eq? r r1)
             (eq? n n1))]
       [_ #f])]
    [_ (error "arg-eq? : expected an arg for arg1, got" arg1)]))



;(print-graph (big-loi ex (uncover-live-loi ex (set))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; register allocation

; allocate-registers : X86Program -> X86Program
(define (allocate-registers p)
  (match p
    [(X86Program info `(,label ,block))
     (define conflicts (dict-ref info 'conflicts))
     (match block
       [(Block binfo loi)
        (define allocated-regs
          (color-to-locations
           (append
            (ar-regs conflicts)
            (ar-vars conflicts))))
        (X86Program (dict-set info
                              'used-callee
                              (filter (λ (arg-loc)
                                        (callee? (cdr arg-loc)))
                                        allocated-regs))
                    (cons label block))])]))

; callee? : Reg or Var -> Boolean
(define (callee? arg)
  (match arg
    [(Reg r)
     (or (eq? r 'rbx)
         (eq? r 'rsp)
         (eq? r 'rbp)
         (eq? r 'r12)
         (eq? r 'r13)
         (eq? r 'r14)
         (eq? r 'r15))]
    [_ #f]))

; ar-regs : Graph -> [DictionaryOf Number Arg]
; takes a Graph and return its mapping from Registers to colors
(define (ar-regs g)
  (bond-reg (filter is-reg? (sequence->list (in-vertices g)))))

; is-reg? : Arg -> Boolean
(define (is-reg? a)
  (match a
    [(Reg reg) true]
    [else false]))

; bond-reg : [ListOf Register] -> [DictionaryOf Number Register]
(define (bond-reg lor)
  (cond
    [(empty? lor) empty]
    [else (let ([rest (bond-reg (rest lor))])
            (dict-set rest (car lor) (- 0 (add1 (dict-count rest)))))]))

; ar-graph : Graph -> [DictionaryOf Number Arg]
(define ar-vars ;; change [ListOf Color] to [SetOf Color] later
  (λ (g)
    (let* ([var-satur-list (make-hash)] ;; [DictionaryOf Var [ListOf Color]]
           [var-handle-list (make-hash)];; [DictionaryOf Var Handle]
           [ls (sequence->list (in-vertices g))]
           [lovar (filter (λ (a) (not (is-reg? a))) ls)]) 
      (begin (for/list ([var ls]) ;; initialize var-satur-list
               (dict-set! var-satur-list var empty))
             (define pq              ;; initialize pq
               (make-pqueue (λ (n1 n2) (> (length (dict-ref var-satur-list n1))
                                          (length (dict-ref var-satur-list n2))))))
             (for/list ([var lovar]) ;; initialize var-satur-list
               (dict-set! var-handle-list var (pqueue-push! pq var)))
             ;; var-handle-list and var-satur-list and pq working properly at this point!!!

             ; find-index : [ListOf Number] Number -> Number
             (define (find-index lon n)
               (cond
                 [(< n (sub1 (length lovar)))
                  (cond
                    [(not (ormap (λ (num) (= num n)) lon)) n] ;; if n is not used, use n
                    [else (find-index lon (add1 n))])]
                 [else n]))
             (letrec ([ar-ls ;; ar-ls : -> [DictionaryOf Number Var]
                       (λ ()
                         (cond
                           [(zero? (pqueue-count pq)) empty]
                           [else (begin
                                   (define var (pqueue-pop! pq))
                                   (pqueue-decrease-key! pq (dict-ref var-handle-list var))
                                   (define sat-list (dict-ref var-satur-list var)) ;; [ListOf Color(Number)]
                                   (define index (find-index sat-list 0))
                                   (for/list ([neighbor (sequence->list (in-neighbors g var))])
                                     (dict-set! var-satur-list neighbor (cons index (dict-ref var-satur-list neighbor)))) 
                                   (define dict-rest (ar-ls))
                                   (dict-set dict-rest var index))]))])
               (ar-ls))))))

            
(define l2 (list (Instr 'movq (list (Imm 1) (Var 'v)))
                 (Instr 'movq (list (Imm 42) (Var 'w)))
                 (Instr 'movq (list (Var 'v) (Var 'x)))
                 (Instr 'addq (list (Imm 7) (Var 'x)))
                 (Instr 'movq (list (Var 'x) (Var 'y)))
                 (Instr 'movq (list (Var 'x) (Var 'z)))
                 (Instr 'addq (list (Var 'w) (Var 'z)))
                 (Instr 'movq (list (Var 'y) (Var 't)))
                 (Instr 'negq (list (Var 't)))
                 (Instr 'movq (list (Var 'z) (Reg 'rax)))
                 (Instr 'addq (list (Var 't) (Reg 'rax)))
                 (Jmp 'conclusion)))
(define losol2 (uncover-live-loi l2 (set (Reg 'rsp) (Reg 'rax))))
;(define g2 (undirected-graph (big-loi l2 losol2)))
;(define result (ar-vars g2))

(define all-regs
  (list (Reg 'rbx)
        (Reg 'rcx)
        (Reg 'rdx)
        (Reg 'rsi)
        (Reg 'rdi)
        (Reg 'r8)
        (Reg 'r9)
        (Reg 'r10)
        (Reg 'r11)
        (Reg 'r12)
        (Reg 'r13)
        (Reg 'r14)))
 

; color-to-locations : [ListOf [PairOf Number Arg]] [DictionaryOf Number Location] -> [DictionaryOf Arg Location]
(define (color-to-locations arg-color-list)
  (cond
    [(empty? arg-color-list) empty]
    [else (dict-set (color-to-locations (cdr arg-color-list))
                    (car arg-color-list)
                    (map-to-loc (car arg-color-list)))]))

; A Location is one of:
; - (Reg reg)
; - (Deref reg int)

; map-to-loc : Number(Color) -> Location
(define (map-to-loc n)
  (cond
    [(= -1 n) (Reg 'rax)]
    [(= -2 n) (Reg 'rsp)]
    [(< n 12) (find-ith n all-regs)]
    [else (Deref 'rbp (* -8 (- n 11)))]))

; find-ith : Number -> Location
(define (find-ith n ls)
  (cond
    [(zero? n) (car ls)]
    [else (find-ith (sub1 n) (cdr ls))]))
        
#|
(define colors
  '((-2 . (Reg 'rsp))
    (-1 . (Reg 'rax))
    (0 . (Reg 'rbx))
    (1 . (Reg 'rcx))
    (2 . (Reg 'rdx))
    (3 . (Reg 'rsi))
    (4 . (Reg 'rdi))
    (5 . (Reg 'rbp))
    (6 . (Reg 'r8))
    (7 . (Reg 'r9))
    (8 . (Reg 'r10))
    (9 . (Reg 'r11))
    (10 . (Reg 'r12))
    (11 . (Reg 'r13))
    (12 . (Reg 'r14))
    (13 . (Reg 'r15))))
(define location-colors (make-hash)) ; return for color-graph
(define taken-colors (make-hash)) ; [Listof [Pair arg [Listof Integer]]] (all vertices w/ nieghbor colors)
#|
W ← vertices(G)
while W != ∅ do
    pick a vertex u from W with the highest saturation,
         breaking ties randomly
    find the lowest color c that is not in {color[v] : v ∈ adjacent(u)}
    color[u] ← c
    W ← (W – {u})
|#
; color-graph : Graph [Listof arg] -> [Listof [Pair arg Integer]]
(define (color-graph graph locs)
  (for/list ([v locs])
    (hash-set! taken-colors v '()))
  (hash-set! location-colors (Reg 'rax) -1)
  (hash-set! location-colors (Reg 'rsp) -2)
  (update-taken-colors graph)
  
  (for/list ([u (take-hs)]
             [v locs]
             #:when (not (hash-has-key? location-colors u)))
    (for/list ([c colors])
               #:final (not (member (car c) (cdr u)))
      (hash-set! location-colors (car u) (car c))
      (update-taken-colors graph)))

  location-colors)

; update-taken-colors : Graph -> Void
(define (update-taken-colors graph)
  (for/list ([location-color location-colors])
    (for/list ([v (sequence->list (in-neighbors graph (car location-color)))])
      (hash-set! taken-colors v (cons (cdr location-color)
                                      (hash-ref taken-colors v))))))




; take-hs :  -> [Pair arg [Listof Integer]]
; take highest saturation (Priority Queue)
(define (take-hs)
  (define pq
    (make-pqueue (λ (p1 p2)
                   (> (length (cdr p1))
                      (length (cdr p2))))))
  (for/list ([v-and-nc taken-colors]) ; vertex and neighbor colors
    (pqueue-push! pq v-and-nc))
  (pqueue-pop! pq))

; color : Integer -> Reg or Deref
(define (color n)
  (match n
    [-2 (Reg 'rsp)]
    [-1 (Reg 'rax)]
    [0 (Reg 'rbx)]
    [1 (Reg 'rcx)]
    [2 (Reg 'rdx)]
    [3 (Reg 'rsi)]
    [4 (Reg 'rdi)]
    [5 (Reg 'rbp)]
    [6 (Reg 'r8)]
    [7 (Reg 'r9)]
    [8 (Reg 'r10)]
    [9 (Reg 'r11)]
    [10 (Reg 'r12)]
    [11 (Reg 'r13)]
    [12 (Reg 'r14)]
    [13 (Reg 'r15)]
    [_ (Deref 'rbp (- (* 8 (- 13 n))))]))

#;(take-hs (list '(a . '(1 2))
               '(b . '(1 2 3 4))
               '(c . '(1 2 3))))

(color-graph (big-loi ex (uncover-live-loi ex (set)))
             (list (Reg 'rax) (Reg 'rsp) (Var 't) (Var 'z)
                   (Var 'y) (Var 'x) (Var 'w) (Var 'v)))
|#
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; assign homes

;; assign-homes : pseudo-x86 -> pseudo-x86
(define (assign-homes p)
  (match p
    [(X86Program info lopr)
     (let* ([pr (car lopr)]
            [label (car pr)]
            [block (cdr pr)])
       (match block
         [(Block binfo instructions)
          (let* ([instrs instructions]
                 [alist (refer-list (map car (cdr (car info))) -8)])
            (X86Program
             info
             (list (cons label
                         (Block binfo (assign-homes-instrs instrs alist))))))]))]))

; refer-list : Dictionary Integer -> Dicationary
(define (refer-list info counter)
  (cond
    [(empty? info) empty]
    [else
     (dict-set (refer-list (cdr info) (- counter 8))
               (car info) (Deref 'rbp counter))]))

; assign-homes-instrs : [ListOf Instr] [ListOf [PairOf Symbol (Deref reg int)]] -> [ListOf Instr]
(define (assign-homes-instrs instrs alist)
  (cond
    [(empty? instrs) empty]
    [else (cons (assign-homes-single (car instrs) alist)
                (assign-homes-instrs (cdr instrs) alist))]))

; assign-homes-single : Instr [ListOf [PairOf Symbol (Deref reg int)]] -> Instr
(define (assign-homes-single instr alist)
  (match instr
    [(Instr op `,ls)
     (Instr op (map (λ (arg)
                      (match arg
                        [(Var var) (dict-ref alist var)]
                        [else arg]))
                    ls))]
    [else instr])) 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; patch instructions

;; patch-instructions : psuedo-x86 -> x86
(define (patch-instructions p)
  (match p
    [(X86Program info lopr)
     (let* ([pr (car lopr)]
            [label (car pr)]
            [block (cdr pr)])
       (match block
         [(Block binfo instructions)
          (X86Program
           info
           (list
            (cons label
                  (Block binfo
                         (foldr (λ (this rest)
                                  (match this
                                    [(Instr 'movq `(,arg1 ,arg2))
                                     (if (equal? arg1 arg2)
                                         rest
                                         (append (patch-instructions-instr this) rest))]
                                    [else (append (patch-instructions-instr this) rest)]))                                      
                                '()
                                instructions)))))]))]))


(define ex3-5
  (X86Program
 '((stack-space . 16))
 (list
  (cons
   'start
   (Block
    '()
  (list
   (Instr 'movq (list (Imm 1) (Deref 'rbp -8)))
   (Instr 'movq (list (Imm 42) (Reg 'rcx)))
   (Instr 'movq (list (Deref 'rbp -8) (Deref 'rbp -8)))
   (Instr 'addq (list (Imm 7) (Deref 'rbp -8)))
   (Instr 'movq (list (Deref 'rbp -8) (Deref 'rbp -16)))
   (Instr 'movq (list (Deref 'rbp -8) (Deref 'rbp -8)))
   (Instr 'addq (list (Reg 'rcx) (Deref 'rbp -8)))
   (Instr 'movq (list (Deref 'rbp -16) (Reg 'rcx)))
   (Instr 'negq (list (Reg 'rcx)))
   (Instr 'movq (list (Deref 'rbp -8) (Reg 'rax)))
   (Instr 'addq (list (Reg 'rcx) (Reg 'rax)))
   (Jmp 'conclusion)))))))

(define (patch-instructions-instr instr)
  (match instr
    [(Instr op `(,arg1 ,arg2))
     (cond
       [(or (equal? op 'addq)
            (equal? op 'movq)
            (equal? op 'subq))
        (cond
          [(both-memory? (list arg1 arg2)) (list (Instr 'movq (list arg1 (Reg 'rax)))
                                                 (Instr op (list (Reg 'rax) arg2)))] 
          [else (list instr)])]
       [else (list instr)])]
    [else (list instr)]))

; both-memory? : [ListOf Arg] -> Boolean
(define (both-memory? loa)
  (foldr (λ (a rest) (match a
                       [(Deref reg int) rest]
                       [else false]))
         true
         loa))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; p&c

; stack-size : Dictionary -> Integer
; make stack-size a multiple of 16
(define (stack-size dict)
  (let ([dict-size (length dict)])
    (if (even? dict-size)
        (* dict-size 8)
        (+ (* dict-size 8) 8))))

;; prelude-and-conclusion : x86 -> x86
(define (prelude-and-conclusion p)
  (match p
    [(X86Program info lopr)
     (let* ([pr (car lopr)]
            [label (car pr)]
            [block (cdr pr)])
       (match block
         [(Block binfo instr)
          (X86Program (dict-set info
                                'stack-size
                                (stack-size (dict-ref 'used-callee info)))
                      (list 
                            (build-main info)
                            (build-start instr)
                            (build-conclusion info)))]))]))

(define (build-main info)
  (cons 'main
        (Block '()
               (list
                (Instr 'pushq (list (Reg 'rbp)))
                (Instr 'movq (list (Reg 'rsp) (Reg 'rbp)))
                (Instr 'subq (list (Imm (dict-ref info 'stack-space)) (Reg 'rsp)))
                (Jmp 'start)))))

(define (build-start instr)
  (cons 'start
        (Block '()
               instr)))

(define (build-conclusion info)
  (cons 'conclusion
        (Block '()
               (list
                (Instr 'addq (list (Imm (dict-ref info 'stack-space)) (Reg 'rsp)))
                (Instr 'popq (list (Reg 'rbp)))
                (Retq)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; print x86
#| x86
reg ::= rsp | rbp | rax | rbx | rcx | rdx | rsi | rdi |
r8 | r9 | r10 | r11 | r12 | r13 | r14 | r15

arg ::= (Imm int) | (Reg reg) | (Deref reg int)

instr ::= (Instr addq (arg arg)) | (Instr subq (arg arg))
| (Instr movq (arg arg)) | (Instr negq (arg))
| (Callq label int) | (Retq) | (Pushq arg) | (Popq arg) | (Jmp label)

block ::= (Block info (instr …))

x86Int ::= (X86Program info ((label . block)…))


(define print_x86
  (λ (p)
    (match p
      [(X86Program `((stack-space . ,size)) blocks)
       (let ([label (car (car blocks))]
             [block (cdr (car blocks))])
         (map (λ (block)
                (cons label
                      (map print-x86-instr block)))
              blocks))])))

(define print-x86-instr
  (λ (i)
    (match i
      [(Instr addq `(,arg1 ,arg2))
 |#      

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Define the compiler passes to be used by interp-tests and the grader
;; Note that your compiler file (the file that defines the passes)
;; must be named "compiler.rkt"
(define compiler-passes
  `( ("uniquify" ,uniquify ,interp-Rvar)
     ("remove complex opera*" ,remove-complex-opera* ,interp-Rvar)
     ("explicate control" ,explicate-control ,interp-Cvar)
     ("instruction selection" ,select-instructions ,interp-x86-0)
     ;("assign homes" ,assign-homes ,interp-x86-0)
     ("liveness analysis" ,uncover-lives ,interp-x86-0)
     ("build interference graph" ,build-inter-graph ,interp-x86-0)
     ("allocate registers" ,allocate-registers ,interp-x86-0)
     ("patch instructions" ,patch-instructions ,interp-x86-0)
     ("prelude-and-conclusion" ,prelude-and-conclusion ,interp-x86-0)
     ))

