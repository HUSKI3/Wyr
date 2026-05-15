module main

import flag
import os
import wyr

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('wyr')
	fp.version('0.0.13')
	fp.description('Simple language to abstract nasm')
	fp.skip_executable()
	source := fp.string('source', `s`, '', 'specify .wyr source')
	debug := fp.bool('debug', `d`, false, 'enable debugging')
	fp.finalize() or {
		eprintln(err.msg())
		exit(1)
	}
	if source.len == 0 {
		println('Source not provided')
		exit(1)
	}
	params := wyr.CompileParams{
		source_path:  source
		debug:        debug
		asm_out_path: 'out.asm'
	}
	mut loader := wyr.OsSourceLoader{}
	mut deps := wyr.OsToolchainChecker{}
	mut sink := wyr.new_file_asm_sink(params.asm_out_path) or {
		eprintln('cannot open output: ${err.msg()}')
		exit(1)
	}
	wyr.compile_wyr(params, mut loader, mut deps, mut sink)
}
