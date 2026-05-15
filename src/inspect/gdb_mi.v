module main

import os
import time

pub struct GdbMi {
pub mut:
	proc &os.Process
	buf  string
}

pub fn new_gdb_mi() !&GdbMi {
	mut p := os.new_process('/usr/bin/gdb')
	p.set_args(['--interpreter=mi2', '-nx'])
	p.set_redirect_stdio()
	p.run()
	mut g := &GdbMi{
		proc: p
	}
	if !g.read_until_has('(gdb)', 10000) {
		return error('gdb startup timeout (no MI prompt)')
	}
	g.buf = ''
	g.send_data('-gdb-set debuginfod enabled off')!
	g.send_data('-gdb-set pagination off')!
	return g
}

pub fn (mut g GdbMi) close() {
	if !g.proc.is_alive() {
		return
	}
	// Prefer MI shutdown so GDB exits and closes pipes; avoids long hangs after the inferior dies.
	g.proc.stdin_write('-gdb-exit\n')
	deadline := time.ticks() + 800
	for time.ticks() < deadline {
		g.drain_stdio()
		if !g.proc.is_alive() {
			return
		}
		time.sleep(5 * time.millisecond)
	}
	if g.proc.is_alive() {
		g.proc.signal_kill()
	}
}

// drain_stdio reads GDB stdout into buf (MI stream) and discards stderr.
// GDB often logs to stderr; if we never read it, the pipe fills and GDB blocks — classic freeze on syscall/exit.
fn (mut g GdbMi) drain_stdio() {
	for {
		mut any := false
		for {
			chunk := g.proc.pipe_read(.stdout) or { break }
			g.buf += chunk
			any = true
		}
		for {
			_ := g.proc.pipe_read(.stderr) or { break }
			any = true
		}
		if !any {
			break
		}
	}
}

fn (mut g GdbMi) read_until_has(marker string, timeout_ms int) bool {
	deadline := time.ticks() + u64(timeout_ms)
	for time.ticks() < deadline {
		g.drain_stdio()
		if g.buf.contains(marker) {
			return true
		}
		time.sleep(1 * time.millisecond)
	}
	return false
}

fn (mut g GdbMi) read_until_done_or_error(timeout_ms int) bool {
	deadline := time.ticks() + u64(timeout_ms)
	for time.ticks() < deadline {
		g.drain_stdio()
		if g.buf.contains('^done') || g.buf.contains('^error') {
			return true
		}
		time.sleep(1 * time.millisecond)
	}
	return false
}

fn (mut g GdbMi) read_until_exec_complete(timeout_ms int) bool {
	deadline := time.ticks() + u64(timeout_ms)
	for time.ticks() < deadline {
		g.drain_stdio()
		if g.buf.contains('*stopped') || g.buf.contains('=thread-group-exited') {
			return true
		}
		time.sleep(1 * time.millisecond)
	}
	return false
}

pub fn (mut g GdbMi) send_data(cmd string) !string {
	g.buf = ''
	g.proc.stdin_write(cmd + '\n')
	if !g.read_until_done_or_error(8000) {
		return error('gdb cmd timeout: ${cmd}\n---\n${g.buf}')
	}
	if g.buf.contains('^error') {
		return error('gdb mi error for `${cmd}`:\n${g.buf}')
	}
	res := g.buf
	g.buf = ''
	return res
}

pub fn (mut g GdbMi) send_exec_async(cmd string) !string {
	g.buf = ''
	g.proc.stdin_write(cmd + '\n')
	if !g.read_until_exec_complete(20000) {
		return error('gdb exec timeout: ${cmd}\n---\n${g.buf}')
	}
	res := g.buf
	g.buf = ''
	return res
}

pub fn (mut g GdbMi) load_exe(path string) ! {
	q := mi_quote_path(os.real_path(path))
	g.send_data('-file-exec-and-symbols ${q}')!
}

pub fn (mut g GdbMi) break_at(symbol string) ! {
	g.send_data('-break-insert ${symbol}')!
}

pub fn (mut g GdbMi) exec_run() !string {
	return g.send_exec_async('-exec-run')
}

pub fn (mut g GdbMi) exec_step() !string {
	return g.send_exec_async('-exec-step')
}

pub fn (mut g GdbMi) exec_continue() !string {
	return g.send_exec_async('-exec-continue')
}

pub fn mi_quote_path(path string) string {
	rp := os.real_path(path)
	if rp.contains(' ') {
		return '"' + rp.replace('"', '\\"') + '"'
	}
	return rp
}

pub fn parse_last_stopped_line(gdb_out string) int {
	idx := gdb_out.last_index('*stopped') or { return -1 }
	rest := gdb_out[idx..]
	li := rest.index('line="') or { return -1 }
	start := li + 6
	mut end := start
	for end < rest.len {
		c := rest[end]
		if c < `0` || c > `9` {
			break
		}
		end++
	}
	if end == start {
		return -1
	}
	return rest[start..end].int()
}

pub fn stopped_exited(gdb_out string) bool {
	// Some stops (e.g. stepping the exit syscall) surface group exit in MI without a tidy *stopped first.
	if gdb_out.contains('=thread-group-exited') {
		return true
	}
	idx := gdb_out.last_index('*stopped') or { return false }
	rest := gdb_out[idx..]
	// Modern GDB uses exited-normally / exited-signalled, not reason="exited".
	return rest.contains('reason="exited-normally"')
		|| rest.contains('reason="exited-signalled"')
		|| rest.contains('reason="exited"')
}

pub fn (mut g GdbMi) eval_reg(name string) string {
	resp := g.send_data('-data-evaluate-expression $' + name) or { return '?' }
	return mi_parse_value(resp)
}

fn mi_parse_value(resp string) string {
	vi := resp.index('value="') or { return '?' }
	start := vi + 7
	mut end := start
	for end < resp.len && resp[end] != `"` {
		end++
	}
	if end == start {
		return '?'
	}
	return resp[start..end]
}

pub fn (mut g GdbMi) regs_line() string {
	mut parts := []string{}
	for reg in ['rax', 'rdi', 'rsp', 'rip'] {
		parts << '${reg}=${g.eval_reg(reg)}'
	}
	return parts.join('  ')
}
