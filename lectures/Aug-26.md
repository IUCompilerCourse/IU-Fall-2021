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

