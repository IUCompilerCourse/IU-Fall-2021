# Basic Example of Closure Conversion

## source program

    def f(x:int)-> Callable[(<ast.List object at 0x1080c61d0>,int,)] :
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


