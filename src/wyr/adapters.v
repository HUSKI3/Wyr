module wyr

import os

// SourceLoader adapts where .wyr source text comes from (filesystem, memory, etc.).
pub interface SourceLoader {
mut:
	read_lines(path string) ![]string
}

pub struct OsSourceLoader {}

pub fn (mut _ OsSourceLoader) read_lines(path string) ![]string {
	return os.read_lines(path)
}

// ToolchainChecker adapts how external tool dependencies are verified.
pub interface ToolchainChecker {
mut:
	require_on_path(tool string)
}

pub struct OsToolchainChecker {}

pub fn (mut _ OsToolchainChecker) require_on_path(tool string) {
	if os.exists_in_system_path(tool) {
		return
	}
	raise(Exception{
		msg:    'Missing dependency ${tool}'
		source: tool
		line:   0
		hint:   'Refer to the guidebook for language documentation'
	})
}

// AsmSink adapts where generated assembly is written.
pub interface AsmSink {
mut:
	write_bytes(b []u8)
	close()
}

pub struct FileAsmSink {
mut:
	file os.File
}

pub fn new_file_asm_sink(path string) !FileAsmSink {
	f := os.create(path) or { return error('cannot create ${path}') }
	return FileAsmSink{
		file: f
	}
}

pub fn (mut s FileAsmSink) write_bytes(b []u8) {
	s.file.write(b) or { panic(err) }
}

pub fn (mut s FileAsmSink) close() {
	s.file.close()
}
