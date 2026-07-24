module wyr

// Condition text inside `if ( … )` or `while ( … )` (required parentheses).
fn extract_paren_condition(chunk string, kw string, line_no int) string {
	if !chunk.contains('(') {
		raise(Exception{
			msg:    'Missing parentheses in ${kw} condition'
			source: chunk
			line:   line_no + 1
			hint:   'Use: ${kw} (expr) — e.g. ${kw} (x == 0)'
		})
	}
	open := chunk.index('(') or {
		raise(Exception{
			msg:    'Missing ( in ${kw} condition'
			source: chunk
			line:   line_no + 1
			hint:   'Use: ${kw} (expr)'
		})
		0
	}
	close := chunk.last_index(')') or {
		raise(Exception{
			msg:    'Missing ) in ${kw} condition'
			source: chunk
			line:   line_no + 1
			hint:   'Use: ${kw} (expr)'
		})
		0
	}
	if close <= open {
		raise(Exception{
			msg:    'Empty or invalid ${kw} condition'
			source: chunk
			line:   line_no + 1
			hint:   'Use: ${kw} (expr)'
		})
	}
	return chunk[open + 1..close].trim(' ')
}

// lextokens_impl returns tokens and how many source lines from `lines` were consumed.
fn lextokens_impl(lines []string, record_flag bool, debug bool, lineoverride int) ([]&Token, int) {
	mut complete := []&Token{}
	mut idx := 0
	mut ifdepth := 0
	for idx < lines.len {
		chunk := lines[idx].trim(' ').trim_indent()
		line_no := idx + lineoverride
		mut token := &Token{
			@type:  TokenTypes.@none
			line:   line_no
			source: chunk
		}

		if debug {
			if record_flag {
				println('\x1b[35;43;1m${line_no}\x1b[0m -> ${chunk}\x1b[0m')
			} else {
				println('\x1b[37;42;1m${line_no}\x1b[0m -> ${chunk}\x1b[0m')
			}
		}

		if chunk.len == 0 {
			idx++
			continue
		}
		if chunk.len >= 2 && chunk[0..2] == '//' {
			idx++
			continue
		}
		if chunk[0] == `}` {
			if debug {
				println('Done recording')
			}
			if record_flag {
				return complete, idx + 1
			}
			idx++
			continue
		}
		if chunk.len >= 2 && chunk[0..2] == 'fi' {
			if debug {
				println('Done recording')
			}
			if record_flag {
				return complete, idx + 1
			}
			idx++
			continue
		}
		if chunk.len >= 4 && chunk[0..4] == 'esle' {
			if debug {
				println('Done recording')
			}
			if record_flag {
				return complete, idx + 1
			}
			idx++
			continue
		}
		if chunk.len >= 5 && chunk[0..5] == 'while' {
			proc_head := extract_paren_condition(chunk, 'while', line_no)
			sub := lines[idx + 1..]
			newtokens, n := lextokens_impl(sub, true, debug, lineoverride + idx + 1)
			token = &Token{
				id:     'while_${ifdepth}'
				value:  proc_head
				source: chunk
				line:   line_no
				@type:  TokenTypes.while
				extra:  newtokens
			}
			ifdepth++
			complete << token
			idx += 1 + n
			continue
		}
		if chunk.len >= 2 && chunk[0..2] == 'if' {
			proc_head := extract_paren_condition(chunk, 'if', line_no)
			sub := lines[idx + 1..]
			newtokens, n := lextokens_impl(sub, true, debug, lineoverride + idx + 1)
			token = &Token{
				id:     'iftree_${ifdepth}'
				value:  proc_head
				source: chunk
				line:   line_no
				@type:  TokenTypes.conditional
				extra:  newtokens
			}
			ifdepth++
			complete << token
			idx += 1 + n
			continue
		}
		if chunk.len >= 2 && chunk[0..2] == 'fn' {
			return_type := chunk.split('fn')[1].trim(' ').split(' ')[0]
			func_name := chunk.split('@')[1].split(' ')[0]
			arguments := chunk.split('(')[1].split(')')[0].split(',')
			mut local_offset := 0
			if !chunk.split('').contains('{') {
				local_offset += 1
			}
			sub := lines[idx + 1 + local_offset..]
			newtokens, n := lextokens_impl(sub, true, debug, lineoverride + idx + 1 + local_offset)
			token = &Token{
				id:     '${func_name}'
				value:  '${return_type} % ${func_name} % ${arguments}'
				source: chunk
				line:   line_no
				@type:  TokenTypes.decfunction
				extra:  newtokens
			}
			complete << token
			idx += 1 + local_offset + n
			continue
		}
		if chunk.len >= 4 && chunk[0..4] == 'else' {
			sub := lines[idx + 1..]
			newtokens, n := lextokens_impl(sub, true, debug, lineoverride + idx + 1)
			token = &Token{
				id:     'elsetree_${ifdepth - 1}'
				value:  ''
				source: chunk
				line:   line_no
				@type:  TokenTypes.conditional
				extra:  newtokens
			}
			complete << token
			idx += 1 + n
			continue
		}
		if chunk.contains('<<') {
			if chunk.split('<<').len < 2 {
				raise(Exception{
					msg:    'Incomplete declaration'
					source: chunk
					line:   lineoverride + idx + 1
					hint:   'Make sure that the declaration follows the format\n' +
						'Example > buffer<<var'
				})
			}
			id := chunk.split('<<')[0]
			value := chunk.split('<<')[1]
			token = &Token{
				id:      id
				line:    line_no
				@type:   TokenTypes.action
				source:  chunk
				valtype: Types.ident
				value:   value
			}
		} else if chunk[0] == `@` && chunk.contains('(') {
			inner := chunk.split('(')[1].split(')')[0]
			fname := chunk.split('@')[1].split('(')[0].trim(' ')
			token = &Token{
				id:      fname
				line:    line_no
				@type:   TokenTypes.userfunction
				source:  chunk
				valtype: Types.ident
				value:   inner.trim(' ')
			}
		} else if chunk[0] == `@` {
			id := chunk.split('@')[1].split('(')[0]
			token = &Token{
				id:      id
				line:    line_no
				@type:   TokenTypes.userfunction
				source:  chunk
				valtype: Types.ident
				value:   ''
			}
		} else if chunk[0] == `.` {
			dot_cmd := chunk.split(' ')[0]
			mut instr_rest := ''
			if chunk.len > dot_cmd.len {
				instr_rest = chunk[dot_cmd.len + 1..].trim(' ')
			}
			token = &Token{
				id:      dot_cmd
				line:    line_no
				@type:   TokenTypes.function
				source:  chunk
				valtype: Types.ident
				value:   instr_rest
			}
		} else if chunk.contains(' = ') && !chunk.contains('<<') {
			left, right := chunk.split_once(' = ') or {
				raise(Exception{
					msg:    'Invalid assignment'
					source: chunk
					line:   lineoverride + idx + 1
					hint:   'Use: name = expression'
				})
				'', ''
			}
			lhs := left.trim(' ')
			if lhs.contains(':') {
				raise(Exception{
					msg:    'Invalid assignment'
					source: chunk
					line:   lineoverride + idx + 1
					hint:   'Declarations use name:type value; assignment uses name = expr'
				})
			}
			token = &Token{
				id:      lhs
				line:    line_no
				@type:   TokenTypes.assign
				source:  chunk
				valtype: Types.ident
				value:   right.trim(' ')
			}
		} else if chunk.contains(' ') && chunk.split(' ')[0].contains(':') {
			id := chunk.split(' ')[0].split(':')[0]
			typ := chunk.split(' ')[0].split(':')[1]
			_, mut rhs_full := chunk.split_once(' ') or {
				raise(Exception{
					msg:    'Incomplete declaration'
					source: chunk
					line:   lineoverride + idx + 1
					hint:   'Make sure that the declaration follows the format\nExample > x:int 2'
				})
				'', ''
			}
			mut value := rhs_full.trim(' ')
			mut tflag := Flags.@none
			rparts := value.split(' ')
			if rparts.len >= 2 && rparts[rparts.len - 1] == 'const' {
				tflag = Flags.@const
				value = rparts[..rparts.len - 1].join(' ').trim(' ')
			}
			if id.len == 0 || typ.len == 0 {
				raise(Exception{
					msg:    'Incomplete declaration'
					source: chunk
					line:   lineoverride + idx + 1
					hint:   'Make sure that the declaration follows the format\n' +
						'Example > x:int 2'
				})
			}
			decl_type := must_parse_decl_type(typ, chunk, lineoverride + idx)
			token = &Token{
				id:      id
				line:    line_no
				@type:   TokenTypes.variable
				flag:    tflag
				source:  chunk
				valtype: decl_type
				value:   value
			}
			if token.valtype == Types.integer {
				raise(Warning{
					msg:    'Integer type will soon be redundant'
					source: chunk
					line:   lineoverride + idx + 1
					hint:   'Please specify the size of your integers using i8, i16, i32 and i64'
				})
			}
		} else {
			raise(Exception{
				msg:    'Unknown statement'
				source: chunk
				line:   lineoverride + idx + 1
				hint:   'Refer to the guidebook for language documentation'
			})
		}
		complete << token
		idx++
	}
	if record_flag {
		raise(Exception{
			msg:    'Trailing chunk'
			source: ''
			line:   lines.len + lineoverride + 1
			hint:   'Perhaps you forgot to terminate a code block?'
		})
	}
	return complete, idx
}

pub fn lextokens(clean_code []string, record_flag bool, debug bool, lineoverride int) []&Token {
	toks, _ := lextokens_impl(clean_code, record_flag, debug, lineoverride)
	return toks
}
