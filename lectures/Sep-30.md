# Loops and Dataflow Analysis

## Syntax

Racket:

    exp ::= ... | (while exp exp) | (set! var exp) | (begin exp ... exp)


Python:

    stmt ::= ... | while exp: stmt^+


## Example

Racket:

	(let ([sum 0])
	  (let ([i 5])
		(begin
		  (while (> i 0)
			(begin
			  (set! sum (+ sum i))
			  (set! i (- i 1))))
		  sum)))

Python:

	sum = 0
	i = 5
	while i > 0:
		sum = sum + i
		i = i - 1
	print(sum)


## Type Checking

See `type-check-Rwhile.rkt`.

See `type_check_Lwhile.py`.


## Interpreter

See `interp-Rwhile.rkt`.

See `interp_Lwhile.py`.


## Control-flow Cycles and Dataflow Analysis

The above example, after instruction selection:

	mainstart:
	   movq $0, sum
	   movq $5, i
	   jmp block5
	block5:
	   movq i, tmp3
	   cmpq tmp3, $0
	   jl block7
	   jmp block8
	block7:
	   addq i, sum
	   movq $1, tmp4
	   negq tmp4
	   addq tmp4, i
	   jmp block5
	block8:
	   movq $27, %rax
	   addq sum, %rax
	   jmp mainconclusion

Control-flow graph:

    mainstart
	|
	V
	block5
	|  ^  \_____
	V  |        \
	block7      block8 --> mainconclusion

For liveness analysis, we can no longer topologically sort the CFG.

Observations:

1. If we start processing a block using an empty live-after set, we
   obtain an under-approximation of it's live-before set.  That is,
   the elements of the set will be correct ones, we just might be
   missing some.

2. If we iteratively process all the blocks, we'll eventually come to
   a situation where their live-before sets don't change.  That's
   called a **fixed point**. The Kleene Fixed-Point Theorem tells us
   that the fixed point is correct in the sense that the live after
   sets are no longer missing any elements.

3. While iterating, we don't have to recompute the live-before set of
   a block if the live-before set of its successors didn't change on
   the previous iteration.


### Example dataflow analysis to determine live-before sets

Start with empty live-before sets

	mainstart: {}
	block5: {}
	block7: {}
	block8: {}

Perform liveness analysis on every block:

	mainstart: {}
	block5: {i}
	block7: {i, sum}
	block8: {rsp, sum}
    
We see changes in blocks 5, 7, and 8, so we again perform the analysis
on the blocks that depend on them wrt. liveness (i.e. in-edges), 
which is start, 5, 7, and 8.

	mainstart: {}
	block5: {i, rsp, sum}
	block7: {i, sum}
	block8: {rsp, sum}

We see changes only in `block5`, so we recompute the live-before for
`mainstart` and `block7`.

	mainstart: {rsp}
	block5: {i, rsp, sum}
	block7: {i, rsp, sum}
	block8: {rsp, sum}

We see changes in `block7` and `mainstart`, so we recompute `block5`,
but it doesn't change. So the above is the fixed point.


### Some Lattice Theory

A **lattice** is a set of elements with a partial ordering, written x ⊑ y,
a bottom element ⊥, and a join operator x ⊔ y.

The lattice abstraction is often used in situations where the elements
represent differing amounts of information and the partial ordering 
x ⊑ y means that element y has more (or equal) information than x.

The bottom element ⊥ represents a total lack of information.

The join operator corresponds to combining the information present in
the two elements.

An element x is an **upper bound** of a set S if 
for every element y in S, y ⊑ x.

An element x is a **least upper bound** of a set S if
x is less-or-equal to any other upper bound of S.


### Dataflow Analysis

Dataflow analysis is a generic framework for analyzing programs with
cycles in their control flow.

A dataflow analysis involves two lattices.

1. A lattice to represent abstract states of the program.

2. A lattice that aggregates the states of all the blocks
   in the control-flow graph.

and a function F over the second lattice that expresses how the
program transforms the abstract states.

The goal of the analysis is to compute a solution element x such that

     F(x) = x

A **fixed point** of a function F is an element x such that F(x) = x.


Example: (liveness analysis)

The lattice for abstract states:

* An element is a set of variables (the ones that may be live).
* The partial ordering is the set containment, i.e. x ⊑ y iff x ⊆ y.
* The bottom element is the empty set.
* The join operator is set union.
  
The lattice for the whole CFG: 

* Each element is a mapping M from labels to sets of variables. 
* The partial ordering is the pointwise ordering: M ⊑ M' iff for any label
  l in the program, M(l) ⊑ M'(l).
* The bottom element is the mapping that sends every label to the empty set.
* The join operator: (M ⊔ M')(l) = M(l) ⊔ M'(l).
  



### Kleene Fixed-Point Theorem

A function F is **monotone** iff x ⊑ y implies F(x) ⊑ F(y).


**Theorem** (Kleene Fixed-Point Theorem) If a function F is monotone,
then the least fixed point of F is the least upper bound of the
ascending Kleene chain:

    ⊥ ⊑ F(⊥) ⊑ F(F(⊥)) ⊑ ... ⊑ F^k(⊥) ⊑ ...


When a lattice contains only finitely-long ascending chains, then
every Kleene chain tops out at some fixed point after some number of
iterations.
	
    ⊥ ⊑ F(⊥) ⊑ F(F(⊥)) ⊑ ... ⊑ F^k(⊥) = F^(k+1)(⊥) 
	

### Liveness Analysis

Let function F be one iteration of liveness analysis applied to all
the blocks in the program.

The function F is monotone: adding variables to the live-after set of
a block can only increase the size of its live-before set.

There are a finite number of variables in the program, so the
ascending chains are all finite.

So iterating the liveness analysis will eventually produce the least
fixed point of F (i.e. a correct solution).




### Worklist Algorithm

	def analyze_dataflow(G, transfer, bottom, join):
		trans_G = transpose(G)
		mapping = {}
		for v in G.vertices():
			mapping[v] = bottom
		worklist = deque()
		for v in G.vertices():
			worklist.append(v)
		while worklist:
			node = worklist.pop()
			input = reduce(join, [mapping[v] for v in trans_G.adjacent(node)], bottom)
			output = transfer(node, input)
			if output != mapping[node]:
				mapping[node] = output
				for v in G.adjacent(node):
					worklist.append(v)

