# Lecture: Explicate, Select, Assign, Patch, Prelude & Conclusion

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

## Explicate Control (Racket only)

This pass makes the order of evaluation simple and explicit in the
syntax.  For now, this means flattening `let` into a sequence of
assignment statements.

The target of this pass is the C_Var language.
Here is the grammar for C_Var.

    atm ::= int | var
    exp ::= atm | (read) | (- atm) | (+ atm atm)
    stmt ::= var = exp; 
    tail ::= return exp; | stmt tail 
    C_Var ::= (label: tail)^+
    
Example:

    (let ([x (let ([y (- 42)])
               y)])
      (- x))
    =>
    start:
        y = (- 42);
        x = y;
        return (- x);

Aside regarding **tail position**. Here is the grammar for L^ANF_Var again
but splitting the exp non-terminal into two, one for `tail` position
and one for not-tail `nt` position.

    atm ::= var | int
    nt ::= atm | (read) | (- atm) | (+ atm atm) 
       | (let ([var nt]) nt)
    tail ::= atm | (read) | (- atm) | (+ atm atm) 
         | (let ([var nt]) tail)
    L^ANF_Var' ::= tail

Recommended function organization:

    explicate-tail : exp -> tail
    
    explicate-assign : exp -> var -> tail -> tail

The `explicate-tail` function takes and L^ANF_Var expression in tail position
and returns a C_Var tail.

The `explicate-assign` function takes 1) an R1 expression that is not
in tail position, that is, the right-hand side of a `let`, 2) the
`let`-bound variable, and 3) the C0 tail for the body of the `let`.
The output of `explicate-assign` is a C0 tail. 

Here's a trace of these two functions on the above example.

    explicate-tail (let ([x (let ([y (- 42)]) y)]) (- x))
      explicate-tail (- x)
        => {return (- x);}
      explicate-assign (let ([y (- 42)]) y) x {return (- x);}
        explicate-assign y x {return (- x);}
          => {x = y; return (- x)}
        explicate-assign (- 42) y {x = y; return (- x);}
          => {y = (- 42); x = y; return (- x);}
        => {y = (- 42); x = y; return (- x);}
      => {y = (- 42); x = y; return (- x);}

## Select Instructions

Translate statements into x86-style instructions.

For example

    x = (+ 10 32);
    =>
    movq $10, x
    addq $32, x

Some cases can be handled with a single instruction.

    x = (+ 10 x);
    =>
    addq $10, x
    

The `read` operation must be turned into a 
call to the `read_int` function in `runtime.c`.

    x = (read);                   x = input_int()
    =>
    callq read_int
    movq %rax, x
    
The return statement is treated like an assignment to `rax` followed
by a jump to the `conclusion` label.

    return e;
    =>
    instr
    jmp conclusion
    
where

    rax = e;
    =>
    instr
    
    
## The Stack and Procedure Call Frames

The stack is a conceptually sequence of frames, one for each procedure
call. The stack grows down.

The *base pointer* `rbp` is used for indexing into the frame.

The *stack poitner* `rsp` points to the top of the stack.

| Position  | Contents       |
| --------- | -------------- |
| 8(%rbp)   | return address |
| 0(%rbp)   | old rbp        |
| -8(%rbp)  | variable 1     |
| -16(%rbp) | variable 2     |
| -24(%rbp) | variable 3     |
|   ...     |    ...         |
| 0(%rsp)   | variable n     |


## Assign Homes

Replace variables with stack locations.

Consider the program `(+ 52 (- 10))`.

Suppose we have two variables in the pseudo-x86, `tmp.1` and `tmp.2`.
We places them in the -16 and -8 offsets from the base pointer `rbp`
using the `deref` form.

    movq $10, tmp.1
    negq tmp.1
    movq tmp.1, tmp.2
    addq $52, tmp.2
    movq tmp.2, %rax
    =>
    movq $10, -16(%rbp)
    negq -16(%rbp)
    movq -16(%rbp), -8(%rbp)
    addq $52, -8(%rbp)
    movq -8(%rbp), %rax
    

## Patch Instructions

Continuing the above example, we need to ensure that
each instruction follows the rules of x86. 

For example, the move from stack location -16 to -8 uses two memory
locations in the same instruction. So we split it up into two
instructions and use rax to hold the value at location -16.

    movq $10 -16(%rbp)
    negq -16(%rbp)
    movq -16(%rbp) -8(%rbp) *
    addq $52 -8(%rbp)
    movq -8(%rbp) %rax
    =>
    movq $10 -16(%rbp)
    negq -16(%rbp)
    movq -16(%rbp), %rax *
    movq %rax, -8(%rbp)  *
    addq $52, -8(%rbp)
    movq -8(%rbp), %rax
    

## Prelude and Conclusion

We generate a prelude and conclusion for the main procedure.

The prelude
1. saves the old base pointer, 
2. moves the base pointer to the top of the stack,
3. moves the stack pointer down passed all the local variables, and
4. jumps to the start label.

The conclusion 
1. moves the stack pointer up passed all the local variables,
2. pops the old base pointer, and
3. returns from the `main` function via `retq` .

Continuing the above example

        .globl _main
    main:
        pushq   %rbp
        movq    %rsp, %rbp
        subq    $16, %rsp
        jmp start

    start:
        movq    $10, -16(%rbp)
        negq    -16(%rbp)
        movq    -16(%rbp), %rax
        movq    %rax, -8(%rbp)
        addq    $52, -8(%rbp)
        movq    -8(%rbp), %rax
        jmp     conclusion
        
    conclusion:
        addq    $16, %rsp
        popq    %rbp
        retq
    
