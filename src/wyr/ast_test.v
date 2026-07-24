module wyr

fn test_operands_inverted_maps_equality_operators() {
	assert operands_inverted['=='] == 'jne'
	assert operands_inverted['!='] == 'je'
	assert operands_inverted['<'] == 'jge'
	assert operands_inverted['>'] == 'jle'
	assert operands_inverted['<='] == 'jg'
	assert operands_inverted['>='] == 'jl'
}

fn test_operands_direct_maps_equality_operators() {
	assert operands_direct['=='] == 'je'
	assert operands_direct['!='] == 'jne'
	assert operands_direct['<'] == 'jl'
	assert operands_direct['>'] == 'jg'
	assert operands_direct['<='] == 'jle'
	assert operands_direct['>='] == 'jge'
}

fn test_int_compare_types_includes_expected_variants() {
	assert int_compare_types.len == 5
	assert Types.i32 in int_compare_types
	assert Types.str !in int_compare_types
}
