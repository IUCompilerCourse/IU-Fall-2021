from ast import *

def height(e):
  match e:
    case Constant(value):
      return 1
    case Name(id):
      return 1
    case BinOp(left, op, right):
      return 1 + max(height(left), height(right))
    case UnaryOp(op, operand):
      return 1 + height(operand)
    case Call(func, args):
      return 1 + max([height(a) for a in [func] + args])

E1 = Constant(42)
E2 = Call(Name('input_int'), [])
E3 = UnaryOp(USub(), E1)
E4 = BinOp(E3, Add(), Constant(5))
E5 = BinOp(E2, Add(), UnaryOp(USub(), E2))

print(height(E1))
print(height(E2))
print(height(E3))
print(height(E4))
print(height(E5))
