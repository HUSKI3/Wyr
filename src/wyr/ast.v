module wyr

pub enum Types {
	@none
	unset
	ident
	str
	i8
	i16
	i32
	i64
	integer
	buffer
}

pub const typesizes = {
	Types.ident:   0
	Types.str:     2
	Types.integer: 8
	Types.buffer:  0
}

pub const loadsizes = {
	0: 'invalid'
	1: 'db'
	2: 'dw'
	4: 'dd'
	8: 'dq'
}

pub enum TokenTypes {
	@none
	variable
	decfunction
	function
	userfunction
	action
	assign
	extra
	conditional
	while
}

pub const operands_inverted = {
	'<=': 'jg'
	'>=': 'jl'
	'==': 'jne'
	'!=': 'je'
	'<':  'jge'
	'>':  'jle'
}

pub const operands_direct = {
	'<=': 'jle'
	'>=': 'jge'
	'==': 'je'
	'!=': 'jne'
	'<':  'jl'
	'>':  'jg'
}

pub enum Flags {
	@none
	@const
}

pub struct Token {
pub:
	id      string
	@type   TokenTypes
	valtype Types
	value   string
	source  string
	flag    Flags
	line    int
	extra   []&Token
}

pub struct Variable {
pub:
	id        string
	@type     Types
	value     string
	token     Token
	size      int
	@const    bool
	param_reg string // if set, i32-ish param lives in this ABI register at entry (rdi, rsi, ...)
}

pub struct Function {
pub:
	id      string
	returns Types
	token   Token
}

pub const int_compare_types = [
	Types.integer,
	Types.i8,
	Types.i16,
	Types.i32,
	Types.i64,
]

pub const small_int_types = [Types.i8, Types.i16]
