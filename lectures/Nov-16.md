# Lambda: Lexically Scoped Functions

## Example

Racket:

    (define (f [x : Integer]) : (Integer -> Integer)
       (let ([y 4])
          (lambda: ([z : Integer]) : Integer
             (+ x (+ y z)))))

    (let ([g (f 5)])
      (let ([h (f 3)])
        (+ (g 11) (h 15))))

Python:

	def f(x : int) -> Callable[[int], int]:
		y = 4
		return lambda z: x + y + z

	g = f(5)
	h = f(3)
	print( g(11) + h(15) )


## Syntax

concrete syntax:

    exp ::= ... | (lambda: ([var : type]...) : type exp)
    Llambda ::= def* exp

abstract syntax:

    exp ::= ... | (Lambda ([var : type]...) type exp)
    Llambda ::= (ProgramDefsExp info def* exp)

    (Let var exp exp)

## Interpreter for Llambda

see `interp-Rlambda.rkt`:

* case for lambda, 
* case for application, 
* case for define (mcons), 
* case for program (backpatching).

## Type Checker for Llambda

see `type-check-Rlambda.rkt`:

The case for lambda.

## Free Variables

Def. A variable is *free with respect to an expression* e if the
variable occurs inside e but does not have an enclosing binding in e.

Use above example to show examples of free variables.

## Closure Representation

Figure 7.2 in book, diagram of g and h from above example.

# Closure Conversion Pass (after reveal-functions)

1. Translate each lambda into a "flat closure"

    (lambda: (ps ...) : rt body)
    ==>
    (vector (function-ref name) fvs ...)

2. Generate a top-level function for each lambda

    (define (lambda_i [clos : _] ps ...)
      (let ([fv_1 (vector-ref clos 1)])
        (let ([fv_2 (vector-ref clos 2)])
          ...
          body')))
        
3. Translate every function application into an application of a closure:

    (e es ...)
    ==>
    (let ([tmp e'])
      ((vector-ref tmp 0) tmp es' ...))

## Example

    (define (f (x : Integer)) : (Integer -> Integer)
      (let ((y 4))
         (lambda: ((z : Integer)) : Integer
           (+ x (+ y z)))))

     (let ((g ((fun-ref f) 5)))
        (let ((h ((fun-ref f) 3)))
           (+ (g 11) (h 15))))
           
    ==>
    
    (define (f (clos.1 : _) (x : Integer)) : (Vector ((Vector _) Integer -> Integer))
       (let ((y 4))
          (vector (fun-ref lam.1) x y)))
          
    (define (lam.1 (clos.2 : (Vector _ Integer Integer)) (z : Integer)) : Integer
       (let ((x (vector-ref clos.2 1)))
          (let ((y (vector-ref clos.2 2)))
             (+ x (+ y z)))))
             
     (let ((g (let ((t.1 (vector (fun-ref f))))
                ((vector-ref t.1 0) t.1 5))))
        (let ((h (let ((t.2 (vector  (fun-ref f))))
                   ((vector-ref t.2 0) t.2 3))))
           (+ (let ((t.3 g)) ((vector-ref t.3 0) t.3 11))
              (let ((t.4 h)) ((vector-ref t.4 0) t.4 15)))))
