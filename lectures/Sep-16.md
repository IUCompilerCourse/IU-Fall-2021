# Concrete Syntax of L_If

Racket

    bool ::= #t | #f
    cmp ::=  eq? | < | <= | > | >= 
    exp ::= int | (read) | (- exp) | (+ exp exp) | (- exp exp)
        | var | (let ([var exp]) exp)
        | bool | (and exp exp) | (or exp exp) | (not exp) 
        | (cmp exp exp) | (if exp exp exp) 
    L_If ::= exp

Python

    binop ::= + | - | and | or | == | != | < | <= | > | >=
	uniop ::= - | not
	exp ::= int | input_int() | uniop exp | exp binop exp | var
	    | True | False | exp if exp else exp
    stmt ::= print(exp) | exp | var = exp | if exp: stmt+ else: stmt+
	L_If ::= stmt*

New things:
* Boolean literals: true and false.
* Logical operators on Booleans: `and`, `or`, `not`.
* Comparison operators: equal, less than, etc.
* The `if` conditional expression. Branching!
* Subtraction on integers.


# Semantics of L_If

	class InterpPif(InterpPvar):

	  def interp_cmp(self, cmp):
		match cmp:
		  case Lt():
			return lambda x, y: x < y
		  case LtE():
			return lambda x, y: x <= y
		  case Gt():
			return lambda x, y: x > y
		  case GtE():
			return lambda x, y: x >= y
		  case Eq():
			return lambda x, y: x == y
		  case NotEq():
			return lambda x, y: x != y

	  def interp_exp(self, e, env):
		match e:
		  case IfExp(test, body, orelse):
			match self.interp_exp(test, env):
			  case True:
				return self.interp_exp(body, env)
			  case False:
				return self.interp_exp(orelse, env)
		  case BinOp(left, Sub(), right):
			l = self.interp_exp(left, env)
			r = self.interp_exp(right, env)
			return l - r
		  case UnaryOp(Not(), v):
			return not self.interp_exp(v, env)
		  case BoolOp(And(), values):
			left = values[0]; right = values[1]
			match self.interp_exp(left, env):
			  case True:
				return self.interp_exp(right, env)
			  case False:
				return False
		  case BoolOp(Or(), values):
			left = values[0]; right = values[1]
			match self.interp_exp(left, env):
			  case True:
				return True
			  case False:
				return self.interp_exp(right, env)
		  case Compare(left, [cmp], [right]):
			l = self.interp_exp(left, env)
			r = self.interp_exp(right, env)
			return self.interp_cmp(cmp)(l, r)
		  case Let(Name(x), rhs, body):
			v = self.interp_exp(rhs, env)
			new_env = dict(env)
			new_env[x] = v
			return self.interp_exp(body, new_env)
		  case _:
			return super().interp_exp(e, env)

	  def interp_stmts(self, ss, env):
		if len(ss) == 0:
		  return
		match ss[0]:
		  case If(test, body, orelse):
			match self.interp_exp(test, env):
			  case True:
				return self.interp_stmts(body + ss[1:], env)
			  case False:
				return self.interp_stmts(orelse + ss[1:], env)
		  case _:
			return super().interp_stmts(ss, env)
		
Things to note:
* Our treatment of Booleans and operations on them is strict: we don't
  allow other kinds of values (such as integers) to be treated as if
  they are Booleans.
* `and` is short-circuiting.
* The handling of comparison operators has been factored out into an
  auxilliary function named `interp_cmp`.


# Type errors and static type checking

In Racket:

    > (not 1)
    #f

    > (car 1)
    car: contract violation
      expected: pair?
      given: 1

In Typed Racket:

    > (not 1)
    #f

    > (car 1)
    Type Checker: Polymorphic function `car' could not be applied to arguments:
    Domains: (Listof a)
             (Pairof a b)
    Arguments: One
    in: (car 1)

In Python:

    >>> not 1
	False

    >>> 1[0]
    TypeError: 'int' object is not subscriptable	

In PyCharm:

    >>> not 1
	False

    >>> 1[0]
	Class 'int' does not define '__getitem__', so the '[]' operator cannot
	be used on its instances 

A type checker (aka. type system) enforces at compile-time that only
the appropriate operations are applied to values of a given type.

To accomplish this, a type checker must predict what kind of value
will be produced by an expression at runtime.

Type checker:

	class TypeCheckPvar:

	  def type_check_exp(self, e, env):
		match e:
		  case BinOp(left, Add(), right):
			l = self.type_check_exp(left, env)
			check_type_equal(l, int, left)
			r = self.type_check_exp(right, env)
			check_type_equal(r, int, right)
			return int
		  case UnaryOp(USub(), v):
			t = self.type_check_exp(v, env)
			check_type_equal(t, int, v)
			return int
		  case Name(id):
			return env[id]
		  case Constant(value) if isinstance(value, int):
			return int
		  case Call(Name('input_int'), []):
			return int
		  case _:
			raise Exception('error in TypeCheckPvar.type_check_exp, unhandled ' + repr(e))

	  def type_check_stmts(self, ss, env):
		if len(ss) == 0:
		  return
		match ss[0]:
		  case Assign([lhs], value):
			t = self.type_check_exp(value, env)
			if lhs.id in env:
			  check_type_equal(env[lhs.id], t, value)
			else:
			  env[lhs.id] = t
			return self.type_check_stmts(ss[1:], env)
		  case Expr(Call(Name('print'), [arg])):
			t = self.type_check_exp(arg, env)
			check_type_equal(t, int, arg)
			return self.type_check_stmts(ss[1:], env)
		  case Expr(value):
			self.type_check_exp(value, env)
			return self.type_check_stmts(ss[1:], env)
		  case _:
			raise Exception('error in TypeCheckPvar.type_check_stmt, unhandled ' + repr(s))

	  def type_check_P(self, p):
		match p:
		  case Module(body):
			self.type_check_stmts(body, {})


	class TypeCheckPif(TypeCheckPvar):

	  def type_check_exp(self, e, env):
		match e:
		  case Constant(value) if isinstance(value, bool):
			return bool
		  case IfExp(test, body, orelse):
			test_t = self.type_check_exp(test, env)
			check_type_equal(bool, test_t, test)
			body_t = self.type_check_exp(body, env)
			orelse_t = self.type_check_exp(orelse, env)
			check_type_equal(body_t, orelse_t, e)
			return body_t
		  case BinOp(left, Sub(), right):
			l = self.type_check_exp(left, env)
			check_type_equal(l, int, left)
			r = self.type_check_exp(right, env)
			check_type_equal(r, int, right)
			return int
		  case UnaryOp(Not(), v):
			t = self.type_check_exp(v, env)
			check_type_equal(t, bool, v)
			return bool 
		  case BoolOp(op, values):
			left = values[0]; right = values[1]
			l = self.type_check_exp(left, env)
			check_type_equal(l, bool, left)
			r = self.type_check_exp(right, env)
			check_type_equal(r, bool, right)
			return bool
		  case Compare(left, [cmp], [right]) if isinstance(cmp, Eq) or isinstance(cmp, NotEq):
			l = self.type_check_exp(left, env)
			r = self.type_check_exp(right, env)
			check_type_equal(l, r, e)
			return bool
		  case Compare(left, [cmp], [right]):
			l = self.type_check_exp(left, env)
			check_type_equal(l, int, left)
			r = self.type_check_exp(right, env)
			check_type_equal(r, int, right)
			return bool
		  case Let(Name(x), rhs, body):
			t = self.type_check_exp(rhs, env)
			new_env = dict(env); new_env[x] = t
			return self.type_check_exp(body, new_env)
		  case _:
			return super().type_check_exp(e, env)

	  def type_check_stmts(self, ss, env):
		if len(ss) == 0:
		  return
		match ss[0]:
		  case If(test, body, orelse):
			test_t = self.type_check_exp(test, env)
			check_type_equal(bool, test_t, test)
			body_t = self.type_check_stmts(body, env)
			orelse_t = self.type_check_stmts(orelse, env)
			check_type_equal(body_t, orelse_t, ss[0])
			return self.type_check_stmts(ss[1:], env)
		  case _:
			return super().type_check_stmts(ss, env)


How should the type checker handle the `if` expression?


# Shrinking L_If

Several of the language forms in L_If are redundant and can be easily
expressed using other language forms. They are present in L_If to make
programming more convenient, but they do not fundamentally increase
the expressiveness of the language. 

To reduce the number of language forms that later compiler passes have
to deal with, we shrink L_If by translating away some of the forms.
For example, subtraction is expressible as addition and negation.

    (and e1 e2)   =>   (if e1 e2 #f)
	(or e1 e2)    =>   (if e1 #t e2)
    
It is possible to shrink many more of the language forms, but
sometimes it can hurt the efficiency of the generated code.
For example, we could express subtraction in terms of addition
and negation:

    (- e1 e2)    => (+ e1 (- e2))
	
but that would result in two x86 instructions instead of one.



