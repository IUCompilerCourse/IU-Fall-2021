## Functions in x86, continued

Last time we finished with a discussion of taking a function's address
and then doing an indirect call.

The address of a label can be obtained using the `leaq` instruction
and PC-relative addressing:

    leaq add1(%rip), %rbx

Calling a function whose address is in a register, i.e., indirect
function call.

    callq *%rbx


### Abstract Syntax:

    arg ::= ... | (FunRef label)
    instr ::= ... | (IndirectCallq arg) | (TailJmp arg) 
           | (Instr 'leaq (list arg arg))
    def ::= (Def label '() '() info ((label . block) ...))
    pseudo-x86 ::= (ProgramDefs info (def...))

### Calling Conventions

The `callq` instruction
1. pushes the return address onto the stack
2. jumps to the target label or address (for indirect call)

But there is more to do to make a function call:
1. parameter passing
2. pushing and popping frames on the procedure call stack
3. coordinating the use of registers for local variables


#### Parameter Passing

The C calling convention uses the following six registers (in that order)
for argument passing:

    rdi, rsi, rdx, rcx, r8, r9

The calling convention says that the stack may be used for argument
passing if there are more than six arguments, but we shall take an
alternate approach that makes it easier to implement efficient tail
calls. If there are more than six arguments, then `r9` will store a
tuple containing the sixth argument and the rest of the arguments.

#### Pushing and Popping Frames

The instructions for each function will have a prelude and conclusion
similar to the one we've been generating for `main`.

The most important aspect of the prelude is moving the stack pointer
down by the size needed the function's frame. Similarly, the
conclusion needs to move the stack pointer back up.

Recall that we are storing variables of vector type on the root stack.
So the prelude needs to move the root stack pointer `r15` up and the
conclusion needs to move the root stack pointer back down.  Also, in
the prelude, this frame's slots in the root stack must be initialized
to `0` to signal to the garbage collector that those slots do not yet
contain a pointer to a vector.

As we did for `main`, the prelude must also save the contents of the
old base pointer `rbp` and set it to the top of the frame, so that we
can use it for accessing local variables that have been spilled to the
stack.

|Caller View    | Callee View   | Contents       |  Frame 
|---------------|---------------|----------------|---------
| 8(%rbp)       |               | return address | 
| 0(%rbp)       |               | old rbp        |
| -8(%rbp)      |               | callee-saved   |  Caller (e.g. map)
|  ...          |               |   ...          |
| -8(j+1)(%rbp) |               | spill          |
|  ...          |               |   ...          |
|               | 8(%rbp)       | return address | 
|               | 0(%rbp)       | old rbp        |
|               | -8(%rbp)      | callee-saved   |  Callee (e.g. add1 as f)
|               |  ...          |   ...          |
|               | -8(j+1)(%rbp) | spill          |
|               |  ...          |   ...          |


#### Coordinating Registers

Recall that the registers are categorized as either caller-saved or
callee-saved. 

If the function uses any of the callee-saved registers, then the
previous contents of those registers needs to be saved and restored in
the prelude and conclusion of the function.

Regarding caller-saved registers, nothing new needs to be done.
Recall that we make sure not to assign call-live variables to
caller-saved registers.

#### Efficient Tail Calls

Normally the amount of stack space used by a program is O(d) where d
is the depth of nested function calls.

This means that recursive functions almost always use at least O(n)
space.

However, we can sometimes use much less space.

A *tail call* is a function call that is the last thing to happen
inside another function.

Example: the recursive call to `tail_sum` is a tail call.

    (define (tail_sum [n : Integer] [r : Integer]) : Integer
      (if (eq? n 0) 
          r
          (tail_sum (- n 1) (+ n r))))

    (+ (tail_sum 3 0) 36)

In Python:

	def tail_sum(n : int, r : int) -> int:
		if n == 0:
			return r
		else:
			return tail_sum(n - 1, n + r)

    print( tail_sum(3, 0) + 36)

Because a tail call is the last thing to happen, we no longer need the
caller's frame and can reuse that stack space for the callee's frame.
So we can clean up the current frame and then jump to the callee.
However, some care must be taken regarding argument passing.

The standard convention for passing more than 6 arguments is to use
slots in the caller's frame. But we're deleting the caller's frame.
We could use the callee's frame, but its difficult to move all the
variables without stomping on eachother because the caller and callee
frames overlap in memory. This could be solved by using auxilliary
memory somewhere else, but that increases the amount of memory
traffic.

We instead recommend using the heap to pass the arguments that don't
fit in the 6 registers.

Instead of `callq`, use `jmp` for the tail call because the return
address that is already on the stack is the correct one.

Use `rax` to hold the target address for an indirect jump.

## Shrink

    (ProgramDefsExp info defs exp)
    ==>
    (ProgramDefs info (append defs (list mainDef)))
    
where `mainDef` is

    (Def 'main '() 'Integer '() exp')

## Reveal Functions (new)

We'll need to generate `leaq` instructions for references to
functions, so it makes sense to differentiate them from let-bound
variables.

    (Var x)
    ==>
    (Var x)

    (Var f)
    ==>
    (FunRef f)


    (Let x (Bool #t)
      (Apply (If (Var x) (Var 'add1) (Var 'sub1)) 
             (Int 41)))
    => 
    (Let x (Bool #t)
      (Apply (If (Var x) (FunRef 'add1) (FunRef 'sub1)) 
             (Int 41)))


## Limit Functions (new)

Transform functions so that have at most 6 parameters.

### Function definition

    (Def f ([x1 : t1] ... [xn : tn]) rt info body)
    ==>
    (Def f ([x1 : t1] ... [x5 : t5] [vec : (Vector t6 ... tn)]) rt info
       new-body)

and transform the `body`, replace occurences of parameters `x6` and
higher as follows

    x6
    ==>
    (vector-ref vec 0)
    
    x7
    ==>
    (vector-ref vec 1)

    ...

### Function application

If there are more than 6 arguments, pass arguments 6 and higher in a
vector:

    (Apply e0 (e1 ... en))
    ==>
    (Apply e0 (e1 ... e5 (vector e6 ... en)))


## Remove Complex Operands

Treat `FunRef` and `Apply` as complex operands.

    (Prim '+ (list (Int 5) (FunRef add1)))
    =>
    (Let ([tmp (FunRef add1)])
      (Prim '+ (list (Int 5) (Var tmp))))

Arguments of `Apply` need to be atomic expressions.


## Explicate Control

* assignment
* tail
* predicate

Add cases for `FunRef` and `Apply` to the three helper functions
for assignment, tail, and predicate contexts.

In assignment and predicate contexts, `Apply` becomes `Call`.

In tail contexts, `Apply` becomes `TailCall`.

You'll need a new helper function for function definitions.
The code will be similar to the previous code for `Program`

Previous assignment:

    (define/override (explicate-control p)
      (match p
        [(Program info body)
         (set! control-flow-graph '())
         (define-values (body-block vars) (explicate-tail body))
         (define new-info (dict-set info 'locals vars))
         (Program new-info
                  (CFG (dict-set control-flow-graph 'start body-block)))]
         ))

adapt the above to process every function definition.


## Uncover Locals

Add a case for `TailCall` to the helper for tail contexts.

Create a new helper function for function definitions.
Again, it will be similar to the previous code for `Program`.


## Select Instructions

### `FunRef` becomes `leaq`

We'll keep `FunRef` as an instruction argument for now,
placing it in a `leaq` instruction.

    (Assign lhs (FunRef f))
    ==>
    (Instr 'leaq (list (FunRef f) lhs'))

### `Call` becomes `IndirectCallq`

    (Assign lhs (Call fun (arg1 ... argn)))
    ==>
    movq arg'1 rdi
    movq arg'2 rsi
    ...
    (IndirectCallq fun')
    (Instr 'movq (Reg 'rax) lhs')

### `TailCall` becomes `TailJmp`

We postpone the work of popping the frame until later by inventing an
instruction we'll call `TailJmp`.

    (TailCall fun (arg1 ... argn))
    ==>
    movq arg'1 rdi
    movq arg'2 rsi
    ...
    (TailJmp fun')

### Function Definitions

    (Def f ([x1 : T1] ... [xn : Tn]) rt info CFG)
       1. CFG => CFG'
       2. prepend to start block from CFG'
           movq rdi x1
           ...
       4. parameters get added to the list of local variables
    =>
    (Def f '() '() new-info new-CFG)

alternative:
  replace parameters (in the CFG) with argument registers


## Uncover Live

New helper function for function definitions.

`leaq` reads from the first argument and writes to the second.

`IndirectCallq` and `TailJmp` read from their argument and you must
assume they write to all the caller-saved registers.

## Build Interference Graph

New helper function for function definitions.

Compute one interference graph per function.

Spill vector-typed variables that are live during a function call.
(Because our functions make trigger `collect`.) So add interference
edges between those variables and the callee-saved registers.

## Patch Instructions

The destination of `leaq` must be a register.

The destination of `TailJmp` should be `rax`.

    (TailJmp %rbx)
    ==>
    movq %rbx, %rax
    (TailJmp rax)

## Print x86


    (FunRef label) => label(%rip)

    (IndirectCallq arg) => callq *arg
    
    (TailJmp rax)
    =>
    addq frame-size, %rsp         move stack pointer up
    popq %rbx                     callee-saved registers
    ...
    subq root-frame-size, %r15    move root-stack pointer
    popq %rbp                     restore rbp
    jmp *%rax                     jump to the target function
    
