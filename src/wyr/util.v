module wyr

import strconv

pub fn is_numeric(s string) bool {
	if s.len == 0 {
		return false
	}
	_ := strconv.parse_int(s, 10, 32) or { return false }
	return true
}

pub fn wyr_type_from_keyword(key string) !Types {
	return match key {
		'string' {
			Types.str
		}
		'i8' {
			Types.i8
		}
		'i16' {
			Types.i16
		}
		'i32' {
			Types.i32
		}
		'i64' {
			Types.i64
		}
		'int' {
			Types.integer
		}
		'buffer' {
			Types.buffer
		}
		else {
			error("unknown type '${key}'")
		}
	}
}

pub fn wyr_type_from_return_keyword(key string) !Types {
	return match key {
		'void' {
			Types.@none
		}
		'string' {
			Types.str
		}
		'i8' {
			Types.i8
		}
		'i16' {
			Types.i16
		}
		'i32' {
			Types.i32
		}
		'i64' {
			Types.i64
		}
		'int' {
			Types.integer
		}
		'buffer' {
			Types.buffer
		}
		else {
			error("unknown type '${key}'")
		}
	}
}

pub fn must_parse_decl_type(key string, source string, line int) Types {
	return wyr_type_from_keyword(key) or {
		raise(Exception{
			msg:    'Unknown type ${key}'
			source: source
			line:   line
			hint:   "No type '${key}' exists. Is it spelt correctly?"
		})
		Types.@none
	}
}

pub fn must_parse_return_word(ret string) Types {
	return wyr_type_from_return_keyword(ret) or {
		raise(Exception{
			msg:  'Unknown type ${ret}'
			hint: "No type '${ret}' exists. Is it spelt correctly?"
		})
		Types.@none
	}
}
