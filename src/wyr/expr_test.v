module wyr

fn test_parse_expr_call_no_args() {
	tok := &Token{}
	e := parse_expr_string('@foo()', tok) or { panic(err.msg()) }
	assert e.kind == .call
	assert e.val == 'foo'
	assert e.call_args.len == 0
}

fn test_parse_expr_call_one_arg_literal() {
	tok := &Token{}
	e := parse_expr_string('@twice(3)', tok) or { panic(err.msg()) }
	assert e.kind == .call
	assert e.val == 'twice'
	assert e.call_args.len == 1
	assert e.call_args[0].kind == .leaf
	assert e.call_args[0].val == '3'
}

fn test_parse_expr_paren_and_plus() {
	tok := &Token{}
	e := parse_expr_string('(1 + 2) * 3', tok) or { panic(err.msg()) }
	assert e.kind == .mul
	assert e.right.kind == .leaf
	assert e.right.val == '3'
}
