# Language P_var
#
# Concrete Syntax
#
# exp ::= var | int | `input_int` `(` `)` | `-` exp | exp `+` exp
# stmt ::= var `=` exp | `print` `(` exp `)` | exp
# program ::= stmt+
#
#
# Abstract Syntax
#
# exp ::= Name(var) | Constant(int) | Call(Name('input_int'), [])
#       | UnaryOp(USub(), exp) | BinOp(exp, Add(), exp)
# stmt ::= Assign([var],exp) | Expr(Call(Name('print'), [exp])) | Expr(exp)
# program ::= Module([stmt])
import ast
from ast import *
from utils import *
from x86_ast import *
import os
from typing import List, Tuple, Set, Dict

Binding = Tuple[Name, expr]
Temporaries = List[Binding]


class Compiler:

    ############################################################################
    # Remove Complex Operands
    ############################################################################

    @staticmethod
    def gen_assigns(bs: Temporaries) -> List[stmt]:
        return [Assign([lhs], rhs) for (lhs, rhs) in bs]

    def rco_exp(self, e: expr, need_atomic: bool) -> Tuple[expr, Temporaries]:
        match e:
            case BinOp(left, op, right):
                (l, bs1) = self.rco_exp(left, True)
                (r, bs2) = self.rco_exp(right, True)
                if need_atomic:
                    tmp = Name(generate_name('tmp'))
                    b = BinOp(l, op, r)
                    return tmp, bs1 + bs2 + [(tmp, b)]
                else:
                    return BinOp(l, op, r), bs1 + bs2
            case UnaryOp(op, operand):
                (rand, bs) = self.rco_exp(operand, True)
                if need_atomic:
                    tmp = Name(generate_name('tmp'))
                    return tmp, bs + [(tmp, UnaryOp(op, rand))]
                else:
                    return UnaryOp(op, rand), bs
            case Name(id):
                return e, []
            case Constant(value):
                return e, []
            case Call(func, args):
                (new_func, bs1) = self.rco_exp(func, True)
                (new_args, bss2) = \
                    unzip([self.rco_exp(arg, True) for arg in args])
                if need_atomic:
                    tmp = Name(generate_name('tmp'))
                    return (tmp, bs1 + sum(bss2, [])
                            + [(tmp, Call(new_func, new_args, []))])
                else:
                    return Call(new_func, new_args, []), bs1 + sum(bss2, [])
            case _:
                raise Exception('error in rco_exp, unhandled: ' + repr(e))

    def rco_stmt(self, s: stmt) -> List[stmt]:
        match s:
            case Assign(targets, value):
                new_value, bs = self.rco_exp(value, False)
                return self.gen_assigns(bs) + [Assign(targets, new_value)]
            case Expr(value):
                new_value, bs = self.rco_exp(value, False)
                return self.gen_assigns(bs) + [Expr(new_value)]

    def remove_complex_operands(self, p: Module) -> Module:
        match p:
            case Module(body):
                sss = [self.rco_stmt(s) for s in body]
                return Module(sum(sss, []))

    ############################################################################
    # Select Instructions
    ############################################################################

    def select_arg(self, e: expr) -> arg:
        match e:
            case Name(id):
                return Variable(id)
            case Constant(value):
                return Immediate(value)
            case _:
                raise Exception('select_arg unhandled: ' + repr(e))

    def select_op(self, op: operator) -> str:
        match op:
            case Add():
                return 'addq'
            case USub():
                return 'negq'

    def select_stmt(self, s: stmt) -> List[instr]:
        match s:
            case Expr(Call(Name('input_int'), [])):
                return [Callq(label_name('read_int'), 0)]
            case Expr(Call(Name('print'), [operand])):
                return [Instr('movq', [self.select_arg(operand), Reg('rdi')]),
                        Callq(label_name('print_int'), 1)]
            case Expr(value):
                return []
            case Assign([lhs], Name(id)):
                new_lhs = self.select_arg(lhs)
                if Name(id) != lhs:
                    return [Instr('movq', [Variable(id), new_lhs])]
                else:
                    return []
            case Assign([lhs], Constant(value)):
                new_lhs = self.select_arg(lhs)
                rhs = self.select_arg(Constant(value))
                return [Instr('movq', [rhs, new_lhs])]
            case Assign([lhs], UnaryOp(op, operand)):
                new_lhs = self.select_arg(lhs)
                rand = self.select_arg(operand)
                return [Instr('movq', [rand, new_lhs]),
                        Instr(self.select_op(op), [new_lhs])]
            case Assign([lhs], BinOp(left, op, right)):
                new_lhs = self.select_arg(lhs)
                l = self.select_arg(left)
                r = self.select_arg(right)
                return [Instr('movq', [l, new_lhs]),
                        Instr(self.select_op(op), [r, new_lhs])]
            case Assign([lhs], Call(Name('input_int'), [])):
                new_lhs = self.select_arg(lhs)
                return [Callq(label_name('read_int'), 0),
                        Instr('movq', [Reg('rax'), new_lhs])]
            case Assign([lhs], Call(Name('print'), [operand])):
                return [Instr('movq', [self.select_arg(operand), Reg('rdi')]),
                        Callq(label_name('print_int'), 1)]
            case _:
                raise Exception('error in select_stmt, unknown: ' + repr(s))

    def select_instructions(self, p: Module) -> X86Program:
        match p:
            case Module(body):
                sss = [self.select_stmt(s) for s in body]
                return X86Program(sum(sss, []))

    ############################################################################
    # Assign Homes
    ############################################################################

    def collect_locals_instr(self, i: instr) -> Set[location]:
        match i:
            case Instr(inst, args):
                lss = [self.collect_locals_arg(a) for a in args]
                return set().union(*lss)
            case Callq(func, num_args):
                return set()

    def collect_locals_arg(self, a: arg) -> Set[location]:
        match a:
            case Reg(id):
                return set()
            case Variable(id):
                return {Variable(id)}
            case Immediate(value):
                return set()

    def collect_locals_instrs(self, ss: List[stmt]) -> Set[location]:
        return set().union(*[self.collect_locals_instr(s) for s in ss])

    @staticmethod
    def gen_stack_access(i: int) -> arg:
        return Deref('rbp', -(8 + 8 * i))

    def assign_homes_arg(self, a: arg, home: Dict[Variable, arg]) -> arg:
        match a:
            case Reg(id):
                return a
            case Variable(id):
                return home.get(a, a)
            case Immediate(value):
                return a

    def assign_homes_instr(self, i: instr,
                           home: Dict[location, arg]) -> instr:
        match i:
            case Instr(instr, args):
                new_args = [self.assign_homes_arg(a, home) for a in args]
                return Instr(instr, new_args)
            case Callq(func, num_args):
                return i

    def assign_homes_instrs(self, ss: List[instr],
                            home: Dict[location, arg]) -> List[instr]:
        return [self.assign_homes_instr(s, home) for s in ss]

    def assign_homes(self, p: X86Program) -> X86Program:
        match p:
            case X86Program(body):
                variables = self.collect_locals_instrs(body)
                home = {}
                for i, x in enumerate(variables):
                    home[x] = self.gen_stack_access(i)
                body = self.assign_homes_instrs(body, home)
                p = X86Program(body)
                p.stack_space = align(8 * len(variables), 16)
                return p

    ############################################################################
    # Patch Instructions
    ############################################################################

    @staticmethod
    def big_constant(c: arg) -> bool:
        return isinstance(c, Immediate) and c.value > 2 ** 16

    @staticmethod
    def in_memory(a: arg) -> bool:
        return isinstance(a, Deref)

    def patch_instr(self, i: instr) -> List[instr]:
        match i:
            case Instr(inst, [s, t]) if (self.in_memory(s)
                                          or self.big_constant(s)) \
                                         and self.in_memory(t):
                return [Instr('movq', [s, Reg('rax')]),
                        Instr(inst, [Reg('rax'), t])]
            case _:
                return [i]

    def patch_instrs(self, ss: List[instr]) -> List[instr]:
        return sum([self.patch_instr(i) for i in ss], [])

    def patch_instructions(self, p: X86Program) -> X86Program:
        match p:
            case X86Program(body):
                new_p = X86Program(self.patch_instrs(body))
                new_p.stack_space = p.stack_space
                return new_p

    ############################################################################
    # Generate Main Function
    ############################################################################

    def generate_main(self, p: X86Program) -> X86Program:
        match p:
            case X86Program(body):
                prelude = [Instr('pushq', [Reg('rbp')]),
                           Instr('movq', [Reg('rsp'), Reg('rbp')]),
                           Instr('subq', [Immediate(p.stack_space), Reg('rsp')])]
                concl = [Instr('addq', [Immediate(p.stack_space), Reg('rsp')]),
                         Instr('popq', [Reg('rbp')]),
                         Instr('retq', [])]
                return X86Program(prelude + body + concl)

    ############################################################################
    # Print x86
    ############################################################################

    def print_x86(self, p: X86Program) -> str:
        match p:
            case X86Program(body):
                return '\t.globl ' + label_name('main') + '\n' + \
                       label_name('main') + ':\n' + \
                       '\tpushq %rbp\n' + \
                       '\tmovq %rsp, %rbp\n' + \
                       '\tsubq $' + str(p.stack_space) + ', %rsp\n' + \
                       '\n'.join([self.print_instr(s) for s in body]) + '\n' + \
                       '\taddq $' + str(p.stack_space) + ', %rsp\n' + \
                       '\tpopq %rbp\n' + \
                       '\tretq\n'

    def print_instr(self, i: instr) -> str:
        match i:
            case Instr(inst, args):
                return '\t' + inst + ' ' + \
                       ', '.join(self.print_arg(a) for a in args)
            case Callq(func, args):
                return '\t' + 'callq' + ' ' + func

    def print_arg(self, a: arg) -> str:
        match a:
            case Reg(id):
                return '%' + id
            case Variable(id):
                return id
            case Immediate(value):
                return '$' + str(value)
            case Deref(reg, offset):
                return str(offset) + '(%' + reg + ')'

