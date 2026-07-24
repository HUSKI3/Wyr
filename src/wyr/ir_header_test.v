module wyr

fn test_strip_ir_version_header_default_when_absent() {
	h, lines := strip_ir_version_header(['x:i32 0'])
	assert h.version == default_ir_version
	assert lines.len == 1
	assert lines[0] == 'x:i32 0'
}

fn test_strip_ir_version_header_strips_wyr_line() {
	h, lines := strip_ir_version_header(['wyr 1', 'x:i32 0'])
	assert h.version == 1
	assert lines.len == 1
	assert lines[0] == 'x:i32 0'
}
