module wyr

fn test_lextokens_skips_empty_and_comments() {
	toks := lextokens(['', '// comment'], false, false, 0)
	assert toks.len == 0
}

fn test_lextokens_variable_declaration() {
	toks := lextokens(['count:i32 0'], false, false, 0)
	assert toks.len == 1
	t := toks[0]
	assert t.@type == TokenTypes.variable
	assert t.id == 'count'
	assert t.valtype == Types.i32
	assert t.value == '0'
}

fn test_lextokens_dot_call() {
	toks := lextokens(['.output buf'], false, false, 0)
	assert toks.len == 1
	t := toks[0]
	assert t.@type == TokenTypes.function
	assert t.id == '.output'
	assert t.value == 'buf'
}

fn test_lextokens_assign_rhs() {
	toks := lextokens(['x = y + 1'], false, false, 0)
	assert toks.len == 1
	t := toks[0]
	assert t.@type == TokenTypes.assign
	assert t.id == 'x'
	assert t.value == 'y + 1'
}

fn test_lextokens_const_suffix() {
	toks := lextokens(['n:i32 42 const'], false, false, 0)
	assert toks.len == 1
	t := toks[0]
	assert t.@type == TokenTypes.variable
	assert t.id == 'n'
	assert t.value == '42'
	assert t.flag == Flags.@const
}

fn test_lextokens_user_call_with_args() {
	toks := lextokens(['@foo( a , b )'], false, false, 0)
	assert toks.len == 1
	t := toks[0]
	assert t.@type == TokenTypes.userfunction
	assert t.id == 'foo'
	assert t.value == 'a , b'
}
