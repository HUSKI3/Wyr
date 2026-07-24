module wyr

pub fn split_comparison_condition(s string) !(string, string, string) {
	t := s.trim(' ')
	// Longer operators first so `<=` is not parsed as `<` + garbage.
	for op in ['<=', '>=', '==', '!=', '<', '>'] {
		idx := t.index(op) or { -1 }
		if idx < 0 {
			continue
		}
		lhs := t[..idx].trim(' ')
		rhs := t[idx + op.len..].trim(' ')
		if lhs.len > 0 && rhs.len > 0 {
			return lhs, op, rhs
		}
	}
	return error('comparison needs lhs op rhs (e.g. a == b)')
}

pub fn parse_if_while_condition(raw string) !(string, string, string) {
	t := raw.trim(' ')
	return split_comparison_condition(t) or {
		parts := t.split(' ')
		if parts.len < 3 {
			return error('invalid condition: ${t}')
		}
		return parts[0], parts[1], parts[2..].join(' ')
	}
}
