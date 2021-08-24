# August 24

Welcome to Compilers! (P423, P523, E313, E513)

## Instructor: Jeremy

## What's a compiler?

## Table of Contents of Essentials of Compilation

## Assignments, Quizzes, Exams, Grading, Academic Integrity

## Technology

* Canvas FA21: COMPILERS: 18429
  Link to real course web page
  Grades

* Web page: https://iucompilercourse.github.io/IU-Fall-2021/

* Communication: Slack http://iu-compiler-course.slack.com/

* Autograder: https://autograder.sice.indiana.edu/web/course/28

## Concrete Syntax, Abstract Syntax Trees (AST)

* Programs in concrete syntax (Racket/Python)

		42                           42

		(read)                       input_int()

		(- 10)                       -10

		(+ (- 10) 5)                 -10 + 5

		(+ (read) (- (read)))        input_int() + -input_int()

* Racket structures for AST

		(struct Int (value))
		(struct Prim (op arg*))

* Python classes for AST

    [Python ast module](https://docs.python.org/3.10/library/ast.html)
	
	[ast module type declarations](https://github.com/python/typeshed/blob/master/stdlib/_ast.pyi)

		class Constant(expr):
			value: Any

		class BinOp(expr):
			left: expr
			op: operator
			right: expr

		class UnaryOp(expr):
			op: unaryop
			operand: expr

* Grammars
	* Concrete syntax
	  
	  Racket style:

			exp ::= int | (read) | (- exp) | (+ exp exp)
			L_Int ::= exp

      Python style:

			exp ::= int | input_int() | - exp | exp + exp
			stmt ::= print(exp) | exp
			L_Int ::= stmt*

	* Abstract syntax
	
      Racket:

			exp ::= (Int int) | (Prim 'read '()) 
				| (Prim '- (list exp))
				| (Prim '+ (list exp exp))
			L_Int ::= (Program '() exp)

      Python:

            exp ::= Constant(int) | Call(Name('input_int'), [])
			    | UnaryOp(USub(), exp)
				| BinOp(exp, Add(), exp)
			stmt ::= Expr(Call(Name('print'), [exp])) | Expr(exp)
            L_Int ::= Module(stmt*)

## Pattern Matching and Structural Recursion

Examples:

* [`L_Int_height.rkt`](./L_Int_height.rkt)

* [`L_Int_height.py`](./L_Int_height.py)
