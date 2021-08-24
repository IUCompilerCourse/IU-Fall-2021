# August 26

## Definitional Interpreters 

[`interp-Rint.rkt`](./interp-Rint.rkt)

[`Rint-interp-example.rkt`](./Rint-interp-example.rkt)

Draw correctness diagram.

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


	L_Var
	|    uniquify
	V
	L_Var
	|    remove complex operands
	V
    L_Var
    |    explicate control
    V
	C_Var
	|    select instructions
	V
	x86_Var
	|    assign homes
	V
	x86*
	|    patch instructions
	V
	x86*
	|    prelude & conclusion
	V
	x86




    

