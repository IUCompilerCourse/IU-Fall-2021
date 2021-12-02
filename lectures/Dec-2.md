# Lecture: Dynamic Typing

We'll implement a dynamically-typed language Ldyn, a subset of
Racket/Python.

Example Ldyn program

    (not (if (eq? (read) 1) #f 0))

    not (False if input_int() == 1 else 0)

We'll implement the compiler for Ldyn in two stages.

1. Extend our typed language with a new type `Any` that is equiped
   with the operations `inject` and `project` that convert a value
   of any other type to `Any` and back again. This language is Lany.

        (let ([x (inject (Int 42) Integer)])
          (project x Integer))                 ;; result is 42

        (let ([x (inject (Bool #t) Boolean)])
          (project x Integer))                 ;; error!

2. Create a new pass (at the beginning) that translates from Ldyn to Lany
   that uses `Any` as the type for just about everying and that
   inserts `inject` and `project` in lots of places.



## The Lany Language: Any

    type ::= ... | Any
    ftype ::= Integer | Boolean | (Vector Any ...) | (Vectorof Any)
          | (Any ... -> Any)
    exp ::= ... | (inject exp ftype) | (project exp ftype) |
          | (boolean? exp) | (integer? exp) | (vector? exp)
          | (procedure? exp) | (void? exp)

The `Vectorof` type is for homogeneous vectors of arbitrary length.
That is, their elements are all of the same type and the length is
determined at runtime.

* type checking Lany

* interpreting Lany

Another example:

    (let ([v (inject (vector (inject 42 Integer)) 
                     (Vector Any))])
       (let ([w (project v (Vector Any))])
          (let ([x (vector-ref w 0)])
             (project x Integer))))



## Compiling Lany

The runtime representation of a value of type `Any` is a 64 bit value
whose 3 least-significant bits (right-most) encode the runtime type,
which we call a *tag*.
  
    tagof(Integer)        = 001
    tagof(Boolean)        = 100
    tagof((Vector ...))   = 010
    tagof((Vectorof ...)) = 010
    tagof((... -> ...))   = 011
    tagof(Void)           = 101

If the value is an integer or Boolean, then the other 61 bits store
that value. (Shifted by 3.)

If the value is a vector or function, then the 64 bits is an
address. All our values are 8-byte aligned, so we don't need the
bottom 3 bits. To obtain the address from an `Any` value, just write
000 to the rightmost 3 bits.

## Shrink

* Compiling `Project` to `tag-of-any`, `value-of-any`, and `exit`.

  If `ty` is `Boolean` or `Integer`:
    
        (project e ty)
        ===>
        (let ([tmp e])
          (if (eq? (tag-of-any tmp) tag)
              (value-of-any tmp ty)
              (exit))))
              
        where tag is tagof(ty)

  If `ty` is a function or vector (e.g. `(Vector Integer Boolean)`), 
  you also need to check the vector
  length or procedure arity. Those two operations be added as two new
  primitives. Use the primitives: `vector-length`, `procedure-arity`.


* Compile `Inject` to `make-any`

        (inject e ty)
        ===>
        (make-any e tag)

        where tag is the result of tagof(ty)

* Abstract syntax for the new forms:
  
        exp ::= ... | (Prim 'tag-of-any (list exp))
             | (Prim 'make-any (list exp (Int tag)))
             | (ValueOf exp type)
             | (Exit)


## Check Bounds (missing from book)

Adapt `type-check-Lany` by changing the cases for `vector-ref` and
`vector-set!` when the vector argument has type `Vectorof T`.

    (vector-ref e1 e2)
    ===>
    (let ([v e1'])
      (let ([i e2'])
        (if (< i (vector-length v))
            (vector-ref v i)
            (exit))))

    (vector-set! e1 e2 e3)
    ===>
    (let ([v e1'])
      (let ([i e2'])
        (if (< i (vector-length v))
            (vector-set! v i e3')
            (exit))))

## Reveal Functions

Old way:

    (Var f)
    ===>
    (FunRef f)

To support `procedure-arity`, we'll need to record the arity of a
function in `FunRefArity`.

    (Var f)
    ===>
    (FunRefArity f n)

Which means when processing the `ProgramDefs` form, we need to build
an alist mapping function names to their arity.

## Closure Convertion

To support `procedure-arity`, we use a special purpose
`Closure` form instead of the primitive `vector`,
both in the case for `Lambda` and `FunRefArity`.

## Expose Allocation

Add a case for `Closure` that is similar to the one for `vector`
except that it uses `AllocateClosure` instead of `Allocate`, so that
it can pass along the arity.

## Remove Complex Operands

Add case for `AllocateClosure`.

## Explicate Control

Add case for `AllocateClosure`.

## Instruction Selection

* `(Prim 'make-any (list e (Int tag)))`

  For tag of an Integer or Boolean: (Void too?)

        (Assign lhs (Prim 'make-any (list e (Int tag)))
        ===>
        movq e', lhs'
        salq $3, lhs'
        orq tag, lhs'

  where `3` is the length of the tag.

  For other types (vectors and functions):

        (Assign lhs (Prim 'make-any (list e (Int tag))))
        ===>
        movq e', lhs'
        orq tag, lhs'

* `(Prim 'tag-of-any (list e))`

        (Assign lhs (Prim 'tag-of-any (list e)))
        ===>
        movq e', lhs
        andq $7, lhs

  where `7` is the binary number `111`.

* `(ValueOf e ty)`

  If `ty` is an Integer, Boolean, Void:

        (Assign lhs (ValueOf e ty))
        ==>
        movq e', lhs'
        sarq $3, lhs

  where `3` is the length of the tag.
  
  If `ty` is a vector or procedure (a pointer):

        (Assign lhs (ValueOf e ty))
        ==>
        movq $-8, lhs
        andq e', lhs

  where -8 is `(bitwise-not (string->number "#b111"))`


## Compiling Lany, Instruction Selection, continued

* `(Exit)`

        (Assign lhs (Exit))
        ===>
        movq $-1, %rdi
        callq exit

* `(Assign lhs (AllocateClosure len ty arity))`

  Treat this just like `Allocate` except that you'll put
  the `arity` into the tag at the front of the vector.
  Use bits 57 and higher for the arity.

        [(Assign lhs (AllocateClosure len `(Vector ,ts ...) arity))
         (define lhs^ (select-instr-arg lhs))
         ;; Add one quad word for the meta info tag
         (define size (* (add1 len) 8))
         ;;highest 7 bits are unused
         ;;lowest 1 bit is 1 saying this is not a forwarding pointer
         (define is-not-forward-tag 1)
         ;;next 6 lowest bits are the length
         (define length-tag (arithmetic-shift len 1))
         ;;bits [6,56] are a bitmask indicating if [0,50] are pointers
         (define ptr-tag
           (for/fold ([tag 0]) ([t (in-list ts)] [i (in-naturals 7)])
             (bitwise-ior tag (arithmetic-shift (b2i (root-type? t)) i))))
         (define arity-tag ...)
         ;; Combine the tags into a single quad word
         (define tag (bitwise-ior arity-tag ptr-tag length-tag is-not-forward-tag))
         (list (Instr 'movq (list (Global 'free_ptr) (Reg tmp-reg)))
               (Instr 'addq (list (Imm size) (Global 'free_ptr)))
               (Instr 'movq (list (Imm tag) (Deref tmp-reg 0)))
               (Instr 'movq (list (Reg tmp-reg) lhs^))
               )
         ]

* `(Assign lhs (Prim 'procedure-arity (list e)))`

  Extract the arity from the tag of the vector.
  
        (Assign lhs (Prim 'procedure-arity (list e)))
        ===>
        movq e', %r11
        movq 0(%r11), %r11
        sarq $57, %r11
        movq %r11, lhs'

* `(Assign lhs (Prim 'vector-length (list e)))`

  Extract the length from the tag of the vector.

        (Assign lhs (Prim 'vector-length (list e)))
        ===>
        movq e', %r11
        movq 0(%r11), %r11
        andq $126, %r11           // 1111110
        sarq $1, %r11
        movq %r11, lhs'


## `Vectorof`, `vector-ref`, and `vector-set!`

The type checker for Lany treats vector operations differently
if the vector is of type `(Vectorof T)`. 
The index can be an arbitrary expression, e.g.
suppose `vec` has type `(Vectorof T)`. Then
the index could be `(read)`

	;; vec1 : (Vector Any Any)
	(let ([vec1 (vector (inject 1 Integer) (inject 2 Integer))])
	  (let ([vec2 (inject vec1 (Vector Any Any))]) ;; vec2 : Any
		(let ([vec3 (project vec2 (Vectorof Any))]) ;; vec3 : (Vectorof Any)
		  (vector-ref vec3 (read)))))

and the type of `(vector-ref vec (read))` is `T`.

Recall instruction selection for `vector-ref`:

    (Assign lhs (Prim 'vector-ref (list evec (Int n))))
    ===>
    movq evec', %r11
    movq offset(%r11), lhs'

    where offset is 8(n+1)

If the index is not of the form `(Int i)`, but an arbitrary
expression, then instead of computing the offset `8(n+1)` at compile
time, you can generate the following instructions. Note the use of the
new instruction `imulq`.

    (Assign lhs (Prim 'vector-ref (list evec en)))
    ===>
    movq en', %r11
    addq $1, %r11
    imulq $8, %r11
    addq evec', %r11
    movq 0(%r11) lhs'

The same idea applies to `vector-set!`.


# The Ldyn Language: Mini Racket (Dynamically Typed)

    exp ::= int | (read) | ... | (lambda (var ...) exp)
          | (vector-ref exp exp) | (vector-set! exp exp exp)
    def ::= (define (var var ...) exp)
    Ldyn ::= def... exp

# Compiling Ldyn to Lany by cast insertion

The main invariant is that every subexpression that we generate should
have type `Any`, which we accomplish by using `inject`.

To perform an operation on a value of type `Any`, we `project` it to
the appropriate type for the operation.

Example:
Ldyn:

    (+ #t 42)

Lany:

    (inject
       (+ (project (inject #t Boolean) Integer)
          (project (inject 42 Integer) Integer))
       Integer)
    ===>
    x86 code

    
Booleans:

    #t
    ===>
    (inject #t Boolean)

Integer:

    42
    ===>
    (inject 42 Integer)

Arithmetic:

    (+ e_1 e_2)
    ==>
    (inject
       (+ (project e'_1 Integer)
          (project e'_2 Integer))
       Integer)

Variables:

    x
    ===>
    x

Lambda:

    (lambda (x_1 ... x_n) e)
    ===>
    (inject (lambda: ([x_1 : Any] ... [x_n : Any]) : Any e')
        (Any ... Any -> Any))

example:

    (lambda (x y) (+ x y))
    ===>
    (inject (lambda: ([x : Any] [y : Any]) : Any
      (inject (+ (project x Integer) (project y Integer)) Integer))
      (Any Any -> Any))

Application:

    (e_0 e_1 ... e_n)
    ===>
    ((project e'_0 (Any ... Any -> Any)) e'_1 ... e'_n)

Vector Reference:

    (vector-ref e_1 e_2)
    ===>
    (vector-ref (project e'_1 (Vectorof Any)) 
                (project e'_2 Integer))


Vector:

    (vector e1 ... en)
    ===>
    (inject 
       (vector e1' ... en')
       (Vector Any .... Any))

Ldyn:
    (vector 1 #t)      heterogeneous
    
    (inject (vector (inject 1 Integer) (inject #t Boolean)) 
       (Vector Any Any)) : Any

Lany: (Vector Int Bool)  heterogeneous
      (Vectorof Int)     homogeneous

actually see:

    (Vector Any Any)
    (Vectorof Any)


