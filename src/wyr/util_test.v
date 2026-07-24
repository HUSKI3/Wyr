module wyr

fn test_is_numeric_accepts_decimal_integers() {
	assert is_numeric('0')
	assert is_numeric('42')
	assert is_numeric('-1')
}

fn test_is_numeric_rejects_non_numbers() {
	assert is_numeric('') == false
	assert is_numeric('abc') == false
	assert is_numeric('12a') == false
}

fn test_wyr_type_from_keyword_covers_decl_types() {
	assert wyr_type_from_keyword('i32')! == Types.i32
	assert wyr_type_from_keyword('i64')! == Types.i64
	assert wyr_type_from_keyword('string')! == Types.str
	assert wyr_type_from_keyword('buffer')! == Types.buffer
	assert wyr_type_from_keyword('int')! == Types.integer
}

fn test_wyr_type_from_keyword_rejects_unknown() {
	wyr_type_from_keyword('notatype') or {
		assert true
		return
	}
	assert false
}

fn test_wyr_type_from_return_keyword_void() {
	assert wyr_type_from_return_keyword('void')! == Types.@none
}

fn test_wyr_type_from_return_keyword_matches_decl_aliases() {
	assert wyr_type_from_return_keyword('i32')! == Types.i32
}
