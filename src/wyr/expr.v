module wyr

pub enum ExprKind {
	leaf
	neg
	add
	sub
	mul
	div
	mod_
	call
}

pub struct ExprAst {
pub:
	kind      ExprKind
	val       string
	left      &ExprAst = unsafe { nil }
	right     &ExprAst = unsafe { nil }
	call_args []&ExprAst
}

struct ExprParser {
	s   string
mut:
	pos int
}

fn (mut p ExprParser) skip_ws() {
	for p.pos < p.s.len && p.s[p.pos] in [` `, `\t`] {
		p.pos++
	}
}

fn (mut p ExprParser) peek() u8 {
	p.skip_ws()
	if p.pos >= p.s.len {
		return 0
	}
	return p.s[p.pos]
}

fn (mut p ExprParser) consume_ch() u8 {
	p.skip_ws()
	if p.pos >= p.s.len {
		return 0
	}
	c := p.s[p.pos]
	p.pos++
	return c
}

fn (mut p ExprParser) parse_number_or_name() !&ExprAst {
	p.skip_ws()
	if p.pos >= p.s.len {
		return error('unexpected end of expression')
	}
	mut start := p.pos
	for p.pos < p.s.len {
		c := p.s[p.pos]
		if c.is_digit() || c == `_` || (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`)
			|| (c == `-` && p.pos == start) {
			p.pos++
		} else {
			break
		}
	}
	if start == p.pos {
		return error('expected number or name')
	}
	atom := p.s[start..p.pos]
	if is_numeric(atom) || (atom.len > 1 && atom[0] == `-` && is_numeric(atom[1..])) {
		return &ExprAst{
			kind:      .leaf
			val:       atom
			call_args: []&ExprAst{}
		}
	}
	return &ExprAst{
		kind:      .leaf
		val:       atom
		call_args: []&ExprAst{}
	}
}

fn (mut p ExprParser) parse_call_ident() !string {
	p.skip_ws()
	if p.pos >= p.s.len {
		return error('expected function name')
	}
	mut start := p.pos
	for p.pos < p.s.len {
		c := p.s[p.pos]
		if c.is_digit() || c == `_` || (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) {
			p.pos++
		} else {
			break
		}
	}
	if start == p.pos {
		return error('expected function name')
	}
	return p.s[start..p.pos]
}

fn (mut p ExprParser) parse_atom() !&ExprAst {
	p.skip_ws()
	if p.peek() == `@` {
		p.consume_ch()
		callee := p.parse_call_ident()!
		if p.consume_ch() != `(` {
			return error('expected ( after @name')
		}
		mut cargs := []&ExprAst{}
		p.skip_ws()
		if p.peek() != `)` {
			for {
				cargs << p.parse_expr()!
				p.skip_ws()
				if p.peek() == `)` {
					break
				}
				if p.consume_ch() != `,` {
					return error('expected , or ) in argument list')
				}
			}
		}
		if p.consume_ch() != `)` {
			return error('expected )')
		}
		return &ExprAst{
			kind:      .call
			val:       callee
			call_args: cargs
		}
	}
	if p.peek() == `(` {
		p.consume_ch()
		e := p.parse_expr()!
		if p.consume_ch() != `)` {
			return error('expected )')
		}
		return e
	}
	if p.peek() == `-` {
		p.consume_ch()
		inner := p.parse_atom()!
		return &ExprAst{
			kind:      .neg
			left:      inner
			val:       ''
			right:     unsafe { nil }
			call_args: []&ExprAst{}
		}
	}
	return p.parse_number_or_name()!
}

fn (mut p ExprParser) parse_mul() !&ExprAst {
	mut n := p.parse_atom()!
	for {
		p.skip_ws()
		if p.pos >= p.s.len {
			break
		}
		op := p.s[p.pos]
		if op !in [`*`, `/`, `%`] {
			break
		}
		p.pos++
		r := p.parse_atom()!
		kind := match op {
			`*` { ExprKind.mul }
			`/` { ExprKind.div }
			else { ExprKind.mod_ }
		}
		n = &ExprAst{
			kind:      kind
			left:      n
			right:     r
			call_args: []&ExprAst{}
		}
	}
	return n
}

fn (mut p ExprParser) parse_expr() !&ExprAst {
	mut n := p.parse_mul()!
	for {
		p.skip_ws()
		if p.pos >= p.s.len {
			break
		}
		op := p.s[p.pos]
		if op !in [`+`, `-`] {
			break
		}
		p.pos++
		r := p.parse_mul()!
		kind := if op == `+` { ExprKind.add } else { ExprKind.sub }
		n = &ExprAst{
			kind:      kind
			left:      n
			right:     r
			call_args: []&ExprAst{}
		}
	}
	return n
}

pub fn parse_expr_string(s string, _tok &Token) !&ExprAst {
	mut p := ExprParser{
		s:   s.trim(' ')
		pos: 0
	}
	e := p.parse_expr()!
	p.skip_ws()
	if p.pos != p.s.len {
		return error('trailing garbage in expression')
	}
	return e
}

pub fn emit_expr_into_eax(mut text []string, variables map[string]&Variable, ast &ExprAst, tok &Token) {
	match ast.kind {
		.leaf {
			if is_numeric(ast.val) || (ast.val.len > 1 && ast.val[0] == `-` && is_numeric(ast.val[1..])) {
				text << '\tmov eax, ${ast.val}\n'
			} else {
				require_int_for_math(ast.val, variables, tok)
				v := variables[ast.val]
				emit_load_i32_like(mut text, v, ast.val)
			}
		}
		.call {
			mut idx := 0
			for a in ast.call_args {
				if idx >= abi_arg_regs.len {
					raise(Exception{
						msg:    'Too many function arguments'
						source: tok.source
						line:   tok.line + 1
						hint:   'At most ${abi_arg_regs.len} scalar arguments in one call (SysV AMD64)'
					})
				}
				emit_expr_into_eax(mut text, variables, a, tok)
				reg := abi_arg_regs[idx]
				text << '\tmov ${reg}, rax\n'
				idx++
			}
			text << '\tcall ${ast.val}\n'
		}
		.neg {
			emit_expr_into_eax(mut text, variables, ast.left, tok)
			text << '\tneg eax\n'
		}
		.add {
			emit_expr_into_eax(mut text, variables, ast.left, tok)
			text << '\tpush rax\n'
			emit_expr_into_eax(mut text, variables, ast.right, tok)
			text << '\tmov ebx, eax\n'
			text << '\tpop rax\n'
			text << '\tadd eax, ebx\n'
		}
		.sub {
			emit_expr_into_eax(mut text, variables, ast.left, tok)
			text << '\tpush rax\n'
			emit_expr_into_eax(mut text, variables, ast.right, tok)
			text << '\tmov ebx, eax\n'
			text << '\tpop rax\n'
			text << '\tsub eax, ebx\n'
		}
		.mul {
			emit_expr_into_eax(mut text, variables, ast.left, tok)
			text << '\tpush rax\n'
			emit_expr_into_eax(mut text, variables, ast.right, tok)
			text << '\tmov ebx, eax\n'
			text << '\tpop rax\n'
			text << '\timul eax, ebx\n'
		}
		.div {
			emit_expr_into_eax(mut text, variables, ast.left, tok)
			text << '\tpush rax\n'
			emit_expr_into_eax(mut text, variables, ast.right, tok)
			text << '\tmov ebx, eax\n'
			text << '\tpop rax\n'
			text << '\tcdq\n'
			text << '\tidiv ebx\n'
		}
		.mod_ {
			emit_expr_into_eax(mut text, variables, ast.left, tok)
			text << '\tpush rax\n'
			emit_expr_into_eax(mut text, variables, ast.right, tok)
			text << '\tmov ebx, eax\n'
			text << '\tpop rax\n'
			text << '\tcdq\n'
			text << '\tidiv ebx\n'
			text << '\tmov eax, edx\n'
		}
	}
}

pub fn emit_load_i32_like(mut text []string, v &Variable, sym string) {
	if v.param_reg != '' {
		match v.@type {
			.i8 {
				text << '\tmovsx eax, ${abi_reg_low8(v.param_reg)}\n'
			}
			.i16 {
				text << '\tmovsx eax, ${abi_reg_low16(v.param_reg)}\n'
			}
			else {
				text << '\tmov eax, ${abi_reg_low32(v.param_reg)}\n'
			}
		}
		return
	}
	match v.@type {
		.i8 {
			text << '\tmovsx eax, byte [${sym}]\n'
		}
		.i16 {
			text << '\tmovsx eax, word [${sym}]\n'
		}
		else {
			text << '\tmov eax, [${sym}]\n'
		}
	}
}

pub fn emit_store_eax_to_var(mut text []string, v &Variable, sym string) {
	if v.param_reg != '' {
		match v.@type {
			.i8 {
				text << '\tmov ${abi_reg_low8(v.param_reg)}, al\n'
			}
			.i16 {
				text << '\tmov ${abi_reg_low16(v.param_reg)}, ax\n'
			}
			else {
				text << '\tmov ${abi_reg_low32(v.param_reg)}, eax\n'
			}
		}
		return
	}
	match v.@type {
		.i8 {
			text << '\tmov byte [${sym}], al\n'
		}
		.i16 {
			text << '\tmov word [${sym}], ax\n'
		}
		else {
			text << '\tmov dword [${sym}], eax\n'
		}
	}
}
