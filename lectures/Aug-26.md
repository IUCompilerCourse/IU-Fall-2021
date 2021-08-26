# August 26

## Teams

## Pattern Matching and Structural Recursion

Examples:

* [`L_Int_height.rkt`](./L_Int_height.rkt)

* [`L_Int_height.py`](./L_Int_height.py)

## Definitional Interpreters for L_Int

[`interp-Rint.rkt`](./interp-Rint.rkt)

[`Rint-interp-example.rkt`](./Rint-interp-example.rkt)

[`interp_Pint.py`](./interp_Pint.py)


## The L_Var Language: L_Int + variables and let

Racket version:

    exp ::= int | (read) | (- exp) | (+ exp exp) 
          | var | (let ([var exp]) exp)
    L_Var ::= exp

Python version:

	exp ::= int | input_int() | - exp | exp + exp | var
	stmt ::= print(exp) | exp | var = exp
	L_Int ::= stmt*

Racket examples:

    (let ([x (+ 12 20)])
      (+ 10 x))

    (let ([x 32]) 
      (+ (let ([x 10]) x) 
         x))

Python examples:

    x = 12 + 20
	print(10 + x)

    x = 33
	x = 10
	print(x + x)

Racket Interpreter for L_Var: [`interp-Rvar.rkt`](./interp-Rvar.rkt)

Python Interpreter for L_Var: [`interp_Pvar.rkt`](./interp_Pvar.rkt)

## x86 Assembly Language

	reg ::= rsp | rbp | rsi | rdi | rax | .. | rdx  | r8 | ... | r15
	arg ::=  $int | %reg | int(%reg) 
	instr ::= addq  arg, arg |
			  subq  arg, arg |
			  negq  arg | 
			  movq  arg, arg | 
			  callq label |
			  pushq arg | 
			  popq arg | 
			  retq 
	prog ::=  .globl main
			   main:  instr^{+}


Intel Machine:
    * program counter
    * registers
    * memory (stack and heap)

Example compilation of a Racket/Python program:

	(+ 10 32)             10 + 32

    =>

		.globl main
	main:
		movq	$10, %rax
		addq	$32, %rax
		movq	%rax, %rdi
		callq	print_int
		movq    $0, %rax
		retq


## What's different?

1. 2 args and return value vs. 2 arguments with in-place update
2. nested expressions vs. atomic expressions
3. order of evaluation: left-to-right depth-first, vs. sequential
4. unbounded number of variables vs. registers + memory
5. variables can overshadow vs. uniquely named registers + memory

* `select_instructions`: convert each L_Var operation into a sequence
  of instructions
* `remove_complex_opera*`: ensure that each sub-expression is
  atomic by introducing temporary variables
* `explicate_control`: convert from the AST to basic blocks with jumps
* `assign_homes`: replace variables with stack locations
* `uniquify`: rename variables so they are all unique


In what order should we do these passes?
	
Gordian Knot: 
* instruction selection
* register/stack allocation

solution: do instruction selection optimistically, assuming all
	  registers then do register allocation then patch up the
	  instructions

Pass for Racket and Python L_Var compilers:

	L_Var                                   L_Var
	|    uniquify                           |    remove complex operands
	V                                       V
	L_Var                                   L_Var
	|    remove complex operands            |    select instructions
	V                                       V
    L_Var                                   x86_Var
    |    explicate control                  |    assign homes
	V                                       V
	C_Var                                   x86*
	|    select instructions                |    patch instructions
	V                                       V
	x86_Var                                 x86*
	|    assign homes                       |    prelude & conclusion
	V                                       V
	x86*                                    x86
	|    patch instructions
	V
	x86*
	|    prelude & conclusion
	V
	x86




    

