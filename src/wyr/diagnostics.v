module wyr

pub struct Exception {
pub:
	msg    string
	source string
	line   int
	hint   string
	@type  string = 'e'
}

pub struct Warning {
pub:
	msg    string
	source string
	line   int
	hint   string
	@type  string = 'w'
}

pub type Diag = Exception | Warning

// DiagSink adapts how diagnostics are delivered (console, tests, LSP, etc.).
pub interface DiagSink {
mut:
	emit(d Diag)
}

pub struct ConsoleDiagSink {}

pub fn (mut _ ConsoleDiagSink) emit(d Diag) {
	match d {
		Exception {
			println('\033[31;1;4m[Exception] at ${d.line} => ${d.msg}\033[0m')
			println('\033[32;49;3m${d.line}\033[0m\033[37;49;1m\t${d.source}\033[0m')
			if d.hint.len != 0 {
				println('\033[36;49;3m${d.hint}\033[0m')
			}
		}
		Warning {
			println('\033[33;4;1m[Warning] at ${d.line} => ${d.msg}\033[0m')
			println('\033[32;49;3m${d.line}\033[0m\033[37;49;1m\t${d.source}\033[0m')
			if d.hint.len != 0 {
				println('\033[36;49;3m${d.hint}\033[0m')
			}
		}
	}
}

pub fn raise(d Diag) {
	mut sink := ConsoleDiagSink{}
	sink.emit(d)
	match d {
		Exception { exit(1) }
		Warning {}
	}
}
