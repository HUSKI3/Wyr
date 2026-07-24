module wyr

pub fn emit_ret_stmt(mut text []string, ctx ParseCtx, variables map[string]&Variable, value_raw string, tok &Token) {
	if ctx.fn_exit_label.len == 0 {
		raise(Exception{
			msg:    '.ret outside of function'
			source: tok.source
			line:   tok.line + 1
			hint:   'Return is only valid inside fn ... @name () { ... }'
		})
	}
	val := value_raw.trim(' ')
	if ctx.fn_return_type == Types.@none {
		if val.len > 0 {
			raise(Exception{
				msg:    'void function cannot return a value'
				source: tok.source
				line:   tok.line + 1
				hint:   'Use `.ret` with no expression'
			})
		}
		text << '\tjmp ${ctx.fn_exit_label}\n'
		return
	}
	if val.len == 0 {
		raise(Exception{
			msg:    'missing return value'
			source: tok.source
			line:   tok.line + 1
			hint:   'Use `.ret <expression>`'
		})
	}
	e := parse_expr_string(val, tok) or {
		raise(Exception{
			msg:    'Invalid return expression'
			source: tok.source
			line:   tok.line + 1
			hint:   err.msg()
		})
		unsafe { nil }
	}
	emit_expr_into_eax(mut text, variables, e, tok)
	text << '\tjmp ${ctx.fn_exit_label}\n'
}

pub fn emit_user_call(mut text []string, variables map[string]&Variable, callee string, arg_csv string, tok &Token) {
	args := if arg_csv.len == 0 {
		[]string{}
	} else {
		arg_csv.split(',').map(fn (s string) string {
			return s.trim(' ')
		})
	}
	mut idx := 0
	for a in args {
		if a.len == 0 {
			continue
		}
		if idx >= abi_arg_regs.len {
			raise(Exception{
				msg:    'Too many function arguments'
				source: tok.source
				line:   tok.line + 1
				hint:   'At most ${abi_arg_regs.len} scalar arguments are supported (SysV AMD64)'
			})
		}
		emit_value_into_eax(mut text, variables, a, tok)
		reg := abi_arg_regs[idx]
		text << '\tmov ${reg}, rax\n'
		idx++
	}
	text << '\tcall ${callee}\n'
}
