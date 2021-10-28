# Lecture: Tuples continued

## select-instructions
  
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
       
## allocate-registers
  
* Spill tuple-typed variables to the root stack. Handle this
  in the code for assigning homes (converting colors to
  stack locations and registers.)
  
  Use `r15` for the top of the root stack. Remove it from
  consideration by the register allocator.

* If a tuple variable is live during a call to collect,
  make sure to spill it. Do this by adding interference edges
  between the call-live tuple variables and the callee-saved
  registers.

## prelude-and-conclusion

* Insert a call to `initialize`, passing in two arguments for the size
  of the rootstack and the size of the heap.

* Move the root stack forward to make room for the tuple spills.

* The first call to collect might happen before all the
  slots in the root stack have been initialized.
  So make sure to zero-initialize the root stack in the prelude!

## Example


