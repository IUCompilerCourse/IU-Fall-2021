# Concrete Syntax of L_If

    bool ::= #t | #f
    cmp ::=  eq? | < | <= | > | >= 
    exp ::= int | (read) | (- exp) | (+ exp exp) | (- exp exp)
        | var | (let ([var exp]) exp)
        | bool | (and exp exp) | (or exp exp) | (not exp) 
        | (cmp exp exp) | (if exp exp exp) 
    L_If ::= exp
    
New things:
* Boolean literals: `#t` and `#f`.
* Logical operators on Booleans: `and`, `or`, `not`.
* Comparison operators: `eq?`, `<`, etc.
* The `if` conditional expression. Branching!
* Subtraction on integers.


# Semantics of L_If

    (define (interp-op op)
      (match op
        ...
        ['not (lambda (v) (match v [#t #f] [#f #t]))]
        ['eq? (lambda (v1 v2)
                (cond [(or (and (fixnum? v1) (fixnum? v2))
                           (and (boolean? v1) (boolean? v2)))
                       (eq? v1 v2)]))]
        ['< (lambda (v1 v2)
              (cond [(and (fixnum? v1) (fixnum? v2)) (< v1 v2)]))]
        ...))

    (define (interp-exp env)
      (lambda (e)
        (define recur (interp-exp env))
        (match e
          ...
          [(Bool b) b]
          [(If cnd thn els)
           (define b (recur cnd))
           (match b
             [#t (recur thn)]
             [#f (recur els)])] 
         [(Prim 'and (list e1 e2))
           (define v1 (recur e1))
           (match v1
             [#t (match (recur e2) [#t #t] [#f #f])]
             [#f #f])]
          [(Prim op args)
           (apply (interp-op op) (for/list ([e args]) (recur e)))]
          )))

    (define (interp-Lif p)
      (match p
        [(Program info e)
         ((interp-exp '()) e)]
        ))

Things to note:
* Our treatment of Booleans and operations on them is strict in the
  sense that we don't allow other kinds of values (such as integers)
  to be treated as if they are Booleans.
* `and` is short-circuiting.
* The handling of primitive operators has been factored out
  into an auxilliary function named `interp-op`.


# Type errors and static type checking

In Racket:

    > (not 1)
    #f

    > (car 1)
    car: contract violation
      expected: pair?
      given: 1

In Typed Racket:

    > (not 1)
    #f

    > (car 1)
    Type Checker: Polymorphic function `car' could not be applied to arguments:
    Domains: (Listof a)
             (Pairof a b)
    Arguments: One
    in: (car 1)


A type checker, aka. type system, enforces at compile-time that only
the appropriate operations are applied to values of a given type.

To accomplish this, a type checker must predict what kind of value
will be produced by an expression at runtime.

     (not 1)   ;; not an L_If program!

Type checker:

    (define/public (unary-op-types)
      '((- . ((Integer) . Integer))
     	(not . ((Boolean) . Boolean))
        ))

    (define/public (binary-op-types)
      '((+ . ((Integer Integer) . Integer))
        (- . ((Integer Integer) . Integer))
     	(and . ((Boolean Boolean) . Boolean))
	    (or . ((Boolean Boolean) . Boolean))
     	(< . ((Integer Integer) . Boolean))
     	(<= . ((Integer Integer) . Boolean))
     	(> . ((Integer Integer) . Boolean))
    	(>= . ((Integer Integer) . Boolean))
	))
    
    (define/public (nullary-op-types)
      '((read . (() . Integer))))

    (define (type-check-exp env) ;; return a type: Integer, Boolean
      (lambda (e)
        (match e
          [(Var x) (dict-ref env x)]
          [(Int n) 'Integer]
          [(Bool b) 'Boolean]
          [(Let x e body)
            (define Te ((type-check-exp env) e))
            (define Tb ((type-check-exp (dict-set env x Te)) body))
            Tb]
          ...
          [(If e1 e2 e3)
           (define T1 ((type-check-exp env) e1))
           (unless (equal? T1 'Boolean) (error ...))
           (define T2 ((type-check-exp env) e2))
           (define T3 ((type-check-exp env) e3))
           (unless (equal? T2 T3) (error ...))
           T2]
          [(Prim op es)
            (define-values (new-es ts)
               (for/lists (exprs types) ([e es]) ((type-check-exp env) e)))
            (define t-ret (type-check-op op ts))
            (values (Prim op new-es) t-ret)]
          [else
           (error "type-check-exp couldn't match" e)])))

    (define (type-check env)
      (lambda (e)
        (match e
          [(Program info body)
           (define Tb ((type-check-exp '()) body))
           (unless (equal? Tb 'Integer)
             (error "result of the program must be an integer, not " Tb))
           (Program info body)]
          )))

How should the type checker handle the `if` expression?


# Shrinking L_If

Several of the language forms in L_If are redundant and can be easily
expressed using other language forms. They are present in L_If to make
programming more convenient, but they do not fundamentally increase
the expressiveness of the language. 

To reduce the number of language forms that later compiler passes have
to deal with, we shrink L_If by translating away some of the forms.
For example, subtraction is expressible as addition and negation.

    (and e1 e2)   =>   (if e1 e2 #f)
	(or e1 e2)    =>   (if e1 #t e2)
    
It is possible to shrink many more of the language forms, but
sometimes it can hurt the efficiency of the generated code.
For example, we could express subtraction in terms of addition
and negation:

    (- e1 e2)    => (+ e1 (- e2))
	
but that would result in two x86 instructions instead of one.



