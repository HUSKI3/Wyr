module wyr

fn test_split_comparison_leq() {
	lhs, op, rhs := split_comparison_condition('a <= b')!
	assert lhs == 'a'
	assert op == '<='
	assert rhs == 'b'
}

fn test_split_comparison_geq() {
	lhs, op, rhs := split_comparison_condition('(x+1) >= y')!
	assert op == '>='
}

fn test_split_longest_op_first() {
	lhs, op, rhs := split_comparison_condition('a <= 3')!
	assert op == '<='
	assert rhs == '3'
}
