# Closure Conversion Pass (after reveal-functions)

1. Translate each lambda into a "flat closure"

    Let `fv1, fv2, ...` be the free variables of the lambda.

    Racket

		(lambda: (ps ...) : rt body)
		==>
		(vector lambda_name fv1 fv2 ...)

    Python

        lambda ps... : body
		==>
		(lambda_name, fv1, fv2, ...)

2. Generate a top-level function for each lambda

    Let `FT1, FT2, ...` be the types of the free variables
    and the `has_type` of the lambda is `FunctionType([PT1, ...], RT)`.

    Racket
	
		(define (lambda_name [clos : _] ps ...) -> rt
		  (let ([fv1 (vector-ref clos 1)])
			(let ([fv2 (vector-ref clos 2)])
			  ...
			  body')))

    Python

        def lambda_name(clos : TupleType([_,FT1,FT2,...]), p1:PT1, ...) -> RT: 
            fv1 = clos[1]
			fv2 = clos[2]
			...
			return body'

3. Translate every function application into an application of a closure:

    Racket

		(e es ...)
		==>
		(let ([tmp e'])
		  ((vector-ref tmp 0) tmp es' ...))

    Python

        e0(e1, ..., en)
		==>
		let tmp = e0' in tmp[0](tmp, e1', ..., en')
		



# Basic Example of Closure Conversion

## source program

    def f(x:int)-> Callable[[int],int] :
      y = 4
      return (lambda z: x + y + z)
    g = f(5)
    h = f(3)
    print(g(11) + h(15))


## box free variables

    def f(x.0:int)-> Callable[[int], int] :
      x = (x.0,)
      y = (777,)
      y[0] = 4
      return (lambda z: x[0] + y[0] + z)
	  
    def main()-> int :
      g = {f}(5)
      h = {f}(3)
      print(g(11) + h(15))
      return 0

## closure conversion

    def lambda.1(fvs.2:(bot,(int),(int)),z:int)-> int :
      y = fvs.2[1]
      x = fvs.2[2]
      return x[0] + y[0] + z
	  
    def f(fvs.3:bot,x.0:int)-> (Callable[[(),int], int]) :
      x = (x.0,)
      y = (777,)
      y[0] = 4
      return closure({lambda.1},y,x)
	  
    def main()-> int :
      g = (let clos.4 = closure({f}) in clos.4[0](clos.4, 5))
      h = (let clos.5 = closure({f}) in clos.5[0](clos.5, 3))
      print((let clos.6 = g in clos.6[0](clos.6, 11)) + (let clos.7 = h in clos.7[0](clos.7, 15)))
      return 0


# Example that Motivates Boxing Free Variables

## source program

    x = 0
    y = 0
    z = 20
    f : Callable[[int], int] = (lambda a: a + x + z)
    x = 10
    y = 12
    print(f(y))

## box free variables

    def main()-> int:
      x = (777,)
      z = (777,)
      x[0] = 0
      y = 0
      z[0] = 20
      f : Callable[[int], int] = (lambda a: a + x[0] + z[0])
      x[0] = 10
      y = 12
      print(f(y))
      return 0

## closure conversion

    def lambda.0(fvs.1:(bot,(int),(int)),a:int)-> int :
      z = fvs.1[1]
      x = fvs.1[2]
      return a + x[0] + z[0]

    def main()-> int :
      x = (777,)
      z = (777,)
      x[0] = 0
      y = 0
      z[0] = 20
      f = closure({lambda.0},z,x)
      x[0] = 10
      y = 12
      print((let clos.2 = f in clos.2[0](clos.2, y)))
      return 0


