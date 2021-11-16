# Compiling Functions, Continued

## Example of a simple function

source program 

	  def add(x:int,y:int)-> int :
		return x + y
	  print(add(40, 2))

shrink 

	  def add(x:<class 'int'>,y:<class 'int'>)-> <class 'int'> :
		return x + y
	  def main()-> <class 'int'> :
		print(add(40, 2))
		return 0

reveal functions 

	  def add(x:<class 'int'>,y:<class 'int'>)-> <class 'int'> :
		return x + y
	  def main()-> <class 'int'> :
		print(add(%rip)(40, 2))
		return 0

limit functions 

	  def add(x:<class 'int'>,y:<class 'int'>)-> <class 'int'> :
		return x + y
	  def main()-> <class 'int'> :
		print(add(%rip)(40, 2))
		return 0

expose allocation 

	  def add(x:<class 'int'>,y:<class 'int'>)-> <class 'int'> :
		return x + y
	  def main()-> <class 'int'> :
		print(add(%rip)(40, 2))
		return 0

remove complex operands 

	  def add(x:<class 'int'>,y:<class 'int'>)-> <class 'int'> :
		return x + y
	  def main()-> <class 'int'> :
		fun.0 = add(%rip)
		tmp.1 = fun.0(40, 2)
		print(tmp.1)
		return 0

explicate control 

	def add(x:<class 'int'>,y:<class 'int'>)-> <class 'int'> :
	_addstart:
		return x + y

	def main()-> <class 'int'> :
	_mainstart:
		fun.0 = add(%rip)
		tmp.1 = fun.0(40, 2)
		print(tmp.1)
		return 0

select 

	def _add()-> <class 'int'> :
	_addstart:
		movq %rdi, x
		movq %rsi, y
		movq x, %rax
		addq y, %rax
		jmp _addconclusion

	def _main()-> <class 'int'> :
	_mainstart:
		leaq _add(%rip), fun.0
		movq $40, %rdi
		movq $2, %rsi
		callq *fun.0
		movq %rax, tmp.1
		movq tmp.1, %rdi
		callq _print_int
		movq $0, %rax
		jmp _mainconclusion

register allocation

	def _add(x:<class 'int'>,y:<class 'int'>)-> <class 'int'> :
	_addstart:
		movq %rdi, %rcx
		movq %rsi, %rdx
		movq %rcx, %rax
		addq %rdx, %rax
		jmp _addconclusion

	def _main()-> <class 'int'> :
	_mainstart:
		leaq _add(%rip), %rcx
		movq $40, %rdi
		movq $2, %rsi
		callq *%rcx
		movq %rax, %rcx
		movq %rcx, %rdi
		callq _print_int
		movq $0, %rax
		jmp _mainconclusion

patch instructions

	def _add(x:<class 'int'>,y:<class 'int'>)-> <class 'int'> :
	_addstart:
		movq %rdi, %rcx
		movq %rsi, %rdx
		movq %rcx, %rax
		addq %rdx, %rax
		jmp _addconclusion

	def _main()-> <class 'int'> :
	_mainstart:
		leaq _add(%rip), %rcx
		movq $40, %rdi
		movq $2, %rsi
		callq *%rcx
		movq %rax, %rcx
		movq %rcx, %rdi
		callq _print_int
		movq $0, %rax
		jmp _mainconclusion

prelude and conclusion 

		.align 16
	_addstart:
	  movq %rdi, %rcx
	  movq %rsi, %rdx
	  movq %rcx, %rax
	  addq %rdx, %rax
	  jmp _addconclusion

		.align 16
	_add:
	  pushq %rbp
	  movq %rsp, %rbp
	  subq $0, %rsp
	  jmp _addstart

		.align 16
	_addconclusion:
	  subq $0, %r15
	  addq $0, %rsp
	  popq %rbp
	  retq 

		.align 16
	_mainstart:
	  leaq _add(%rip), %rcx
	  movq $40, %rdi
	  movq $2, %rsi
	  callq *%rcx
	  movq %rax, %rcx
	  movq %rcx, %rdi
	  callq _print_int
	  movq $0, %rax
	  jmp _mainconclusion

		.globl _main
		.align 16
	_main:
	  pushq %rbp
	  movq %rsp, %rbp
	  subq $0, %rsp
	  movq $65536, %rdi
	  movq $65536, %rsi
	  callq _initialize
	  movq _rootstack_begin(%rip), %r15
	  jmp _mainstart

		.align 16
	_mainconclusion:
	  subq $0, %r15
	  addq $0, %rsp
	  popq %rbp
	  retq 

