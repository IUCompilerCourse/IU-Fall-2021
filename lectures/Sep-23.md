# More x86 with an eye toward instruction selection for LIf

    cc ::= e | l | le | g | ge
    instr ::= ... | xorq arg, arg | cmpq arg, arg | set<cc> arg
          | movzbq arg, arg | j<cc> label 

x86 assembly does not have Boolean values (false and true),
but the integers 0 and 1 will serve.

x86 assembly does not have direct support for logical `not`.
But `xorq` can do the job:

          | 0 | 1 |
          |---|---|
        0 | 0 | 1 |
        1 | 1 | 0 |

    var = (not arg);       =>       movq arg, var
                                    xorq $1, var

The `cmpq` instruction can be used to implement `eq?`, `<`, etc.  But
it is strange. It puts the result in a mysterious EFLAGS register.

    var = (< arg1 arg2)    =>       cmpq arg2, arg1
                                    setl %al
                                    movzbq %al, var

The `cmpq` instruction can also be used for conditional branching.
The conditional jump instructions `je`, `jl`, etc. also read
from the EFLAGS register.

    if (eq? arg1 arg2)    =>       cmpq arg2, arg1
      goto l1;                     je l1
    else                           jmp l2
      goto l2;


# The CIf intermediate language

Syntax of CIf

    bool ::= #t | #f
    atm ::= int | var | bool
    cmp ::= eq? | < | <= | > | >=
    exp ::= ... | (not atm) | (cmp atm atm)
    stmt ::= ...
    tail ::= ... 
         | goto label; 
         | if (cmp atm atm) 
             goto label; 
           else
             goto label;
    CIf ::= label1:
               tail1
             label2:
               tail2
             ...

# Explicate Control

Consider the following Racket and Python programs

Racket:

    (let ([x (read)])
      (let ([y (read)])
        (if (if (< x 1) (eq? x 0) (eq? x 2))
            (+ y 2)
            (+ y 10))))

Python:

    x = input_int()
    y = input_int()
    print(y + 2 if (x == 0 if x < 1 else x == 2) else y + 10)

A straightforward way to compile an `if` expression is to recursively
compile the condition, and then use the `cmpq` and `je` instructions
to branch on its Boolean result. Let's first focus in the `(if (< x 1) ...)`.

    ...
    cmpq $1, x          ;; (< x 1)
    setl %al
    movzbq %al, tmp
    cmpq $1, tmp        ;; (if (< x 1) ...)
    je then_branch1
    jmp else_branch1
    ...

But notice that we used two `cmpq`, a `setl`, and a `movzbq`
when it would have been better to use a single `cmpq` with
a `jl`.

    ...
    cmpq $1, x          ;; (if (< x 1) ...)
    jl then_branch1
    jmp else_branch1
    ...
        
Ok, so we should recognize when the condition of an `if` is a
comparison, and specialize our code generation. But can we do even
better? Consider the outer `if` in the example program, whose
condition is not a comparison, but another `if`.  Can we rearrange the
program so that the condition of the `if` is a comparison?  How about
pushing the outer `if` inside the inner `if`:

Racket:

    (let ([x (read)])
      (let ([y (read)])
        (if (< x 1) 
          (if (eq? x 0)
            (+ y 2)
            (+ y 10))
          (if (eq? x 2)
            (+ y 2)
            (+ y 10)))))

Python:

    x = input_int()
    y = intput_int()
    print(((y + 2) if x == 0 else (y + 10)) \
          if (x < 1) \
          else ((y + 2) if (x == 2) else (y + 10)))

Unfortunately, now we've duplicated the two branches of the outer `if`.
A compiler must *never* duplicate code!

Now we come to the reason that our Cn programs take the forms of a
*graph* instead of a *tree*. A graph allows multiple edges to point to
the same vertex, thereby enabling sharing instead of duplication. The
nodes of this graph are the labeled `tail` statements and the edges
are expressed with `goto`.

Using these insights, we can compile the example to the following CIf
program.
    
    (let ([x (read)])
      (let ([y (read)])
        (if (if (< x 1) (eq? x 0)  (eq? x 2))
            (+ y 2)
            (+ y 10))))
    =>
	start:
		x = (read);
		y = (read);
		if (< x 1)
		   goto block_8;
		else
		   goto block_9;
	block_8:
		if (eq? x 0)
		   goto block_4;
		else
		   goto block_5;
	block_9:
		if (eq? x 2)
		   goto block_6;
		else
		   goto block_7;
	block_4:
		goto block_2;
	block_5:
		goto block_3;
	block_6:
		goto block_2;
	block_7:
		goto block_3;
	block_2:
		return (+ y 2);
	block_3:
		return (+ y 10);

Python:

    x = input_int()
    y = input_int()
    print(y + 2 if (x == 0 if x < 1 else x == 2) else y + 10)
    =>
    start:
      x = input_int()
      y = input_int()
      if x < 1:
        goto block_8
      else:
        goto block_9
    block_8:
      if x == 0:
        goto block_4
      else:
        goto block_5
    block_9:
      if x == 2:
        goto block_6
      else:
        goto block_7
    block_4:
      goto block_2
    block_5:
      goto block_3
    block_6:
      goto block_2
    block_7:
      goto block_3
    block_2:
      tmp_0 = y + 2
      goto block_1
    block_3:
      tmp_0 = y + 10
      goto block_1
    block_1:
      print(tmp_0)
      return 0


Notice that we've acheived both objectives.
1. The condition of each `if` is a comparison.
2. We have not duplicated the two branches of the outer `if`.


Racket:
    
	explicate-tail : LIf_exp -> CIf_tail
 	    generates code for expressions in tail position
	explicate-assign : LIf_exp -> var -> CIf_tail -> CIf_tail
	    generates code for an `let` by cases on the right-hand side expression
	explicate-pred : LIf_exp x CIf_tail x CIf_tail -> CIf_tail
	    generates code for an `if` expression by cases on the condition.

Python:

    def explicate_stmt(self, s: stmt, cont: List[stmt],
                       basic_blocks: Dict[str, List[stmt]]) -> List[stmt]
        generates code for statements
    def explicate_assign(self, e: expr, x: Variable, cont: List[stmt],
                         basic_blocks: Dict[str, List[stmt]]) -> List[stmt]
        generates code for an assignment by cases on the right-hand side expression.
    def explicate_effect(self, e: expr, cont: List[stmt],
                         basic_blocks: Dict[str, List[stmt]]) -> List[stmt]
		generates code for expressions as statements, so their result is
		ignored and only their side effects matter.
    def explicate_pred(self, cnd: expr, thn: List[stmt], els: List[stmt],
                       basic_blocks: Dict[str, List[stmt]]) -> List[stmt]
        generates code for `if` expression or statement by cases on the condition.


Example:

    (let ([x (read)])
       (if (eq? x 0) 42 777))

    x = input_int()
	if x == 0:
	    print(42)
	else:
	    print(777)

Example:
    
	(let ([y (read)])
	   (let ([x (if (eq? y 0) 40 777)])
	      (+ x 2)))

    y = input_int()
	x = (40 if y == 0 else 777)
	print(x + 2)

Example:

    (if #t 42 777)
	
	if True:
	    print(42)
	else:
	    print(777)
		
Example:

    (let ([x (read)])
      (let ([y (read)])
        (if (if (< x 1) (eq? x 0)  (eq? x 2))
            (+ y 2)
            (+ y 10))))

    x = input_int()
    y = input_int()
    print(y + 2 if (x == 0 if x < 1 else x == 2) else y + 10)

