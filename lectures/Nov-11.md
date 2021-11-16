# Compiling Functions, Continued


## Example of a tail call

source program 

	  def sum(x:int,s:int)-> int :
		if x == 0:
		  return s
		else:
		  return sum(x - 1, x + s)

	  print(sum(3, 0) + 36)

shrink 

	  def sum(x:<class 'int'>,s:<class 'int'>)-> <class 'int'> :
		if x == 0:
		  return s
		else:
		  return sum(x - 1, x + s)

	  def main()-> <class 'int'> :
		print(sum(3, 0) + 36)
		return 0

reveal functions 

	  def sum(x:<class 'int'>,s:<class 'int'>)-> <class 'int'> :
		if x == 0:
		  return s
		else:
		  return sum(%rip)(x - 1, x + s)

	  def main()-> <class 'int'> :
		print(sum(%rip)(3, 0) + 36)
		return 0

limit functions 

	  def sum(x:<class 'int'>,s:<class 'int'>)-> <class 'int'> :
		if x == 0:
		  return s
		else:
		  return sum(%rip)(x - 1, x + s)
	  def main()-> <class 'int'> :
		print(sum(%rip)(3, 0) + 36)
		return 0

expose allocation 

	  def sum(x:<class 'int'>,s:<class 'int'>)-> <class 'int'> :
		if x == 0:
		  return s
		else:
		  return sum(%rip)(x - 1, x + s)
	  def main()-> <class 'int'> :
		print(sum(%rip)(3, 0) + 36)
		return 0

remove complex operands 

	  def sum(x:<class 'int'>,s:<class 'int'>)-> <class 'int'> :
		if x == 0:
		  return s
		else:
		  fun.0 = sum(%rip)
		  tmp.1 = x - 1
		  tmp.2 = x + s
		  return fun.0(tmp.1, tmp.2)

	  def main()-> <class 'int'> :
		fun.3 = sum(%rip)
		tmp.4 = fun.3(3, 0)
		tmp.5 = tmp.4 + 36
		print(tmp.5)
		return 0

explicate control 

	def sum(x:<class 'int'>,s:<class 'int'>)-> <class 'int'> :
	_block.7:
		return s
	_block.8:
		fun.0 = sum(%rip)
		tmp.1 = x - 1
		tmp.2 = x + s
		fun.0(tmp.1,tmp.2)

	_sumstart:
		if x == 0:
		  goto _block.7
		else:
		  goto _block.8

	def main()-> <class 'int'> :
	_mainstart:
		fun.3 = sum(%rip)
		tmp.4 = fun.3(3, 0)
		tmp.5 = tmp.4 + 36
		print(tmp.5)
		return 0

select instructions

	def _sum()-> <class 'int'> :
	_block.7:
		movq s, %rax
		jmp _sumconclusion
	_block.8:
		leaq _sum(%rip), fun.0
		movq x, tmp.1
		subq $1, tmp.1
		movq x, tmp.2
		addq s, tmp.2
		movq tmp.1, %rdi
		movq tmp.2, %rsi
		tailjmp fun.0
	_sumstart:
		movq %rdi, x
		movq %rsi, s
		cmpq $0, x
		je _block.7
		jmp _block.8

	def _main()-> <class 'int'> :
	_mainstart:
		leaq _sum(%rip), fun.3
		movq $3, %rdi
		movq $0, %rsi
		callq *fun.3
		movq %rax, tmp.4
		movq tmp.4, tmp.5
		addq $36, tmp.5
		movq tmp.5, %rdi
		callq _print_int
		movq $0, %rax
		jmp _mainconclusion

register allocation

	def _sum(x:<class 'int'>,s:<class 'int'>)-> <class 'int'> :
	_block.6:
	_block.7:
		movq %rsi, %rax
		jmp _sumconclusion
	_block.8:
		leaq _sum(%rip), %rdx
		movq %rcx, %rdi
		subq $1, %rdi
		movq %rcx, %rcx
		addq %rsi, %rcx
		movq %rdi, %rdi
		movq %rcx, %rsi
		tailjmp %rdx
	_sumstart:
		movq %rdi, %rcx
		movq %rsi, %rsi
		cmpq $0, %rcx
		je _block.7
		jmp _block.8

	def _main()-> <class 'int'> :
	_mainstart:
		leaq _sum(%rip), %rcx
		movq $3, %rdi
		movq $0, %rsi
		callq *%rcx
		movq %rax, %rcx
		movq %rcx, %rcx
		addq $36, %rcx
		movq %rcx, %rdi
		callq _print_int
		movq $0, %rax
		jmp _mainconclusion

patch instructions

	def _sum(x:<class 'int'>,s:<class 'int'>)-> <class 'int'> :
	_block.6:
	_block.7:
		movq %rsi, %rax
		jmp _sumconclusion
	_block.8:
		leaq _sum(%rip), %rdx
		movq %rcx, %rdi
		subq $1, %rdi
		addq %rsi, %rcx
		movq %rcx, %rsi
		movq %rdx, %rax
		tailjmp %rax
	_sumstart:
		movq %rdi, %rcx
		cmpq $0, %rcx
		je _block.7
		jmp _block.8

	def _main()-> <class 'int'> :
	_mainstart:
		leaq _sum(%rip), %rcx
		movq $3, %rdi
		movq $0, %rsi
		callq *%rcx
		movq %rax, %rcx
		addq $36, %rcx
		movq %rcx, %rdi
		callq _print_int
		movq $0, %rax
		jmp _mainconclusion

prelude and conclusion 

		.align 16
	_block.6:

		.align 16
	_block.7:
	  movq %rsi, %rax
	  jmp _sumconclusion

		.align 16
	_block.8:
	  leaq _sum(%rip), %rdx
	  movq %rcx, %rdi
	  subq $1, %rdi
	  addq %rsi, %rcx
	  movq %rcx, %rsi
	  movq %rdx, %rax
	  subq $0, %r15
	  addq $0, %rsp
	  popq %rbp
	  jmp *%rax

		.align 16
	_sumstart:
	  movq %rdi, %rcx
	  cmpq $0, %rcx
	  je _block.7
	  jmp _block.8

		.align 16
	_sum:
	  pushq %rbp
	  movq %rsp, %rbp
	  subq $0, %rsp
	  jmp _sumstart

		.align 16
	_sumconclusion:
	  subq $0, %r15
	  addq $0, %rsp
	  popq %rbp
	  retq 

		.align 16
	_mainstart:
	  leaq _sum(%rip), %rcx
	  movq $3, %rdi
	  movq $0, %rsi
	  callq *%rcx
	  movq %rax, %rcx
	  addq $36, %rcx
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



## Example of function with too many parameters

source program 

	  def sum(a:int,b:int,c:int,d:int,e:int,f:int,g:int,h:int)-> int :
		return a + b + c + d + e + f + g + h
	  print(sum(5, 5, 5, 5, 5, 5, 5, 7))


shrink 

	  def sum(a:<class 'int'>,b:<class 'int'>,c:<class 'int'>,d:<class 'int'>,e:<class 'int'>,f:<class 'int'>,g:<class 'int'>,h:<class 'int'>)-> <class 'int'> :
		return a + b + c + d + e + f + g + h

	  def main()-> <class 'int'> :
		print(sum(5, 5, 5, 5, 5, 5, 5, 7))
		return 0


reveal functions 

	  def sum(a:int,b:int,c:int,d:int,e:int,f:int,g:int,h:int)-> int :
		return a + b + c + d + e + f + g + h

	  def main()-> int :
		print(sum(%rip)(5, 5, 5, 5, 5, 5, 5, 7))
		return 0

limit functions 

	  def sum(a:int,b:int,c:int,d:int,e:int,tup.0:(int,int,int))-> int :
		return a + b + c + d + e + tup.0[0] + tup.0[1] + tup.0[2]
	  def main()-> int :
		print(sum(%rip)(5, 5, 5, 5, 5, (5,5,7,)))
		return 0

expose allocation 

	  def sum(a:<class 'int'>,b:<class 'int'>,c:<class 'int'>,d:<class 'int'>,e:<class 'int'>,tup.0:(<class 'int'>,<class 'int'>,<class 'int'>))-> <class 'int'> :
		return a + b + c + d + e + tup.0[0] + tup.0[1] + tup.0[2]
	  def main()-> <class 'int'> :
		print(sum(%rip)(5, 5, 5, 5, 5, begin:
		  if free_ptr + 32 < fromspace_end:
		  else:
			collect(32)
		  alloc.1 = allocate(3,(<class 'int'>,<class 'int'>,<class 'int'>))
		  alloc.1[0] = 5
		  alloc.1[1] = 5
		  alloc.1[2] = 7
		  alloc.1))
		return 0

remove complex operands 

	  def sum(a:<class 'int'>,b:<class 'int'>,c:<class 'int'>,d:<class 'int'>,e:<class 'int'>,tup.0:(<class 'int'>,<class 'int'>,<class 'int'>))-> <class 'int'> :
		tmp.2 = a + b
		tmp.3 = tmp.2 + c
		tmp.4 = tmp.3 + d
		tmp.5 = tmp.4 + e
		tmp.6 = tup.0[0]
		tmp.7 = tmp.5 + tmp.6
		tmp.8 = tup.0[1]
		tmp.9 = tmp.7 + tmp.8
		tmp.10 = tup.0[2]
		return tmp.9 + tmp.10
	  def main()-> <class 'int'> :
		fun.11 = sum(%rip)
		tmp.15 = begin:
		  tmp.12 = free_ptr
		  tmp.13 = tmp.12 + 32
		  tmp.14 = fromspace_end
		  if tmp.13 < tmp.14:
		  else:
			collect(32)
		  alloc.1 = allocate(3,(<class 'int'>,<class 'int'>,<class 'int'>))
		  alloc.1[0] = 5
		  alloc.1[1] = 5
		  alloc.1[2] = 7
		  alloc.1
		tmp.16 = fun.11(5, 5, 5, 5, 5, tmp.15)
		print(tmp.16)
		return 0

explicate control 

	def sum(a:<class 'int'>,b:<class 'int'>,c:<class 'int'>,d:<class 'int'>,e:<class 'int'>,tup.0:(<class 'int'>,<class 'int'>,<class 'int'>))-> <class 'int'> :
	_sumstart:
		tmp.2 = a + b
		tmp.3 = tmp.2 + c
		tmp.4 = tmp.3 + d
		tmp.5 = tmp.4 + e
		tmp.6 = tup.0[0]
		tmp.7 = tmp.5 + tmp.6
		tmp.8 = tup.0[1]
		tmp.9 = tmp.7 + tmp.8
		tmp.10 = tup.0[2]
		return tmp.9 + tmp.10

	def main()-> <class 'int'> :
	_block.17:
		alloc.1 = allocate(3,(<class 'int'>,<class 'int'>,<class 'int'>))
		alloc.1[0] = 5
		alloc.1[1] = 5
		alloc.1[2] = 7
		tmp.15 = alloc.1
		tmp.16 = fun.11(5, 5, 5, 5, 5, tmp.15)
		print(tmp.16)
		return 0
	_block.18:
		goto _block.17
	_block.19:
		collect(32)
		goto _block.17
	_mainstart:
		fun.11 = sum(%rip)
		tmp.12 = free_ptr
		tmp.13 = tmp.12 + 32
		tmp.14 = fromspace_end
		if tmp.13 < tmp.14:
		  goto _block.18
		else:
		  goto _block.19

select instructions

	def _sum(a:<class 'int'>,b:<class 'int'>,c:<class 'int'>,d:<class 'int'>,e:<class 'int'>,tup.0:(<class 'int'>,<class 'int'>,<class 'int'>))-> <class 'int'> :
	_sumstart:
		movq %rdi, a
		movq %rsi, b
		movq %rdx, c
		movq %rcx, d
		movq %r8, e
		movq %r9, tup.0
		movq a, tmp.2
		addq b, tmp.2
		movq tmp.2, tmp.3
		addq c, tmp.3
		movq tmp.3, tmp.4
		addq d, tmp.4
		movq tmp.4, tmp.5
		addq e, tmp.5
		movq tup.0, %r11
		movq 8(%r11), %r11
		movq %r11, tmp.6
		movq tmp.5, tmp.7
		addq tmp.6, tmp.7
		movq tup.0, %r11
		movq 16(%r11), %r11
		movq %r11, tmp.8
		movq tmp.7, tmp.9
		addq tmp.8, tmp.9
		movq tup.0, %r11
		movq 24(%r11), %r11
		movq %r11, tmp.10
		movq tmp.9, %rax
		addq tmp.10, %rax
		jmp _sumconclusion

	def _main()-> <class 'int'> :
	_block.17:
		movq _free_ptr(%rip), %r11
		addq $32, _free_ptr(%rip)
		movq $7, 0(%r11)
		movq %r11, alloc.1
		movq alloc.1, %r11
		movq $5, 8(%r11)
		movq alloc.1, %r11
		movq $5, 16(%r11)
		movq alloc.1, %r11
		movq $7, 24(%r11)
		movq alloc.1, tmp.15
		movq $5, %rdi
		movq $5, %rsi
		movq $5, %rdx
		movq $5, %rcx
		movq $5, %r8
		movq tmp.15, %r9
		callq *fun.11
		movq %rax, tmp.16
		movq tmp.16, %rdi
		callq _print_int
		movq $0, %rax
		jmp _mainconclusion
	_block.18:
		jmp _block.17
	_block.19:
		movq %r15, %rdi
		movq $32, %rsi
		callq _collect
		jmp _block.17
	_mainstart:
		leaq _sum(%rip), fun.11
		movq _free_ptr(%rip), tmp.12
		movq tmp.12, tmp.13
		addq $32, tmp.13
		movq _fromspace_end(%rip), tmp.14
		cmpq tmp.14, tmp.13
		jl _block.18
		jmp _block.19



register allocation

	def _sum(a:<class 'int'>,b:<class 'int'>,c:<class 'int'>,d:<class 'int'>,e:<class 'int'>,tup.0:(<class 'int'>,<class 'int'>,<class 'int'>))-> <class 'int'> :
	_sumstart:
		movq %rdi, %rdi
		movq %rsi, %rsi
		movq %rdx, %rdx
		movq %rcx, %rcx
		movq %r8, %r8
		movq %r9, %r9
		movq %rdi, %rdi
		addq %rsi, %rdi
		movq %rdi, %rsi
		addq %rdx, %rsi
		movq %rsi, %rdx
		addq %rcx, %rdx
		movq %rdx, %rcx
		addq %r8, %rcx
		movq %r9, %r11
		movq 8(%r11), %r11
		movq %r11, %rdx
		movq %rcx, %rcx
		addq %rdx, %rcx
		movq %r9, %r11
		movq 16(%r11), %r11
		movq %r11, %rdx
		movq %rcx, %rcx
		addq %rdx, %rcx
		movq %r9, %r11
		movq 24(%r11), %r11
		movq %r11, %rdx
		movq %rcx, %rax
		addq %rdx, %rax
		jmp _sumconclusion

	def _main()-> <class 'int'> :
	_block.17:
		movq _free_ptr(%rip), %r11
		addq $32, _free_ptr(%rip)
		movq $7, 0(%r11)
		movq %r11, %rcx
		movq %rcx, %r11
		movq $5, 8(%r11)
		movq %rcx, %r11
		movq $5, 16(%r11)
		movq %rcx, %r11
		movq $7, 24(%r11)
		movq %rcx, %r9
		movq $5, %rdi
		movq $5, %rsi
		movq $5, %rdx
		movq $5, %rcx
		movq $5, %r8
		movq %r9, %r9
		callq *%rbx
		movq %rax, %rcx
		movq %rcx, %rdi
		callq _print_int
		movq $0, %rax
		jmp _mainconclusion
	_block.18:
		jmp _block.17
	_block.19:
		movq %r15, %rdi
		movq $32, %rsi
		callq _collect
		jmp _block.17
	_mainstart:
		leaq _sum(%rip), %rbx
		movq _free_ptr(%rip), %rcx
		movq %rcx, %rdx
		addq $32, %rdx
		movq _fromspace_end(%rip), %rcx
		cmpq %rcx, %rdx
		jl _block.18
		jmp _block.19


patch instructions

	def _sum(a:<class 'int'>,b:<class 'int'>,c:<class 'int'>,d:<class 'int'>,e:<class 'int'>,tup.0:(<class 'int'>,<class 'int'>,<class 'int'>))-> <class 'int'> :
	_sumstart:
		addq %rsi, %rdi
		movq %rdi, %rsi
		addq %rdx, %rsi
		movq %rsi, %rdx
		addq %rcx, %rdx
		movq %rdx, %rcx
		addq %r8, %rcx
		movq %r9, %r11
		movq 8(%r11), %r11
		movq %r11, %rdx
		addq %rdx, %rcx
		movq %r9, %r11
		movq 16(%r11), %r11
		movq %r11, %rdx
		addq %rdx, %rcx
		movq %r9, %r11
		movq 24(%r11), %r11
		movq %r11, %rdx
		movq %rcx, %rax
		addq %rdx, %rax
		jmp _sumconclusion

	def _main()-> <class 'int'> :
	_block.17:
		movq _free_ptr(%rip), %r11
		addq $32, _free_ptr(%rip)
		movq $7, 0(%r11)
		movq %r11, %rcx
		movq %rcx, %r11
		movq $5, 8(%r11)
		movq %rcx, %r11
		movq $5, 16(%r11)
		movq %rcx, %r11
		movq $7, 24(%r11)
		movq %rcx, %r9
		movq $5, %rdi
		movq $5, %rsi
		movq $5, %rdx
		movq $5, %rcx
		movq $5, %r8
		callq *%rbx
		movq %rax, %rcx
		movq %rcx, %rdi
		callq _print_int
		movq $0, %rax
		jmp _mainconclusion
	_block.18:
		jmp _block.17
	_block.19:
		movq %r15, %rdi
		movq $32, %rsi
		callq _collect
		jmp _block.17
	_mainstart:
		leaq _sum(%rip), %rbx
		movq _free_ptr(%rip), %rcx
		movq %rcx, %rdx
		addq $32, %rdx
		movq _fromspace_end(%rip), %rcx
		cmpq %rcx, %rdx
		jl _block.18
		jmp _block.19


prelude and conclusion 

		.align 16
	_sumstart:
	  addq %rsi, %rdi
	  movq %rdi, %rsi
	  addq %rdx, %rsi
	  movq %rsi, %rdx
	  addq %rcx, %rdx
	  movq %rdx, %rcx
	  addq %r8, %rcx
	  movq %r9, %r11
	  movq 8(%r11), %r11
	  movq %r11, %rdx
	  addq %rdx, %rcx
	  movq %r9, %r11
	  movq 16(%r11), %r11
	  movq %r11, %rdx
	  addq %rdx, %rcx
	  movq %r9, %r11
	  movq 24(%r11), %r11
	  movq %r11, %rdx
	  movq %rcx, %rax
	  addq %rdx, %rax
	  jmp _sumconclusion

		.align 16
	_sum:
	  pushq %rbp
	  movq %rsp, %rbp
	  subq $0, %rsp
	  jmp _sumstart

		.align 16
	_sumconclusion:
	  subq $0, %r15
	  addq $0, %rsp
	  popq %rbp
	  retq 

		.align 16
	_block.17:
	  movq _free_ptr(%rip), %r11
	  addq $32, _free_ptr(%rip)
	  movq $7, 0(%r11)
	  movq %r11, %rcx
	  movq %rcx, %r11
	  movq $5, 8(%r11)
	  movq %rcx, %r11
	  movq $5, 16(%r11)
	  movq %rcx, %r11
	  movq $7, 24(%r11)
	  movq %rcx, %r9
	  movq $5, %rdi
	  movq $5, %rsi
	  movq $5, %rdx
	  movq $5, %rcx
	  movq $5, %r8
	  callq *%rbx
	  movq %rax, %rcx
	  movq %rcx, %rdi
	  callq _print_int
	  movq $0, %rax
	  jmp _mainconclusion

		.align 16
	_block.18:
	  jmp _block.17

		.align 16
	_block.19:
	  movq %r15, %rdi
	  movq $32, %rsi
	  callq _collect
	  jmp _block.17

		.align 16
	_mainstart:
	  leaq _sum(%rip), %rbx
	  movq _free_ptr(%rip), %rcx
	  movq %rcx, %rdx
	  addq $32, %rdx
	  movq _fromspace_end(%rip), %rcx
	  cmpq %rcx, %rdx
	  jl _block.18
	  jmp _block.19

		.globl _main
		.align 16
	_main:
	  pushq %rbp
	  movq %rsp, %rbp
	  pushq %rbx
	  subq $8, %rsp
	  movq $65536, %rdi
	  movq $65536, %rsi
	  callq _initialize
	  movq _rootstack_begin(%rip), %r15
	  jmp _mainstart

		.align 16
	_mainconclusion:
	  subq $0, %r15
	  addq $8, %rsp
	  popq %rbx
	  popq %rbp
	  retq 

