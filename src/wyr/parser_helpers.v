module wyr

// Call before assigning `variables[name]` when lowering a function body entry.
pub fn scope_note_before_define(mut variables map[string]&Variable, mut ctx ParseCtx, name string) {
	if ctx.fn_exit_label.len == 0 {
		return
	}
	if name in variables {
		ctx.scope_restore << ScopeBinding{
			name:     name
			had_prev: true
			prev:     variables[name]
		}
	} else {
		ctx.scope_restore << ScopeBinding{
			name:     name
			had_prev: false
			prev:     unsafe { nil }
		}
	}
}

pub fn scope_restore_all(mut variables map[string]&Variable, mut ctx ParseCtx) {
	for i := ctx.scope_restore.len - 1; i >= 0; i-- {
		b := ctx.scope_restore[i]
		if b.had_prev {
			variables[b.name] = b.prev
		} else {
			variables.delete(b.name)
		}
	}
	ctx.scope_restore = []ScopeBinding{}
	ctx.fn_local_names = map[string]bool{}
}

pub fn require_variable(name string, variables map[string]&Variable, token &Token) {
	if name !in variables {
		raise(Exception{
			msg:    'Unknown variable'
			source: token.source
			line:   token.line + 1
			hint:   "No such variable '${name}'\nPerhaps it's not declared?"
		})
	}
}

pub fn require_int_for_compare(name string, variables map[string]&Variable, token &Token) {
	require_variable(name, variables, token)
	ty := variables[name].@type
	if ty !in int_compare_types {
		raise(Exception{
			msg:    'Invalid item for comparison'
			source: token.source
			line:   token.line + 1
			hint:   "Variable '${name}'<${ty}> is not of type int\n" +
				'Only integers can be used for evaluation'
		})
	}
}

pub fn emit_compare_load_first(mut text []string, variables map[string]&Variable, raw string, token &Token) {
	if is_numeric(raw) {
		text << '\tmov eax, ${raw}\n'
		return
	}
	require_int_for_compare(raw, variables, token)
	if variables[raw].@type in small_int_types {
		text << '\tmov al, byte [${raw}]\n'
	} else {
		text << '\tmov eax, [${raw}]\n'
	}
}

pub fn emit_compare_second_if(mut text []string, variables map[string]&Variable, raw string, token &Token) {
	if is_numeric(raw) {
		text << '\tcmp eax, ${raw}\n'
		return
	}
	require_int_for_compare(raw, variables, token)
	if variables[raw].@type in small_int_types {
		text << '\tcmp al, byte [${raw}]\n'
	} else {
		text << '\tcmp al, [${raw}]\n'
	}
}

pub fn emit_compare_second_while(mut text []string, variables map[string]&Variable, raw string, token &Token) {
	if is_numeric(raw) {
		text << '\tcmp eax, ${raw}\n'
		return
	}
	require_int_for_compare(raw, variables, token)
	if variables[raw].@type in small_int_types {
		text << '\tcmp al, byte [${raw}]\n'
	} else if variables[raw].@type == Types.i64 {
		text << '\tcmp eax, dword [${raw}]\n'
	} else {
		text << '\tcmp eax, [${raw}]\n'
	}
}

pub fn require_int_for_math(name string, variables map[string]&Variable, token &Token) {
	require_variable(name, variables, token)
	if variables[name].@type !in int_compare_types {
		raise(Exception{
			msg:    'Invalid item for mathematical operations'
			source: token.source
			line:   token.line + 1
			hint:   "Variable '${name}' is not of type int\nOnly integers can be used"
		})
	}
}

pub fn asm_scalar_kw(valtype Types) string {
	return match valtype {
		.i8 { 'db' }
		.i16 { 'dw' }
		.i32 { 'dd' }
		.i64 { 'dq' }
		.integer { 'dd' }
		else { '' }
	}
}

pub fn declare_scalar_int(mut bss []string, mut data []string, id string, value string, valtype Types, is_const bool) {
	kw := asm_scalar_kw(valtype)
	if kw == '' {
		return
	}
	if is_const {
		bss << '\t${id} equ ${value}\n'
	} else {
		data << '\t${id}: ${kw} ${value}\n'
	}
}

pub fn register_int_var(mut variables map[string]&Variable, id string, valtype Types, value string, token &Token, is_const bool) {
	variables[id] = &Variable{
		id:        id
		@type:     valtype
		value:     value
		token:     *token
		@const:    is_const
		param_reg: ''
	}
}

pub fn is_scalar_int_type(t Types) bool {
	return t in [.i8, .i16, .i32, .i64, .integer]
}

pub const abi_arg_regs = ['rdi', 'rsi', 'rdx', 'rcx', 'r8', 'r9']

// 64-bit SysV argument register names must use 8/16/32-bit subregs with 32-bit instructions (e.g. `mov eax, edi`), not `mov eax, rdi`.
pub fn abi_reg_low8(reg64 string) string {
	return match reg64 {
		'rdi' { 'dil' }
		'rsi' { 'sil' }
		'rdx' { 'dl' }
		'rcx' { 'cl' }
		'r8' { 'r8b' }
		'r9' { 'r9b' }
		else { reg64 }
	}
}

pub fn abi_reg_low16(reg64 string) string {
	return match reg64 {
		'rdi' { 'di' }
		'rsi' { 'si' }
		'rdx' { 'dx' }
		'rcx' { 'cx' }
		'r8' { 'r8w' }
		'r9' { 'r9w' }
		else { reg64 }
	}
}

pub fn abi_reg_low32(reg64 string) string {
	return match reg64 {
		'rdi' { 'edi' }
		'rsi' { 'esi' }
		'rdx' { 'edx' }
		'rcx' { 'ecx' }
		'r8' { 'r8d' }
		'r9' { 'r9d' }
		else { reg64 }
	}
}

pub fn emit_value_into_eax(mut text []string, variables map[string]&Variable, s string, tok &Token) {
	e := parse_expr_string(s, tok) or {
		raise(Exception{
			msg:    'Invalid expression'
			source: tok.source
			line:   tok.line + 1
			hint:   err.msg()
		})
		unsafe { nil }
	}
	emit_expr_into_eax(mut text, variables, e, tok)
}

pub fn emit_compare_pair(mut text []string, variables map[string]&Variable, lhs string, rhs string, tok &Token) {
	emit_value_into_eax(mut text, variables, lhs, tok)
	text << '\tpush rax\n'
	emit_value_into_eax(mut text, variables, rhs, tok)
	text << '\tmov ebx, eax\n'
	text << '\tpop rax\n'
	text << '\tcmp eax, ebx\n'
}
