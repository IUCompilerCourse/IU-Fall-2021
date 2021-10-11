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


## Remove Jumps

UNDER CONSTRUCTION
