# Lecture: Compiling L_Var, Uniquify, Remove Complex, Explicate Control

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

* `select_instructions`: convert each L_Var operation into 
  one or more instructions
* `remove_complex_opera*`: ensure that each sub-expression is
  atomic by introducing temporary variables
* `explicate_control`: convert from the AST to basic blocks with jumps
* `assign_homes`: replace variables with stack locations
* `uniquify`: rename variables so they are all unique


In what order should we do these passes?
	
Gordian Knot:
* instruction selection
* register/stack allocation

Doing instruction selection first enables improved register
allocation. For example, instruction selection reveals which function
parameters live in which registers.

On the other hand, we should do instruction selection after register
allocation because register allocation may fail to put some variables
in registers, and x86 instructions may each only access one memory
location (non-register), so the compiler must choose different
instruction sequences depending on the register allocation.

solution: 
1. do instruction selection optimistically, assuming all
	variables are assigned to registers
2. then do register allocation
3. then patch up the instructions using a reserved register (rax)

## Overview of the Passes for Racket and Python L_Var compilers

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


Uniquify (Racket only)
----------------------

This pass gives a unique name to every variable, so that variable
shadowing and scope are no longer important.

We recommend using `gensym` to generate a new name for each variable
bound by a `let` expression.

To update variable occurences to match the new names, use an
association list to map the old names to the new names, extending this
map in the case for `let` and doing a lookup in the case for
variables.

Examples:

    (let ([x 32])
      (let ([y 10])
        (+ x y)))
    =>
    (let ([x.1 32])
      (let ([y.2 10])
        (+ x.1 y.2)))


    (let ([x 32])
      (+ (let ([x 10]) x) x))
    =>
    (let ([x.1 32])
      (+ (let ([x.2 10]) x.2) x.1))


Remove Complex Operators and Operands
-------------------------------------

This pass makes sure that the arguments of each operation are atomic
expressions, that is, variables or integer constants. The pass
accomplishes this goal by inserting temporary variables to replace the
non-atomic expressions with variables.

Racket examples:

    (+ (+ 42 10) (- 10))
    =>
    (let ([tmp.1 (+ 42 10)])
      (let ([tmp.2 (- 10)])
        (+ tmp.1 tmp.2)))


    (let ([a 42])
      (let ([b a])
        b))
    =>
    (let ([a 42])
      (let ([b a])
        b))

and not

    (let ([tmp.1 42])
      (let ([a tmp.1])
        (let ([tmp.2 a])
          (let ([b tmp.2])
            b))))

Python example:

    y = 10
    x = 42 + -y
	print(x + 10)
	=>
	y = 10
	tmp_0 = -y
	x = 42 + tmp_0
	tmp_1 = x + 10
	print(tmp_1)


Grammar of the Racket output:

    atm ::= var | int
    exp ::= atm | (read) | (- atm) | (+ atm atm) 
        | (let ([var exp]) exp)
    L^ANF_Var ::= exp

Grammar of the Python output

    atm ::= Constant(int) | Name(var)
    exp ::= atm | Call(Name('input_int'), []) 
        | UnaryOp(USub(), atm) | BinOp(atm, Add(), atm)
    stmt ::= Expr(Call(Name('print'),[atm])) | Expr(exp) | Assign([Name(var)], exp)
    L^ANF_Var ::= Module(stmt*)

Recommended function organization:

    rco_atom : exp -> (Pair atm (Listof (Pair var exp)))
    rco_exp : exp -> exp
    remove-complex-opera* : L_Var -> L^ANF_Var

Inside `rco_atom` and `rco_exp`, for recursive calls, use `rco_atom`
when you need the result to be an atom and use `rco_exp` when you
don't care.

Alternatively, omit `rco_atom` but add a `need_atomic` parameter to `rco_exp`.
Here's the Python version

	Binding = Tuple[Name, expr]
	Temporaries = List[Binding]
	
    def rco_exp(self, e: expr, need_atomic: bool) -> Tuple[expr, Temporaries]
    def rco_stmt(self, s: stmt) -> List[stmt]
    def remove_complex_operands(self, p: Module) -> Module


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
    locals:
      '(x y)
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

    explicate-tail : exp -> (Pair tail (Listof var))
    
    explicate-assign : exp -> var -> tail -> (Pair tail (Listof var))

The `explicate-tail` function takes and L^ANF_Var expression in tail position
and returns a C_Var tail and a list of variables that use to be let-bound
in the expression. This list of variables is then stored in the `info`
field of the `Program` node.

The `explicate-assign` function takes 1) an R1 expression that is not
in tail position, that is, the right-hand side of a `let`, 2) the
`let`-bound variable, and 3) the C0 tail for the body of the `let`.
The output of `explicate-assign` is a C0 tail and a list of variables
that were let-bound. 

Here's a trace of these two functions on the above example.

    explicate-tail (let ([x (let ([y (- 42)]) y)]) (- x))
      explicate-tail (- x)
        => {return (- x);}, ()
      explicate-assign (let ([y (- 42)]) y) x {return (- x);}
        explicate-assign y x {return (- x);}
          => {x = y; return (- x)}, ()
        explicate-assign (- 42) y {x = y; return (- x);}
          => {y = (- 42); x = y; return (- x);}, ()
        => {y = (- 42); x = y; return (- x);}, (y)
      => {y = (- 42); x = y; return (- x);}, (x y)
