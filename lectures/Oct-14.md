# Lecture: Tuples and Garbage Collection

The language Lvec

Racket:

    exp ::= ... 
	    | (vector exp+)                  create a tuple
		| (vector-ref exp int)           read the nth element
        | (vector-set! exp int exp)      write to the nth element

Python:

    exp ::= ...
        | ( exp , ... )                  create a tuple
        | exp [ exp ]                    read the nth element

Python tuples do not support writing, they are immutable.

Racket example:

    (let ([t (vector 40 #t (vector 2))])
      (if (vector-ref t 1)
          (+ (vector-ref t 0)
             (vector-ref (vector-ref t 2) 0))
          44))
	==>
	42

Python example:

    t = (40, True, (2,))
	print( t[0] + t[2][0] if t[1] else 44 )
	==>
	42

## Aliasing

	(let ([t1 (vector 3 7)])
	  (let ([t2 t1])
		(let ([_ (vector-set! t2 0 42)])
		  (vector-ref t1 0))))
	==>
	42


## Tuple Lifetime

	(let ([v (vector (vector 44))])
	  (let ([x (let ([w (vector 42)])
				 (let ([_ (vector-set! v 0 w)])
				   0))])
		(+ x (vector-ref (vector-ref v 0) 0))))
    ===>
	42



## Garbage Collection

Def. The *live data* are all of the tuples that might be accessed by
the program in the future. We can overapproximate this as all of the
tuples that are reachable, transitively, from the registers or
procedure call stack. We refer to the registers and stack collectively
as the *root set*.

The goal of a garbage collector is to reclaim the data that is not
live.

We shall use a 2-space copying collector, using Cheney's algorithm
(BFS) for the copy.

Alternative garbage collection techniques:
* generational copy collectors
* mark and sweep
* reference counting + mark and sweep

Overview of how GC fits into a running program.:

0. Ask the OS for 2 big chunks of memory. Call them FromSpace and ToSpace.
1. Run the program, allocating tuples into the FromSpace.
2. When the FromSpace is full, copy the *live data* into the ToSpace.
3. Swap the roles of the ToSpace and FromSpace and go back to step 1.

Draw Fig. 5.6. (just the FromSpace)

