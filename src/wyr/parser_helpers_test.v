module wyr

fn test_asm_scalar_kw_for_int_family() {
	assert asm_scalar_kw(Types.i8) == 'db'
	assert asm_scalar_kw(Types.i16) == 'dw'
	assert asm_scalar_kw(Types.i32) == 'dd'
	assert asm_scalar_kw(Types.i64) == 'dq'
	assert asm_scalar_kw(Types.integer) == 'dd'
}

fn test_is_scalar_int_type() {
	assert is_scalar_int_type(Types.i8)
	assert is_scalar_int_type(Types.integer)
	assert is_scalar_int_type(Types.str) == false
	assert is_scalar_int_type(Types.buffer) == false
}

fn test_declare_scalar_int_writes_data_section_when_mutable() {
	mut bss := []string{}
	mut data := []string{}
	declare_scalar_int(mut bss, mut data, 'x', '7', Types.i32, false)
	assert bss.len == 0
	assert data.len == 1
	assert data[0] == '\tx: dd 7\n'
}

fn test_declare_scalar_int_writes_equ_when_const() {
	mut bss := []string{}
	mut data := []string{}
	declare_scalar_int(mut bss, mut data, 'k', '10', Types.i8, true)
	assert bss.len == 1
	assert bss[0] == '\tk equ 10\n'
	assert data.len == 0
}
