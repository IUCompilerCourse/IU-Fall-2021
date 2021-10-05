### Kleene Fixed-Point Theorem

A function F is **monotone** iff x ⊑ y implies F(x) ⊑ F(y).


**Theorem** (Kleene Fixed-Point Theorem) 
If a function F is monotone, then the least fixed point of F is the
least upper bound of the ascending Kleene chain:

    ⊥ ⊑ F(⊥) ⊑ F(F(⊥)) ⊑ ... ⊑ F^k(⊥) ⊑ ...

We don't need a theorem quite that general, but we'll use the idea of
ascending Kleene chains.


**Theorem** (Yet Another Fixed-Point Theorem)
Suppose L is a lattice where every ascending chain is finitely long.
Let F be monotone function. 
There exists some k such that F^k(⊥) is the least fixed point of F.

Proof.

First, we construct the ascending Kleene chain by showing that 
for any i,

    F^i(⊥) ⊑ F^(i+1)(⊥)
	
Base case: 

    ⊥ ⊑ F(⊥) 

by the definition of ⊥.

Inductive case: the induction hypothesis states that

    F^k(⊥) ⊑ F^(k+1)(⊥)

Then because F is monotone, we have

    F(F^k(⊥))  ⊑ F(F^(k+1)(⊥))
    =            =
    F^(k+1)(⊥) ⊑ F^(k+2)(⊥)
	
Thus we have the ascending chain:

    ⊥ ⊑ F(⊥) ⊑ F(F(⊥)) ⊑ ... ⊑ F^i(⊥) ⊑ ...
	
But the chain must be finitely long, so it tops out at some k.
	
    ⊥ ⊑ F(⊥) ⊑ F(F(⊥)) ⊑ ... ⊑ F^k(⊥) = F^(k+1)(⊥)
	
So F^k(⊥) is a fixed point.

It remains to show that F^k(⊥) is the least of all fixed points.
Suppose x is another fixed point of F, so F(x) = x.
We prove by induction that for all i, F^i(⊥) ⊑ x.
Base case: ⊥ ⊑ x by the definition of ⊥.
Inductive case: the induction hypothesis gives us

    F^i(⊥) ⊑ x
	
then by monotonicity	

    F^(i+1)(⊥) ⊑ F(x)
	
But x is a fixed point of F, so F(x) = x.

    F^(i+1)(⊥) ⊑ x
	
Therefore, in particular, F^k(⊥) ⊑ x, so it is the least fixed point.

QED


### Liveness Analysis

Let function F be one iteration of liveness analysis applied to all
the blocks in the program.

The function F is monotone because adding variables to the live-after
set of a block can only increase the size of its live-before set.

There are a finite number of variables in the program, so the
ascending chains are all finite.

So iterating the liveness analysis will eventually produce the least
fixed point of F (i.e. a correct solution).


### Worklist Algorithm

Inputs
* G: control-flow graph
* transfer: applies analysis to one block
* bottom: bottom element of the lattice (e.g. empty set)
* join: join operator (e.g. set union)

Outputs
* The transfer function can store the results in a location
  of your choice.

Algorithm:

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

