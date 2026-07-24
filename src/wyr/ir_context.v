module wyr

// Records one name binding so it can be restored after lowering a function body.
pub struct ScopeBinding {
pub:
	name     string
	had_prev bool
	prev     &Variable
}

// ParseCtx carries function lowering state for .ret, control-flow labels, and per-function scope.
pub struct ParseCtx {
pub:
	fn_exit_label      string
	fn_return_type     Types
	fn_return_width    int // bytes for mov to rax: 1,2,4,8
	flow_label_prefix  string // prepended to if/while labels inside functions
pub mut:
	scope_restore  []ScopeBinding
	fn_local_names map[string]bool // params + body locals in the current fn (no shadowing within fn)
}

pub fn root_parse_ctx() ParseCtx {
	return ParseCtx{
		fn_exit_label:      ''
		fn_return_type:     Types.@none
		fn_return_width:    4
		flow_label_prefix:  ''
		scope_restore:      []ScopeBinding{}
		fn_local_names:     map[string]bool{}
	}
}

pub fn fn_parse_ctx(exit_label string, ret Types, flow_prefix string) ParseCtx {
	if ret == Types.@none {
		return ParseCtx{
			fn_exit_label:      exit_label
			fn_return_type:     ret
			fn_return_width:    0
			flow_label_prefix:  flow_prefix
			scope_restore:      []ScopeBinding{}
			fn_local_names:     map[string]bool{}
		}
	}
	w := match ret {
		.i8 { 1 }
		.i16 { 2 }
		.i32, .integer { 4 }
		.i64 { 8 }
		else { 4 }
	}
	return ParseCtx{
		fn_exit_label:      exit_label
		fn_return_type:     ret
		fn_return_width:    w
		flow_label_prefix:  flow_prefix
		scope_restore:      []ScopeBinding{}
		fn_local_names:     map[string]bool{}
	}
}
