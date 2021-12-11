# Review for Final Exam

## source program (map-tuple)

    def map(f : Callable[[int],int], 
	        v : tuple[(int, int,)]) -> tuple[(int, int,)]:
      return (f(v[0]), f(v[1]),)

    def inc(x:int) -> int:
      return x + 1

    n = input_int()
    print(map(inc, (0, n,))[1])



## shrink

    def map(f:Callable[(<ast.List object at 0x107244430>, int,)], v:tuple[(int, int,)]) -> tuple[(int, int,)]:
      return (f(v[0]), f(v[1]),)

    def inc(x:int) -> int:
      return x + 1

    def main() -> int:
      n = input_int()
      print(map(inc, (0, n,))[1])
      return 0


## reveal_functions

    def map(f:Callable[[int], int], v:tuple[int,int]) -> tuple[int,int]:
      return (f(v[0]), f(v[1]),)

    def inc(x:int) -> int:
      return x + 1

    def main() -> int:
      n = input_int()
      print({map}({inc}, (0, n,))[1])
      return 0


## limit_functions

    def map(f:Callable[[int], int], v:tuple[int,int]) -> tuple[int,int]:
      return (f(v[0]), f(v[1]),)

    def inc(x:int) -> int:
      return x + 1

    def main() -> int:
      n = input_int()
      print({map}({inc}, (0, n,))[1])
      return 0


## expose_allocation

    def map(f:Callable[[int], int], v:tuple[int,int]) -> tuple[int,int]:
      return {
        init.156 = f(v[0])
        init.157 = f(v[1])
        if free_ptr + 24 < fromspace_end:
        else:
          collect(24)
        alloc.155 = allocate(2,tuple[int,int])
        alloc.155[0] = init.156
        alloc.155[1] = init.157
        alloc.155}

    def inc(x:int) -> int:
      return x + 1

    def main() -> int:
      n = input_int()
      print({map}({inc}, {
        init.159 = 0
        init.160 = n
        if free_ptr + 24 < fromspace_end:
        else:
          collect(24)
        alloc.158 = allocate(2,tuple[int,int])
        alloc.158[0] = init.159
        alloc.158[1] = init.160
        alloc.158})[1])
      return 0


## remove_complex_operands

    def map(f:Callable[[int], int], v:tuple[int,int]) -> tuple[int,int]:
      return {
        tmp.161 = v[0]
        init.156 = f(tmp.161)
        tmp.162 = v[1]
        init.157 = f(tmp.162)
        tmp.163 = free_ptr
        tmp.164 = tmp.163 + 24
        tmp.165 = fromspace_end
        if tmp.164 < tmp.165:
        else:
          collect(24)
        alloc.155 = allocate(2,tuple[int,int])
        alloc.155[0] = init.156
        alloc.155[1] = init.157
        alloc.155}

    def inc(x:int) -> int:
      return x + 1

    def main() -> int:
      n = input_int()
      fun.166 = {map}
      fun.167 = {inc}
      tmp.171 = {
        init.159 = 0
        init.160 = n
        tmp.168 = free_ptr
        tmp.169 = tmp.168 + 24
        tmp.170 = fromspace_end
        if tmp.169 < tmp.170:
        else:
          collect(24)
        alloc.158 = allocate(2,tuple[int,int])
        alloc.158[0] = init.159
        alloc.158[1] = init.160
        alloc.158}
      tmp.172 = fun.166(fun.167, tmp.171)
      tmp.173 = tmp.172[1]
      print(tmp.173)
      return 0


## explicate_control

	  def map(f:Callable[[int], int], v:tuple[int,int]) -> tuple[int,int]:
	_block.174:
		  alloc.155 = allocate(2,tuple[int,int])
		  alloc.155[0] = init.156
		  alloc.155[1] = init.157
		  return alloc.155
	_block.175:
		  goto _block.174
	_block.176:
		  collect(24)
		  goto _block.174
	_mapstart:
		  tmp.161 = v[0]
		  init.156 = f(tmp.161)
		  tmp.162 = v[1]
		  init.157 = f(tmp.162)
		  tmp.163 = free_ptr
		  tmp.164 = tmp.163 + 24
		  tmp.165 = fromspace_end
		  if tmp.164 < tmp.165:
			goto _block.175
		  else:
			goto _block.176


	  def inc(x:int) -> int:
	_incstart:
		  return x + 1


	  def main() -> int:
	_block.177:
		  alloc.158 = allocate(2,tuple[int,int])
		  alloc.158[0] = init.159
		  alloc.158[1] = init.160
		  tmp.171 = alloc.158
		  tmp.172 = fun.166(fun.167, tmp.171)
		  tmp.173 = tmp.172[1]
		  print(tmp.173)
		  return 0
	_block.178:
		  goto _block.177
	_block.179:
		  collect(24)
		  goto _block.177
	_mainstart:
		  n = input_int()
		  fun.166 = {map}
		  fun.167 = {inc}
		  init.159 = 0
		  init.160 = n
		  tmp.168 = free_ptr
		  tmp.169 = tmp.168 + 24
		  tmp.170 = fromspace_end
		  if tmp.169 < tmp.170:
			goto _block.178
		  else:
			goto _block.179



	type_check_Cfun iterating {'map': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'inc': FunctionType(param_types=[IntType()], ret_type=IntType()), 'main': FunctionType(param_types=[], ret_type=IntType()), 'f': FunctionType(param_types=[IntType()], ret_type=IntType()), 'v': TupleType(types=[IntType(), IntType()]), 'alloc.155': TupleType(types=[IntType(), IntType()]), 'tmp.161': IntType(), 'init.156': IntType(), 'tmp.162': IntType(), 'init.157': IntType(), 'tmp.163': IntType(), 'tmp.164': IntType(), 'tmp.165': IntType()}
	type_check_Cfun iterating {'map': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'inc': FunctionType(param_types=[IntType()], ret_type=IntType()), 'main': FunctionType(param_types=[], ret_type=IntType()), 'f': FunctionType(param_types=[IntType()], ret_type=IntType()), 'v': TupleType(types=[IntType(), IntType()]), 'alloc.155': TupleType(types=[IntType(), IntType()]), 'tmp.161': IntType(), 'init.156': IntType(), 'tmp.162': IntType(), 'init.157': IntType(), 'tmp.163': IntType(), 'tmp.164': IntType(), 'tmp.165': IntType()}
	type_check_Cfun var_types for map
	{'map': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'inc': FunctionType(param_types=[IntType()], ret_type=IntType()), 'main': FunctionType(param_types=[], ret_type=IntType()), 'f': FunctionType(param_types=[IntType()], ret_type=IntType()), 'v': TupleType(types=[IntType(), IntType()]), 'alloc.155': TupleType(types=[IntType(), IntType()]), 'tmp.161': IntType(), 'init.156': IntType(), 'tmp.162': IntType(), 'init.157': IntType(), 'tmp.163': IntType(), 'tmp.164': IntType(), 'tmp.165': IntType()}
	type_check_Cfun iterating {'map': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'inc': FunctionType(param_types=[IntType()], ret_type=IntType()), 'main': FunctionType(param_types=[], ret_type=IntType()), 'x': IntType()}
	type_check_Cfun var_types for inc
	{'map': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'inc': FunctionType(param_types=[IntType()], ret_type=IntType()), 'main': FunctionType(param_types=[], ret_type=IntType()), 'x': IntType()}
	type_check_Cfun iterating {'map': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'inc': FunctionType(param_types=[IntType()], ret_type=IntType()), 'main': FunctionType(param_types=[], ret_type=IntType()), 'alloc.158': TupleType(types=[IntType(), IntType()]), 'tmp.171': TupleType(types=[IntType(), IntType()]), 'tmp.172': Bottom(), 'tmp.173': Bottom(), 'n': IntType(), 'fun.166': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'fun.167': FunctionType(param_types=[IntType()], ret_type=IntType()), 'init.159': IntType(), 'init.160': IntType(), 'tmp.168': IntType(), 'tmp.169': IntType(), 'tmp.170': IntType()}
	type_check_Cfun iterating {'map': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'inc': FunctionType(param_types=[IntType()], ret_type=IntType()), 'main': FunctionType(param_types=[], ret_type=IntType()), 'alloc.158': TupleType(types=[IntType(), IntType()]), 'tmp.171': TupleType(types=[IntType(), IntType()]), 'tmp.172': TupleType(types=[IntType(), IntType()]), 'tmp.173': IntType(), 'n': IntType(), 'fun.166': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'fun.167': FunctionType(param_types=[IntType()], ret_type=IntType()), 'init.159': IntType(), 'init.160': IntType(), 'tmp.168': IntType(), 'tmp.169': IntType(), 'tmp.170': IntType()}
	type_check_Cfun iterating {'map': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'inc': FunctionType(param_types=[IntType()], ret_type=IntType()), 'main': FunctionType(param_types=[], ret_type=IntType()), 'alloc.158': TupleType(types=[IntType(), IntType()]), 'tmp.171': TupleType(types=[IntType(), IntType()]), 'tmp.172': TupleType(types=[IntType(), IntType()]), 'tmp.173': IntType(), 'n': IntType(), 'fun.166': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'fun.167': FunctionType(param_types=[IntType()], ret_type=IntType()), 'init.159': IntType(), 'init.160': IntType(), 'tmp.168': IntType(), 'tmp.169': IntType(), 'tmp.170': IntType()}
	type_check_Cfun var_types for main
	{'map': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'inc': FunctionType(param_types=[IntType()], ret_type=IntType()), 'main': FunctionType(param_types=[], ret_type=IntType()), 'alloc.158': TupleType(types=[IntType(), IntType()]), 'tmp.171': TupleType(types=[IntType(), IntType()]), 'tmp.172': TupleType(types=[IntType(), IntType()]), 'tmp.173': IntType(), 'n': IntType(), 'fun.166': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'fun.167': FunctionType(param_types=[IntType()], ret_type=IntType()), 'init.159': IntType(), 'init.160': IntType(), 'tmp.168': IntType(), 'tmp.169': IntType(), 'tmp.170': IntType()}


## select_instructions

	  def _map() -> tuple[int,int]:
	_block.174:
		  movq _free_ptr(%rip), %r11
		  addq $24, _free_ptr(%rip)
		  movq $5, 0(%r11)
		  movq %r11, alloc.155
		  movq alloc.155, %r11
		  movq init.156, 8(%r11)
		  movq alloc.155, %r11
		  movq init.157, 16(%r11)
		  movq alloc.155, %rax
		  jmp _mapconclusion
	_block.175:
		  jmp _block.174
	_block.176:
		  movq %r15, %rdi
		  movq $24, %rsi
		  callq _collect
		  jmp _block.174
	_mapstart:
		  movq %rdi, f
		  movq %rsi, v
		  movq v, %r11
		  movq 8(%r11), %r11
		  movq %r11, tmp.161
		  movq tmp.161, %rdi
		  callq *f
		  movq %rax, init.156
		  movq v, %r11
		  movq 16(%r11), %r11
		  movq %r11, tmp.162
		  movq tmp.162, %rdi
		  callq *f
		  movq %rax, init.157
		  movq _free_ptr(%rip), tmp.163
		  movq tmp.163, tmp.164
		  addq $24, tmp.164
		  movq _fromspace_end(%rip), tmp.165
		  cmpq tmp.165, tmp.164
		  jl _block.175
		  jmp _block.176


	  def _inc() -> int:
	_incstart:
		  movq %rdi, x
		  movq x, %rax
		  addq $1, %rax
		  jmp _incconclusion


	  def _main() -> int:
	_block.177:
		  movq _free_ptr(%rip), %r11
		  addq $24, _free_ptr(%rip)
		  movq $5, 0(%r11)
		  movq %r11, alloc.158
		  movq alloc.158, %r11
		  movq init.159, 8(%r11)
		  movq alloc.158, %r11
		  movq init.160, 16(%r11)
		  movq alloc.158, tmp.171
		  movq fun.167, %rdi
		  movq tmp.171, %rsi
		  callq *fun.166
		  movq %rax, tmp.172
		  movq tmp.172, %r11
		  movq 16(%r11), %r11
		  movq %r11, tmp.173
		  movq tmp.173, %rdi
		  callq _print_int
		  movq $0, %rax
		  jmp _mainconclusion
	_block.178:
		  jmp _block.177
	_block.179:
		  movq %r15, %rdi
		  movq $24, %rsi
		  callq _collect
		  jmp _block.177
	_mainstart:
		  callq _read_int
		  movq %rax, n
		  leaq _map(%rip), fun.166
		  leaq _inc(%rip), fun.167
		  movq $0, init.159
		  movq n, init.160
		  movq _free_ptr(%rip), tmp.168
		  movq tmp.168, tmp.169
		  addq $24, tmp.169
		  movq _fromspace_end(%rip), tmp.170
		  cmpq tmp.170, tmp.169
		  jl _block.178
		  jmp _block.179


## assign_homes

	uncover live:
	_block.174:

			{ %rsp, init.157, init.156}
	  movq _free_ptr(%rip), %r11

			{ %rsp, init.157, init.156}
	  addq $24, _free_ptr(%rip)

			{ %rsp, init.157, init.156}
	  movq $5, 0(%r11)

			{ %rsp, init.157, init.156}
	  movq %r11, alloc.155

			{ %r11, %rsp, init.157, init.156}
	  movq alloc.155, %r11

			{init.157, alloc.155, %rsp, init.156}
	  movq init.156, 8(%r11)

			{alloc.155, %rsp, init.157, init.156}
	  movq alloc.155, %r11

			{alloc.155, %rsp, init.157}
	  movq init.157, 16(%r11)

			{alloc.155, %rsp, init.157}
	  movq alloc.155, %rax

			{alloc.155, %rsp}
	  jmp _mapconclusion

			{ %rsp, %rax}
	_block.175:

			{ %rsp, init.157, init.156}
	  jmp _block.174

			{ %rsp, init.157, init.156}
	_block.176:

			{ %rsp, init.157, init.156, %r15}
	  movq %r15, %rdi

			{ %rsp, init.157, init.156, %r15}
	  movq $24, %rsi

			{ %rsp, init.157, %rdi, init.156}
	  callq _collect

			{init.157, %rsp, %rsi, %rdi, init.156}
	  jmp _block.174

			{ %rsp, init.157, init.156}
	_mapstart:

			{ %rdi, %rsp, %rsi, %rax, %r15}
	  movq %rdi, f

			{ %rdi, %rsp, %rsi, %rax, %r15}
	  movq %rsi, v

			{ %rsp, %rsi, %rax, %r15, f}
	  movq v, %r11

			{ %rax, %rsp, v, %r15, f}
	  movq 8(%r11), %r11

			{ %rax, %r11, %rsp, v, %r15, f}
	  movq %r11, tmp.161

			{ %rax, %r11, %rsp, v, %r15, f}
	  movq tmp.161, %rdi

			{ %rax, tmp.161, %rsp, v, %r15, f}
	  callq *f

			{ %rax, %rdi, %rsp, v, %r15, f}
	  movq %rax, init.156

			{ %rax, %rsp, v, %r15, f}
	  movq v, %r11

			{init.156, %rsp, v, %rax, %r15, f}
	  movq 16(%r11), %r11

			{ %r11, init.156, %rsp, %rax, %r15, f}
	  movq %r11, tmp.162

			{ %r11, init.156, %rsp, %rax, %r15, f}
	  movq tmp.162, %rdi

			{tmp.162, init.156, %rsp, %rax, %r15, f}
	  callq *f

			{ %rdi, %rsp, f, %rax, %r15, init.156}
	  movq %rax, init.157

			{ %rsp, %rax, %r15, init.156}
	  movq _free_ptr(%rip), tmp.163

			{ %rsp, init.157, %r15, init.156}
	  movq tmp.163, tmp.164

			{init.157, %rsp, tmp.163, %r15, init.156}
	  addq $24, tmp.164

			{init.157, tmp.164, %rsp, %r15, init.156}
	  movq _fromspace_end(%rip), tmp.165

			{init.157, tmp.164, %rsp, %r15, init.156}
	  cmpq tmp.165, tmp.164

			{init.157, tmp.164, %rsp, tmp.165, %r15, init.156}
	  jl _block.175

			{ %rsp, init.157, %r15, init.156}
	  jmp _block.176

			{ %rsp, init.157, %r15, init.156}
	var_types:
	{'map': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'inc': FunctionType(param_types=[IntType()], ret_type=IntType()), 'main': FunctionType(param_types=[], ret_type=IntType()), 'f': FunctionType(param_types=[IntType()], ret_type=IntType()), 'v': TupleType(types=[IntType(), IntType()]), 'alloc.155': TupleType(types=[IntType(), IntType()]), 'tmp.161': IntType(), 'init.156': IntType(), 'tmp.162': IntType(), 'init.157': IntType(), 'tmp.163': IntType(), 'tmp.164': IntType(), 'tmp.165': IntType()}
	home:
	{Variable('init.157'): Reg('rbx'), Variable('tmp.161'): Reg('rcx'), Variable('alloc.155'): Reg('rcx'), Variable('tmp.164'): Reg('rdx'), Variable('tmp.165'): Reg('rcx'), Variable('tmp.163'): Reg('rcx'), Variable('v'): Reg('rbx'), Variable('f'): Reg('r13'), Variable('tmp.162'): Reg('rcx'), Variable('init.156'): Reg('r12')}
	uncover live:
	_incstart:

			{ %rsp, %rdi}
	  movq %rdi, x

			{ %rsp, %rdi}
	  movq x, %rax

			{ %rsp, x}
	  addq $1, %rax

			{ %rsp, %rax}
	  jmp _incconclusion

			{ %rsp, %rax}
	var_types:
	{'map': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'inc': FunctionType(param_types=[IntType()], ret_type=IntType()), 'main': FunctionType(param_types=[], ret_type=IntType()), 'x': IntType()}
	home:
	{Variable('x'): Reg('rcx')}
	uncover live:
	_block.177:

			{fun.167, fun.166, init.159, %rsp, init.160, %rax}
	  movq _free_ptr(%rip), %r11

			{fun.167, fun.166, init.159, %rsp, init.160, %rax}
	  addq $24, _free_ptr(%rip)

			{fun.167, fun.166, init.159, %rsp, init.160, %rax}
	  movq $5, 0(%r11)

			{fun.167, fun.166, init.159, %rsp, init.160, %rax}
	  movq %r11, alloc.158

			{ %r11, fun.167, fun.166, init.159, %rsp, init.160, %rax}
	  movq alloc.158, %r11

			{fun.167, fun.166, init.159, %rsp, init.160, %rax, alloc.158}
	  movq init.159, 8(%r11)

			{fun.167, fun.166, init.159, %rsp, init.160, %rax, alloc.158}
	  movq alloc.158, %r11

			{fun.167, fun.166, %rsp, init.160, %rax, alloc.158}
	  movq init.160, 16(%r11)

			{fun.167, fun.166, %rsp, init.160, %rax, alloc.158}
	  movq alloc.158, tmp.171

			{ %rax, fun.167, fun.166, %rsp, alloc.158}
	  movq fun.167, %rdi

			{fun.167, %rsp, fun.166, tmp.171, %rax}
	  movq tmp.171, %rsi

			{ %rdi, fun.166, tmp.171, %rax, %rsp}
	  callq *fun.166

			{fun.166, %rdi, %rsp, %rsi, %rax}
	  movq %rax, tmp.172

			{ %rsp, %rax}
	  movq tmp.172, %r11

			{ %rsp, tmp.172}
	  movq 16(%r11), %r11

			{ %r11, %rsp}
	  movq %r11, tmp.173

			{ %r11, %rsp}
	  movq tmp.173, %rdi

			{ %rsp, tmp.173}
	  callq _print_int

			{ %rsp, %rdi}
	  movq $0, %rax

			{ %rsp}
	  jmp _mainconclusion

			{ %rsp, %rax}
	_block.178:

			{fun.167, fun.166, init.159, %rsp, init.160, %rax}
	  jmp _block.177

			{fun.167, fun.166, init.159, %rsp, init.160, %rax}
	_block.179:

			{fun.167, fun.166, init.159, %rsp, init.160, %rax, %r15}
	  movq %r15, %rdi

			{fun.167, fun.166, init.159, %rsp, init.160, %rax, %r15}
	  movq $24, %rsi

			{fun.167, fun.166, init.159, %rsp, init.160, %rdi, %rax}
	  callq _collect

			{fun.167, fun.166, init.159, %rsp, init.160, %rdi, %rsi, %rax}
	  jmp _block.177

			{fun.167, fun.166, init.159, %rsp, init.160, %rax}
	_mainstart:

			{ %rsp, %rax, %r15}
	  callq _read_int

			{ %rsp, %rax, %r15}
	  movq %rax, n

			{ %rsp, %rax, %r15}
	  leaq _map(%rip), fun.166

			{ %rsp, n, %r15, %rax}
	  leaq _inc(%rip), fun.167

			{n, fun.166, %rsp, %rax, %r15}
	  movq $0, init.159

			{n, fun.167, fun.166, %rsp, %rax, %r15}
	  movq n, init.160

			{n, fun.167, fun.166, init.159, %rsp, %rax, %r15}
	  movq _free_ptr(%rip), tmp.168

			{fun.167, fun.166, init.159, %rsp, init.160, %rax, %r15}
	  movq tmp.168, tmp.169

			{tmp.168, fun.167, fun.166, init.159, %rsp, init.160, %rax, %r15}
	  addq $24, tmp.169

			{tmp.169, fun.167, fun.166, init.159, %rsp, init.160, %rax, %r15}
	  movq _fromspace_end(%rip), tmp.170

			{init.160, %rax, %r15, fun.167, tmp.169, init.159, %rsp, fun.166}
	  cmpq tmp.170, tmp.169

			{init.160, %rsp, %rax, %r15, tmp.170, fun.167, tmp.169, init.159, fun.166}
	  jl _block.178

			{fun.167, fun.166, init.159, %rsp, init.160, %rax, %r15}
	  jmp _block.179

			{fun.167, fun.166, init.159, %rsp, init.160, %rax, %r15}
	var_types:
	{'map': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'inc': FunctionType(param_types=[IntType()], ret_type=IntType()), 'main': FunctionType(param_types=[], ret_type=IntType()), 'alloc.158': TupleType(types=[IntType(), IntType()]), 'tmp.171': TupleType(types=[IntType(), IntType()]), 'tmp.172': TupleType(types=[IntType(), IntType()]), 'tmp.173': IntType(), 'n': IntType(), 'fun.166': FunctionType(param_types=[FunctionType(param_types=[IntType()], ret_type=IntType()), TupleType(types=[IntType(), IntType()])], ret_type=TupleType(types=[IntType(), IntType()])), 'fun.167': FunctionType(param_types=[IntType()], ret_type=IntType()), 'init.159': IntType(), 'init.160': IntType(), 'tmp.168': IntType(), 'tmp.169': IntType(), 'tmp.170': IntType()}
	home:
	{Variable('tmp.169'): Reg('rdx'), Variable('n'): Reg('rcx'), Variable('tmp.173'): Reg('rcx'), Variable('init.160'): Reg('rbx'), Variable('tmp.172'): Reg('rcx'), Variable('alloc.158'): Reg('rcx'), Variable('tmp.168'): Reg('rcx'), Variable('fun.167'): Reg('r12'), Variable('tmp.170'): Reg('rcx'), Variable('init.159'): Reg('r14'), Variable('fun.166'): Reg('r13'), Variable('tmp.171'): Reg('rcx')}
	  def _map() -> tuple[int,int]:
	_block.174:
		  movq _free_ptr(%rip), %r11
		  addq $24, _free_ptr(%rip)
		  movq $5, 0(%r11)
		  movq %r11, %rcx
		  movq %rcx, %r11
		  movq %r12, 8(%r11)
		  movq %rcx, %r11
		  movq %rbx, 16(%r11)
		  movq %rcx, %rax
		  jmp _mapconclusion
	_block.175:
		  jmp _block.174
	_block.176:
		  movq %r15, %rdi
		  movq $24, %rsi
		  callq _collect
		  jmp _block.174
	_mapstart:
		  movq %rdi, %r13
		  movq %rsi, %rbx
		  movq %rbx, %r11
		  movq 8(%r11), %r11
		  movq %r11, %rcx
		  movq %rcx, %rdi
		  callq *%r13
		  movq %rax, %r12
		  movq %rbx, %r11
		  movq 16(%r11), %r11
		  movq %r11, %rcx
		  movq %rcx, %rdi
		  callq *%r13
		  movq %rax, %rbx
		  movq _free_ptr(%rip), %rcx
		  movq %rcx, %rdx
		  addq $24, %rdx
		  movq _fromspace_end(%rip), %rcx
		  cmpq %rcx, %rdx
		  jl _block.175
		  jmp _block.176


	  def _inc() -> int:
	_incstart:
		  movq %rdi, %rcx
		  movq %rcx, %rax
		  addq $1, %rax
		  jmp _incconclusion


	  def _main() -> int:
	_block.177:
		  movq _free_ptr(%rip), %r11
		  addq $24, _free_ptr(%rip)
		  movq $5, 0(%r11)
		  movq %r11, %rcx
		  movq %rcx, %r11
		  movq %r14, 8(%r11)
		  movq %rcx, %r11
		  movq %rbx, 16(%r11)
		  movq %rcx, %rcx
		  movq %r12, %rdi
		  movq %rcx, %rsi
		  callq *%r13
		  movq %rax, %rcx
		  movq %rcx, %r11
		  movq 16(%r11), %r11
		  movq %r11, %rcx
		  movq %rcx, %rdi
		  callq _print_int
		  movq $0, %rax
		  jmp _mainconclusion
	_block.178:
		  jmp _block.177
	_block.179:
		  movq %r15, %rdi
		  movq $24, %rsi
		  callq _collect
		  jmp _block.177
	_mainstart:
		  callq _read_int
		  movq %rax, %rcx
		  leaq _map(%rip), %r13
		  leaq _inc(%rip), %r12
		  movq $0, %r14
		  movq %rcx, %rbx
		  movq _free_ptr(%rip), %rcx
		  movq %rcx, %rdx
		  addq $24, %rdx
		  movq _fromspace_end(%rip), %rcx
		  cmpq %rcx, %rdx
		  jl _block.178
		  jmp _block.179


## patch_instructions

	  def _map() -> tuple[int,int]:
	_block.174:
		  movq _free_ptr(%rip), %r11
		  addq $24, _free_ptr(%rip)
		  movq $5, 0(%r11)
		  movq %r11, %rcx
		  movq %rcx, %r11
		  movq %r12, 8(%r11)
		  movq %rcx, %r11
		  movq %rbx, 16(%r11)
		  movq %rcx, %rax
		  jmp _mapconclusion
	_block.175:
		  jmp _block.174
	_block.176:
		  movq %r15, %rdi
		  movq $24, %rsi
		  callq _collect
		  jmp _block.174
	_mapstart:
		  movq %rdi, %r13
		  movq %rsi, %rbx
		  movq %rbx, %r11
		  movq 8(%r11), %r11
		  movq %r11, %rcx
		  movq %rcx, %rdi
		  callq *%r13
		  movq %rax, %r12
		  movq %rbx, %r11
		  movq 16(%r11), %r11
		  movq %r11, %rcx
		  movq %rcx, %rdi
		  callq *%r13
		  movq %rax, %rbx
		  movq _free_ptr(%rip), %rcx
		  movq %rcx, %rdx
		  addq $24, %rdx
		  movq _fromspace_end(%rip), %rcx
		  cmpq %rcx, %rdx
		  jl _block.175
		  jmp _block.176


	  def _inc() -> int:
	_incstart:
		  movq %rdi, %rcx
		  movq %rcx, %rax
		  addq $1, %rax
		  jmp _incconclusion


	  def _main() -> int:
	_block.177:
		  movq _free_ptr(%rip), %r11
		  addq $24, _free_ptr(%rip)
		  movq $5, 0(%r11)
		  movq %r11, %rcx
		  movq %rcx, %r11
		  movq %r14, 8(%r11)
		  movq %rcx, %r11
		  movq %rbx, 16(%r11)
		  movq %r12, %rdi
		  movq %rcx, %rsi
		  callq *%r13
		  movq %rax, %rcx
		  movq %rcx, %r11
		  movq 16(%r11), %r11
		  movq %r11, %rcx
		  movq %rcx, %rdi
		  callq _print_int
		  movq $0, %rax
		  jmp _mainconclusion
	_block.178:
		  jmp _block.177
	_block.179:
		  movq %r15, %rdi
		  movq $24, %rsi
		  callq _collect
		  jmp _block.177
	_mainstart:
		  callq _read_int
		  movq %rax, %rcx
		  leaq _map(%rip), %r13
		  leaq _inc(%rip), %r12
		  movq $0, %r14
		  movq %rcx, %rbx
		  movq _free_ptr(%rip), %rcx
		  movq %rcx, %rdx
		  addq $24, %rdx
		  movq _fromspace_end(%rip), %rcx
		  cmpq %rcx, %rdx
		  jl _block.178
		  jmp _block.179


## prelude and conclusion

		.align 16
	_block.174:
		movq _free_ptr(%rip), %r11
		addq $24, _free_ptr(%rip)
		movq $5, 0(%r11)
		movq %r11, %rcx
		movq %rcx, %r11
		movq %r12, 8(%r11)
		movq %rcx, %r11
		movq %rbx, 16(%r11)
		movq %rcx, %rax
		jmp _mapconclusion

		.align 16
	_block.175:
		jmp _block.174

		.align 16
	_block.176:
		movq %r15, %rdi
		movq $24, %rsi
		callq _collect
		jmp _block.174

		.align 16
	_mapstart:
		movq %rdi, %r13
		movq %rsi, %rbx
		movq %rbx, %r11
		movq 8(%r11), %r11
		movq %r11, %rcx
		movq %rcx, %rdi
		callq *%r13
		movq %rax, %r12
		movq %rbx, %r11
		movq 16(%r11), %r11
		movq %r11, %rcx
		movq %rcx, %rdi
		callq *%r13
		movq %rax, %rbx
		movq _free_ptr(%rip), %rcx
		movq %rcx, %rdx
		addq $24, %rdx
		movq _fromspace_end(%rip), %rcx
		cmpq %rcx, %rdx
		jl _block.175
		jmp _block.176

		.align 16
	_map:
		pushq %rbp
		movq %rsp, %rbp
		pushq %rbx
		pushq %r13
		pushq %r12
		subq $8, %rsp
		jmp _mapstart

		.align 16
	_mapconclusion:
		subq $0, %r15
		addq $8, %rsp
		popq %r12
		popq %r13
		popq %rbx
		popq %rbp
		retq 

		.align 16
	_incstart:
		movq %rdi, %rcx
		movq %rcx, %rax
		addq $1, %rax
		jmp _incconclusion

		.align 16
	_inc:
		pushq %rbp
		movq %rsp, %rbp
		subq $0, %rsp
		jmp _incstart

		.align 16
	_incconclusion:
		subq $0, %r15
		addq $0, %rsp
		popq %rbp
		retq 

		.align 16
	_block.177:
		movq _free_ptr(%rip), %r11
		addq $24, _free_ptr(%rip)
		movq $5, 0(%r11)
		movq %r11, %rcx
		movq %rcx, %r11
		movq %r14, 8(%r11)
		movq %rcx, %r11
		movq %rbx, 16(%r11)
		movq %r12, %rdi
		movq %rcx, %rsi
		callq *%r13
		movq %rax, %rcx
		movq %rcx, %r11
		movq 16(%r11), %r11
		movq %r11, %rcx
		movq %rcx, %rdi
		callq _print_int
		movq $0, %rax
		jmp _mainconclusion

		.align 16
	_block.178:
		jmp _block.177

		.align 16
	_block.179:
		movq %r15, %rdi
		movq $24, %rsi
		callq _collect
		jmp _block.177

		.align 16
	_mainstart:
		callq _read_int
		movq %rax, %rcx
		leaq _map(%rip), %r13
		leaq _inc(%rip), %r12
		movq $0, %r14
		movq %rcx, %rbx
		movq _free_ptr(%rip), %rcx
		movq %rcx, %rdx
		addq $24, %rdx
		movq _fromspace_end(%rip), %rcx
		cmpq %rcx, %rdx
		jl _block.178
		jmp _block.179

		.globl _main
		.align 16
	_main:
		pushq %rbp
		movq %rsp, %rbp
		pushq %r14
		pushq %rbx
		pushq %r13
		pushq %r12
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
		popq %r12
		popq %r13
		popq %rbx
		popq %r14
		popq %rbp
		retq 



