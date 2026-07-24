module wyr

fn test_normalize_source_lines_trims_spaces_and_indent() {
	code := ['  hello  ', '\t\tindented']
	out := normalize_source_lines(code)
	assert out.len == 2
	assert out[0] == 'hello'
	assert out[1] == 'indented'
}

fn test_normalize_source_lines_empty_roundtrip() {
	assert normalize_source_lines([]).len == 0
}
