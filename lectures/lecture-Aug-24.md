# August 25

Welcome to Compilers! (P423, P523, E313, E513)

## Instructor: Jeremy

## What's a compiler?

## Table of Contents of Essentials of Compilation

## Assignments, Quizzes, Exams, Grading, Academic Integrity

## Technology

* Canvas FA21: COMPILERS: 18429
  Link to real course web page
  Grades

* Web page:
  https://iucompilercourse.github.io/IU-Fall-2021/

* Communication: Slack http://iu-compiler-course.slack.com/

* autograder: https://autograder.sice.indiana.edu/web/course/28

## Concrete Syntax, Abstract Syntax Trees (AST)

* Programs in concrete syntax (Racket/Python)

		42                           42

		(read)                       input_int()

		(- 10)                       -10

		(+ (- 10) 5)                 -10 + 5

		(+ (read) (- (read)))        input_int + -input_int()

* Racket structures for AST

		(struct Int (value))
		(struct Prim (op arg*))

* Python classes for AST

    [https://docs.python.org/3.10/library/ast.html](Python ast module)

* Grammars
	* Concrete syntax

			exp ::= int | (read) | (- exp) | (+ exp exp) | (- exp exp)
			L0 ::= exp

	* Abstract syntax

			exp ::= (Int int) | (Prim 'read '()) 
				| (Prim '- (list exp))
				| (Prim '+ (list exp exp))
			L0 ::= (Program '() exp)


## Pattern Matching and Structural Recursion

Examples:

* [`L0-height.rkt`](./L0-height.rkt)

* [`L0-height.py`](./L0-height.py)
