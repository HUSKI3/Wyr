module wyr

pub fn normalize_source_lines(code []string) []string {
	mut clean := []string{}
	for line in code {
		txt := line.trim(' ').trim_indent()
		clean << txt
	}
	return clean
}

pub struct CompileParams {
pub:
	source_path  string
	asm_out_path string = 'out.asm'
	debug        bool
}

pub fn compile_wyr(params CompileParams, mut loader OsSourceLoader, mut deps OsToolchainChecker, mut out FileAsmSink) {
	if params.source_path.len == 0 {
		println('Source not provided')
		exit(1)
	}
	deps.require_on_path('nasm')
	if params.debug {
		println('[Check] nasm is present')
	}
	deps.require_on_path('ld')
	if params.debug {
		println('[Check] ld is present')
	}
	if params.debug {
		println('Loading -> ${params.source_path}')
	}
	code := loader.read_lines(params.source_path) or { panic(err) }
	clean_code := normalize_source_lines(code)
	header, ir_lines := strip_ir_version_header(clean_code)
	tokens := lextokens(ir_lines, false, params.debug, 0)
	validate_module(tokens, header)
	_ := bundle_ir(header, tokens)
	if params.debug {
		println('Finished constructing tokens')
	}
	mut builtin := default_builtin_syscalls()
	mut functions := map[string]&Function{}
	mut variables := map[string]&Variable{}
	mut buffers := map[string][]string{}
	mut bss := ['section .bss\n']
	mut data := ['section .data\n']
	mut text := [
		'section .text\n',
		'\tglobal _start\n',
		'\t_start:\n',
	]
	mut tailtext := []string{}
	mut ctx := root_parse_ctx()
	parse_tokens(tokens, mut bss, mut data, mut text, mut tailtext, mut variables, mut
		functions, mut buffers, builtin, mut ctx)
	text << 'wyr_exit:
    mov rax, 60
    xor rdi, rdi
    syscall'
	if params.debug {
		println('Finished asm')
	}
	for elem in bss {
		out.write_bytes(elem.bytes())
	}
	for elem in data {
		out.write_bytes(elem.bytes())
	}
	for elem in text {
		out.write_bytes(elem.bytes())
	}
	for elem in tailtext {
		out.write_bytes(elem.bytes())
	}
	out.close()
	println('Built!')
}
