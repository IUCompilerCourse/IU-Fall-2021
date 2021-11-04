# Compiling Functions

## The Lfun Language

Concrete Syntax for Racket:

    type ::= ... | (type... -> type)
    exp ::= ... | (exp exp...)
    def ::= (define (var [var : type]...) : type exp)
    Lfun ::= def... exp

Concrete Syntax for Python:

    type ::= ... | Callable[[type, ...], type]
    exp ::= ... | exp(exp, ...)
    def ::= def var(var : type,...) -> type: stmt ...
    Lfun ::= def... stmt...

Abstract Syntax for Racket:

    exp ::= ... | (Apply exp exp...)
    def ::= (Def var ([var : type] ...) type '() exp)
    Lfun ::= (ProgramDefsExp '() (def ...) exp)

Abstract Syntax for Python:

    type ::= ... | FunctionType(type*, type)
    exp ::= ... | Call(exp, exp*)
    def ::= FunctionDef(var, [(var, type) ,...], type, stmt*)
    Lfun ::= Module([def... stmt...])

* Because of the function type, functions are first-class in that they
  can be passed as arguments to other functions and returned from
  them. They can also be stored inside tuples.
  
* Functions may be recursive and even mutually recursive.  That is,
  each function name is in scope for the entire program.

Example program in Racket:

    (define (map [f : (Integer -> Integer)]
                 [v : (Vector Integer Integer)]) : (Vector Integer Integer)
       (vector (f (vector-ref v 0)) (f (vector-ref v 1))))
       
    (define (add1 [x : Integer]) : Integer
       (+ x 1))
       
    (vector-ref (map add1 (vector 0 41)) 1)
    
Example program in Python:

	def map(f : Callable[[int], int], v : tuple[int,int]) -> tuple[int,int]:
		return f(v[0]), f(v[1])

	def inc(x : int) -> int:
		return x + 1

	print( map(inc, (0, 41))[1] )

Go over the interpreter (Fig. 6.4)

Go over the type checker.

## Functions in x86

Labels can be used to mark the beginning of a function

The address of a label can be obtained using the `leaq` instruction
and PC-relative addressing:

    leaq add1(%rip), %rbx

Calling a function whose address is in a register, i.e., indirect
function call.

    callq *%rbx

