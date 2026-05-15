module main

import flag
import os
import term.ui as tui

struct App {
mut:
	tui_ctx &tui.Context = unsafe { nil }
	// Paths
	source_path string
	wyr_bin     string
	work_dir    string
	asm_path    string
	exe_path    string
	// Source text
	wyr_lines []string
	asm_lines []string
	// Scroll (0-based line at top of pane)
	wyr_scroll int
	asm_scroll int
	// GDB
	gdb          ?&GdbMi
	debug_active bool
	asm_line     int = -1 // 1-based NASM line from GDB, or -1
	follow_pc    bool = true
	regs_text    string
	status_msg   string
	run_log      string
	last_footer  string
}

fn clip_line(s string, max_w int) string {
	if max_w <= 0 {
		return ''
	}
	if s.len <= max_w {
		return s
	}
	return s[..max_w]
}

fn (mut app App) ensure_paths() {
	app.asm_path = os.join_path(app.work_dir, 'out.asm')
	app.exe_path = os.join_path(app.work_dir, 'wyr-inspect-bin')
}

fn (mut app App) reload_wyr() {
	app.wyr_lines = os.read_lines(app.source_path) or { ['(cannot read source)'] }
}

fn (mut app App) reload_asm() {
	app.asm_lines = os.read_lines(app.asm_path) or { ['(build to generate NASM)'] }
}

fn (mut app App) build() {
	app.ensure_paths()
	app.status_msg = 'compiling...'
	wcmd := os.quoted_path(app.wyr_bin) + ' -s ' + os.quoted_path(app.source_path)
	w := os.execute('cd ${os.quoted_path(app.work_dir)} && ${wcmd}')
	if w.exit_code != 0 {
		app.status_msg = 'wyr failed: ${w.output}'
		return
	}
	o_file := os.join_path(app.work_dir, 'wyr-inspect.o')
	n := os.execute('nasm -felf64 -g -F dwarf -o ${os.quoted_path(o_file)} ${os.quoted_path(app.asm_path)}')
	if n.exit_code != 0 {
		app.status_msg = 'nasm failed: ${n.output}'
		return
	}
	l := os.execute('ld -o ${os.quoted_path(app.exe_path)} ${os.quoted_path(o_file)}')
	if l.exit_code != 0 {
		app.status_msg = 'ld failed: ${l.output}'
		return
	}
	app.reload_asm()
	app.status_msg = 'build ok → ${app.exe_path}'
}

fn (mut app App) run_plain() {
	app.ensure_paths()
	if !os.exists(app.exe_path) {
		app.status_msg = 'no binary; press b to build'
		return
	}
	r := os.execute(app.exe_path)
	app.run_log = r.output
	app.status_msg = 'exit ${r.exit_code}'
}

fn (mut app App) gdb_stop() {
	if mut g := app.gdb {
		g.close()
	}
	app.gdb = none
	app.debug_active = false
	app.asm_line = -1
	app.regs_text = ''
}

fn (mut app App) gdb_start() {
	app.gdb_stop()
	app.ensure_paths()
	if !os.exists(app.exe_path) {
		app.status_msg = 'no binary; press b first'
		return
	}
	app.gdb = new_gdb_mi() or {
		app.status_msg = 'gdb: ${err.msg()}'
		return
	}
	mut g := app.gdb or { return }
	g.load_exe(app.exe_path) or {
		app.status_msg = 'load: ${err.msg()}'
		app.gdb_stop()
		return
	}
	g.break_at('_start') or {
		app.status_msg = 'break: ${err.msg()}'
		app.gdb_stop()
		return
	}
	out := g.exec_run() or {
		app.status_msg = 'run: ${err.msg()}'
		app.gdb_stop()
		return
	}
	if stopped_exited(out) {
		app.status_msg = 'program exited immediately'
		app.gdb_stop()
		return
	}
	app.debug_active = true
	app.asm_line = parse_last_stopped_line(out)
	app.refresh_regs()
	app.sync_asm_scroll()
	app.status_msg = 'gdb at _start (asm line ${app.asm_line})'
}

fn (mut app App) gdb_step() {
	if mut g := app.gdb {
		out := g.exec_step() or {
			app.status_msg = 'step: ${err.msg()}'
			return
		}
		if stopped_exited(out) {
			app.status_msg = 'inferior exited'
			app.gdb_stop()
			return
		}
		app.asm_line = parse_last_stopped_line(out)
		app.refresh_regs()
		app.sync_asm_scroll()
	}
}

fn (mut app App) gdb_continue() {
	if mut g := app.gdb {
		out := g.exec_continue() or {
			app.status_msg = 'continue: ${err.msg()}'
			return
		}
		if stopped_exited(out) {
			app.status_msg = 'inferior exited'
			app.gdb_stop()
			return
		}
		app.asm_line = parse_last_stopped_line(out)
		app.refresh_regs()
		app.sync_asm_scroll()
	}
}

fn (mut app App) refresh_regs() {
	if mut g := app.gdb {
		app.regs_text = g.regs_line()
	}
}

fn (mut app App) sync_asm_scroll() {
	if !app.follow_pc || app.asm_line < 1 {
		return
	}
	_, content_h := app.content_geom()
	if content_h < 2 {
		return
	}
	target := app.asm_line - 1
	half := content_h / 2
	mut want := target - half
	if want < 0 {
		want = 0
	}
	app.asm_scroll = want
}

fn (app App) content_geom() (int, int) {
	h := app.tui_ctx.window_height
	w := app.tui_ctx.window_width
	header := 3
	footer := 6
	ch := h - header - footer
	if ch < 3 {
		return w, 3
	}
	return w, ch
}

fn (mut app App) draw() {
	mut ctx := app.tui_ctx
	ctx.clear()
	ctx.reset()
	w := ctx.window_width
	h := ctx.window_height
	ctx.set_color(tui.Color{80, 200, 120})
	ctx.draw_text(1, 1, 'wyr-inspect — ${app.source_path}')
	ctx.reset()
	ctx.draw_text(1, 2, clip_line(app.status_msg, w - 2))
	ctx.horizontal_separator(3)
	_, content_h := app.content_geom()
	mid := w / 2
	mut left_w := mid - 2
	right_x := mid + 2
	mut right_w := w - right_x - 1
	if left_w < 8 {
		left_w = 8
	}
	if right_w < 8 {
		right_w = 8
	}
	ctx.bold()
	ctx.draw_text(1, 4, 'Wyr source')
	ctx.draw_text(right_x, 4, 'NASM (debug)')
	ctx.reset()
	mut row := 5
	for row < 5 + content_h && row < h - 5 {
		wi := row - 5 + app.wyr_scroll
		ai := row - 5 + app.asm_scroll
		mut left := ''
		if wi >= 0 && wi < app.wyr_lines.len {
			left = '${wi + 1:4}| ${app.wyr_lines[wi]}'
		}
		mut right := ''
		if ai >= 0 && ai < app.asm_lines.len {
			prefix := if app.asm_line == ai + 1 { '>' } else { ' ' }
			right = '${prefix}${ai + 1:4}| ${app.asm_lines[ai]}'
		}
		ctx.draw_text(1, row, clip_line(left, left_w))
		if app.asm_line == ai + 1 && ai >= 0 {
			ctx.set_color(tui.Color{120, 180, 255})
		}
		ctx.draw_text(right_x, row, clip_line(right, right_w))
		ctx.reset()
		row++
	}
	foot_y := h - 5
	ctx.horizontal_separator(foot_y - 1)
	ctx.set_color(tui.Color{200, 180, 100})
	ctx.draw_text(1, foot_y, clip_line(app.regs_text, w - 2))
	ctx.reset()
	ctx.draw_text(1, foot_y + 1, clip_line(app.run_log, w - 2))
	ctx.draw_text(1, foot_y + 2, clip_line(app.last_footer, w - 2))
	ctx.set_color(tui.Color{140, 140, 140})
	ctx.draw_text(1, foot_y + 3, 'b build  g gdb@_start  s step  c continue  r run  f follow-PC  k/j wyr  d/u asm  q quit')
	ctx.reset()
	ctx.flush()
}

fn event(e &tui.Event, mut app App) {
	if e.typ != .key_down {
		return
	}
	match e.code {
		.escape, .q {
			app.gdb_stop()
			println('\nwyr-inspect exit.')
			exit(0)
		}
		.b {
			app.build()
		}
		.g {
			app.gdb_start()
		}
		.s {
			app.gdb_step()
		}
		.c {
			app.gdb_continue()
		}
		.r {
			app.run_plain()
		}
		.f {
			app.follow_pc = !app.follow_pc
			app.status_msg = if app.follow_pc { 'follow PC on' } else { 'follow PC off' }
		}
		.k, .up {
			if app.wyr_scroll > 0 {
				app.wyr_scroll--
			}
		}
		.j, .down {
			app.wyr_scroll++
		}
		.d {
			if app.asm_scroll > 0 {
				app.asm_scroll--
			}
		}
		.u {
			app.asm_scroll++
		}
		else {}
	}
	app.draw()
}

type EventFn = fn (&tui.Event, voidptr)

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('wyr-inspect')
	fp.description('TUI inspector / GDB front-end for Wyr → NASM → ELF')
	fp.skip_executable()
	source := fp.string('source', `s`, '', 'path to .wyr file')
	wyr_bin := fp.string('wyr', `w`, './wyr', 'wyr compiler executable')
	work := fp.string('work', `o`, '.', 'working directory (out.asm, binary)')
	fp.finalize() or {
		eprintln(err.msg())
		exit(1)
	}
	if source.len == 0 {
		eprintln('usage: wyr-inspect -s examples/name.wyr')
		exit(1)
	}
	mut app := &App{
		source_path: os.real_path(source)
		wyr_bin:     os.real_path(wyr_bin)
		work_dir:    os.real_path(work)
	}
	app.ensure_paths()
	app.reload_wyr()
	app.reload_asm()
	app.last_footer = 'ELF debug: nasm -g -F dwarf; MI2 gdb. ASM line highlight uses DWARF line table.'
	mut tctx := tui.init(
		user_data:            app
		frame_fn:             fn (ptr voidptr) {
			mut a := unsafe { &App(ptr) }
			a.draw()
		}
		event_fn:             EventFn(event)
		window_title:         'wyr-inspect'
		hide_cursor:          true
		capture_events:       true
		frame_rate:           12
		use_alternate_buffer: true
	)
	app.tui_ctx = tctx
	app.status_msg = 'b build  g gdb — need ./wyr and gdb in PATH'
	app.draw()
	tctx.run()!
}
