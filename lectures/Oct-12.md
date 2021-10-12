# Lecture: Compiling Loops


## Remove Complex Operands

The condition of `while` may be a complex expression.

For Racketeers, `while`, `set!`, and `begin` are complex expressions
and all their subexpressions are allowed to be complex.


## Explicate Control

For Racketeers, the `begin` expression introduces the need for a
new helper function:

    explicate_effect : exp -> tail -> tail

which is a lot like `explicate_tail` except that when the expression
is obviously pure (no side effects) it can be discarded.

    explicate_effect (WhileLoop cnd body) cont
	=>
	goto loop
	
	where
	body' = explicate_effect body (goto loop)
	loop-body = explciate_effect cnd body' cont
	
	loop:
	    loop-body


## Select Instructions

Racket: A call to `read` may now appear as a stand-alone statements.


## Challenge: Constant Propagation

The idea is that when a variable's value is a constant, replace
uses of the variable with that constant.


### Example 1

Racket program:

	(let ([a 42])
	  (let ([b a])
		b))

after instruction selection:

	start:
		movq $42, a63570
		movq a63570, b63571
		movq b63571, %rax
		jmp conclusion
        

after constant propagation:

	start:
		movq $42, a63570
		movq $42, b63571
		movq $42, %rax
		jmp conclusion


### Example 2

Racket program:

	(let ([y (read)])
	   (let ([x (if (eq? y 0)
				   40
				   777)
				])
		  (+ x 2)))

after instruction selection:

	start:
		callq read_int
		movq %rax, y
		cmpq $0, y
		je block3
		jmp block4
	block4:
		movq $777, x
		jmp block2
	block3:
		movq $40, x
		jmp block2
	block2:
		movq x, %rax
		addq $2, %rax
		jmp conclusion

after constant propagation: (no change)

	start:
		callq read_int
		movq %rax, y
		cmpq $0, y
		je block3
		jmp block4
	block4:
		movq $777, x
		jmp block2
	block3:
		movq $40, x
		jmp block2
	block2:
		movq x, %rax
		addq $2, %rax
		jmp conclusion

