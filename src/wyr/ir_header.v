module wyr

import strconv

pub struct IrModuleHeader {
pub:
	version int
}

pub const default_ir_version = 1

// Strips optional leading `wyr N` line from already-trimmed lines; returns header and remaining lines.
pub fn strip_ir_version_header(lines []string) (IrModuleHeader, []string) {
	if lines.len == 0 {
		return IrModuleHeader{ version: default_ir_version }, lines
	}
	first := lines[0].trim(' ')
	if first.len < 3 || first[0..3] != 'wyr' {
		return IrModuleHeader{ version: default_ir_version }, lines
	}
	rest := first[3..].trim(' ')
	if rest.len == 0 {
		raise(Exception{
			msg:    'Invalid wyr version line'
			source: lines[0]
			line:   1
			hint:   'Use: wyr 1'
		})
	}
	v := strconv.parse_int(rest, 10, 32) or {
		raise(Exception{
			msg:    'Invalid wyr version number'
			source: lines[0]
			line:   1
			hint:   'Use: wyr 1'
		})
		i64(0)
	}
	if v != default_ir_version {
		raise(Exception{
			msg:    'Unsupported Wyr IR version ${v}'
			source: lines[0]
			line:   1
			hint:   'This compiler supports wyr ${default_ir_version} only'
		})
	}
	return IrModuleHeader{ version: int(v) }, lines[1..]
}
