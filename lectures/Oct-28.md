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

        lhs = (Allocate len (Vector type ...));
		
        lhs = Allocate(len, TupleType([type, ...]))

    becomes
    
        movq free_ptr(%rip), lhs'
        addq 8(len+1), free_ptr(%rip)
        movq lhs', %r11
        movq $tag, 0(%r11)
     
* `collect` turns into a `callq` to the collect function. 

    Pass the top of the root stack (`r15`) in register `rdi` and 
    the number of bytes in `rsi`.

        (Collect bytes)
		
        Collect(bytes)
        
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

Source program:

    (vector-ref (vector 42) 0)

    print( (42,)[0] )

expose allocation:

	(vector-ref T 0)


where `T` is

    (let ([_ (if (< (+ (global-value free_ptr) 16) 
                    (global-value fromspace_end))
                 (void)
                 (collect 16))])
       (let ([alloc5 (allocate 1 (Vector Integer))])
          (let ([_6 (vector-set! alloc5 0 42)])
             alloc5)))

remove complex operands:

    (let ([_ (if (let ([tmp8 (global-value free_ptr)])
                         (let ([tmp9 (+ tmp8 16)])
                            (let ([tmp46150 (global-value fromspace_end)])
                               (< tmp9 tmp46150))))
                     (void)
                     (collect 16))])
       (let ([alloc5 (allocate 1 (Vector Integer))])
          (let ([_6 (vector-set! alloc5 0 42)])
             (vector-ref alloc5 0))))

explicate control:

	start:
		tmp8 = (global-value free_ptr);
		tmp9 = (+ tmp8 16);
		tmp46150 = (global-value fromspace_end);
		if (< tmp9 tmp46150)
		   goto block46152;
		else
		   goto block46153;
	block46152:
		_ = (void);
		goto block46151;
	block46153:
		(collect 16)
		goto block46151;
	block46151:
		alloc5 = (allocate 1 (Vector Integer));
		_6 = (vector-set! alloc5 0 42);
		return (vector-ref alloc5 0);

select instructions:

	start:
		movq free_ptr(%rip), tmp8
		movq tmp8, tmp9
		addq $16, tmp9
		movq fromspace_end(%rip), tmp46150
		cmpq tmp46150, tmp9
		jl block46152
		jmp block46153
	block46152:
		movq $0, _7
		jmp block46151
	block46153:
		movq %r15, %rdi
		movq $16, %rsi
		callq collect
		jmp block46151
	block46151:
		movq free_ptr(%rip), %r11
		addq $16, free_ptr(%rip)
		movq $3, 0(%r11)
		movq %r11, alloc5
		movq alloc5, %r11
		movq $42, 8(%r11)
		movq $0, _6
		movq alloc5, %r11
		movq 8(%r11), %rax
		jmp conclusion

prelude and conclusion:

	main:
		pushq %rbp
		movq %rsp, %rbp
		subq $0, %rsp
		movq $65536, %rdi
		movq $65536, %rsi
		callq initialize
		movq rootstack_begin(%rip), %r15
		jmp start
	start:
		movq free_ptr(%rip), %rcx
		addq $16, %rcx
		movq fromspace_end(%rip), %rdx
		cmpq %rdx, %rcx
		jl block46185
		jmp block46186
	block46185:
		movq $0, %rcx
		jmp block46184
	block46186:
		movq %r15, %rdi
		movq $16, %rsi
		callq collect
		jmp block46184
	block46184:
		movq free_ptr(%rip), %r11
		addq $16, free_ptr(%rip)
		movq $3, 0(%r11)
		movq %r11, %rcx
		movq %rcx, %r11
		movq $42, 8(%r11)
		movq $0, %rdx
		movq %rcx, %r11
		movq 8(%r11), %rax
		jmp conclusion
	conclusion:
		subq $0, %r15
		addq $0, %rsp
		popq %rbp
		retq
