module wyr

// validate_module performs structural checks after lexing.
pub fn validate_module(tokens []&Token, header IrModuleHeader) {
	_ := header.version
	mut seen_var := map[string]bool{}
	mut seen_fn := map[string]bool{}
	for tok in tokens {
		if tok.@type == .variable {
			if tok.id in seen_var {
				raise(Exception{
					msg:    'Duplicate top-level symbol ${tok.id}'
					source: tok.source
					line:   tok.line + 1
					hint:   'Each name may only be declared once at module scope'
				})
			}
			seen_var[tok.id] = true
		} else if tok.@type == .decfunction {
			if tok.id in seen_fn {
				raise(Exception{
					msg:    'Duplicate function ${tok.id}'
					source: tok.source
					line:   tok.line + 1
					hint:   'Each fn @name must be unique at module scope'
				})
			}
			seen_fn[tok.id] = true
		}
	}
}
