### Graph Copy via Cheney's Algorithm

* breadth-first search (quick reminder what that is) uses a queue
* Cheney: use the ToSpace as the queue, use two pointers to keep
  track of the front (scan pointer) and back (free pointer) of the queue.
    1. Copy tuples pointed to by the root set into the ToSpace
       to form the initial queue.
    2. While copying a tuple, mark the old one and store the
       address of the new tuple inside the old tuple.
       This is called a *forwarding pointer*.
    3. Start processing tuples from the front of the queue.  For
       each tuple, copy the tuples that are directly reachable from
       it to the back of the queue in the ToSpace, unless the tuple
       has already been copied.  Update the pointers in the
       processed tuple to the copies or the forwarding pointer.
* Draw Fig. 5.7

An implementation of a garbage collector is in `runtime.c`.


### Data Representation

Problems: 
1. how to differentiate pointers from other things on the
  procedure call stack? 
2. how can the GC access the pointers that are in registers?
3. how to differentiate poitners from other things inside tuples?

Solutions:
1. Use a root stack (aka. shadow stack), i.e., place all
   tuples in a separate stack that works in parallel to the
   normal stack.  Draw Fig. 5.7.
2. Spill vector-typed variables to the root stack if they are
   live during a call to the collector.
3. Add a 64-bit header or "tag" to each tuple. (Fig. 5.8)
   The header includes 
	* 1 bit to indicate forwarding (0) or not (1). If 0, then
	  the header is the forwarding pointer.
	* 6 bits to store the length of the tuple (max of 50)
	* 50 bits for the pointer mask to indicate which elements 
	  of the tuple are pointers.



### type checking and type information

Racket: The `type-check-Rvec` function wraps a `HasType` around each
`vector` creation expression.

           (HasType (Prim 'vector es) (Vector ts))

Python: The `type_check_Ltup` writes the tuple type into a new
`has_type` field in the `Tuple` AST node.

This type information is used in the `expose_allocation` pass.

Racket: The `type-check-Cvec` function stores an alist mapping
variables to their types in the `info` field, under the key
`locals-types`, of the `CProgram` AST node.

Python: The `type_check_Ctup` stores a dictionary mapping variables to
their types into a new `var_types` field of the `CProgram` AST node.

This type information is used in the register allocator and in the
generation of the prelude and conclusion.


### expose-allocation (new)

Lower tuple creation into a call to collect, a call to allocate, and
then initialize the memory (see 5.3.1).

Make sure to place the code for sub-expressions prior to the call to
collect. Sub-expressions may also call collect, and we can't have
partially constructed tuples during collect!

New forms in the output language:

        exp ::= ...
         | (Collect int)       call the GC and you're going to need `int` bytes
         | (Allocate int type) allocate `int` many bytes, `type` is the type of the tuple
         | (GlobalValue name)  access global variables e.g. free_ptr, fromspace_end

* `free_ptr`: the next empty spot in the FromSpace
* `fromspace_end`: the end of the FromSpace

For Python, we need a way to intialize the tuple elements.

1. We introduce a `Begin` expression that contains a list of statements
   and a result expression, and
2. Allow `Subscript` on the left-hand side of an assignment

Grammar:

    exp ::= ... | (Begin stmt ... exp)

    lhs ::= Name(var) | Subscript(exp, exp)
    stmt ::= ... | Assign(lhs, exp)


### remove-complex-opera*
  
The new forms Collect, Allocate, GlobalValue, Begin, Subscript should
be treated as complex operands. Operands of Subscript need to be
atomic.

### explicate-control
  
straightforward additions to handle the new forms
    
### select-instructions
  
Here is where we implement the new operations needed for tuples.

example: block9056

* tuple write turns into movq with a deref in the target

    Racket:

        lhs = (vector-set! tup n arg);
        
    becomes
    
        movq tup', %r11
        movq arg', 8(n+1)(%r11)
        movq $0, lhs'

    Python:
	
        tup[n] = arg
		
	becomes
	
        movq tup', %r11
        movq arg', 8(n+1)(%r11)

    what if we use `rax` instead of `r11`:

        movq tup', %rax
        movq -16(%rbp), 8(n+1)(%rax)
        movq $0, lhs'

        movq tup', %rax
        movq -16(%rbp), %rax
        movq %rax, 8(n+1)(%rax)
        movq $0, lhs'


    We use `r11` for temporary storage, so we remove it from the list
    of registers used for register allocation.

* tuple read turns into a movq with deref in the source

    Racket/Python:

        lhs = (vector-ref tup n);
		
		lhs = tup[n]
        
    becomes
    
        movq tup', %r11
        movq 8(n+1)(%r11), lhs'

* `allocate`

   1. put the current `free_ptr` into lhs
   2. move the `free_ptr` forward by 8(len+1)   (room for tag)
   3. initialize the tag (use bitwise-ior and arithmetic-shift)
     using the type information for the pointer mask.

   So

        lhs = (allocate len (Vector type ...));
		
        lhs = allocate(len, TupleType([type, ...]))

    becomes
    
        movq free_ptr(%rip), lhs'
        addq 8(len+1), free_ptr(%rip)
        movq lhs', %r11
        movq $tag, 0(%r11)
     
* `collect` turns into a `callq` to the collect function. 

    Pass the top of the root stack (`r15`) in register `rdi` and 
    the number of bytes in `rsi`.

        (collect bytes)
		
        collect(bytes)
        
    becomes
    
        movq %r15, %rdi
        movq $bytes, %rsi
        callq collect
       
### allocate-registers
  
* Spill tuple-typed variables to the root stack. Handle this
  in the code for assigning homes (converting colors to
  stack locations and registers.)
  
  Use `r15` for the top of the root stack. Remove it from
  consideration by the register allocator.

* If a tuple variable is live during a call to collect,
  make sure to spill it. Do this by adding interference edges
  between the call-live tuple variables and the callee-saved
  registers.

### prelude-and-conclusion

* Insert a call to `initialize`, passing in two arguments for the size
  of the rootstack and the size of the heap.

* Move the root stack forward to make room for the tuple spills.

* The first call to collect might happen before all the
  slots in the root stack have been initialized.
  So make sure to zero-initialize the root stack in the prelude!
