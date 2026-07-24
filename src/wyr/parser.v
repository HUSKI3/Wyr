module wyr

fn token_tree_contains_ret(tokens []&Token) bool {
	for t in tokens {
		if t.@type == TokenTypes.function && t.id == '.ret' {
			return true
		}
		if t.@type in [.conditional, .while] {
			if token_tree_contains_ret(t.extra) {
				return true
			}
		}
	}
	return false
}

pub fn parse_tokens(complete []&Token,
	mut bss []string,
	mut data []string,
	mut text []string,
	mut tailtext []string,
	mut variables map[string]&Variable,
	mut functions map[string]&Function,
	mut buffers map[string][]string,
	builtin map[string][]string,
	mut ctx ParseCtx) {
	mut skip := 0

	for index, token in complete {
		if skip != 0 {
			skip--
			continue
		}
		match token.@type {
			.variable {
				id := &token.id
				value := &token.value
				if ctx.fn_exit_label.len > 0 && *id in ctx.fn_local_names {
					raise(Exception{
						msg:    'Duplicate name in function'
						source: token.source
						line:   token.line + 1
						hint:   "The name '${*id}' is already a parameter or local in this function"
					})
				}
				if *id in variables {
					if ctx.fn_exit_label.len == 0 {
						raise(Exception{
							msg:    'Variable already exists'
							source: token.source
							line:   token.line + 1
							hint:   'A variable with this name is already declared\n' +
								'Please use a new identifier'
						})
					}
					scope_note_before_define(mut variables, mut ctx, *id)
				} else if ctx.fn_exit_label.len > 0 {
					scope_note_before_define(mut variables, mut ctx, *id)
				}
				if is_scalar_int_type(token.valtype) {
					is_const := token.flag == Flags.@const
					declare_scalar_int(mut bss, mut data, *id, *value, token.valtype,
						is_const)
					register_int_var(mut variables, *id, token.valtype, *value, token,
						is_const)
					if ctx.fn_exit_label.len > 0 {
						ctx.fn_local_names[*id] = true
					}
				} else if token.valtype == .str {
					data << '\t${*id}: db ${*value}\n'
					data << '\t${*id}_len: equ $ - ${*id}\n'
					variables[*id] = &Variable{
						id:        *id
						@type:     token.valtype
						value:     *value
						size:      typesizes[token.valtype] * (*value).len
						token:     *token
						param_reg: ''
					}
					if ctx.fn_exit_label.len > 0 {
						ctx.fn_local_names[*id] = true
					}
				} else if token.valtype == .buffer {
					if (*value).int() == 0 {
						data << '\t${*id}_len: equ ${*id}_len\n'
					} else {
						bss << '\t${*id}_len equ ${*value}\n'
					}
					bss << '\t${*id} resb ${*id}_len\n'
					data << '\t${*id}_used dd 0\n'
					variables[*id] = &Variable{
						id:        *id
						@type:     token.valtype
						value:     *value
						token:     *token
						param_reg: ''
					}
					buffers[*id] = []
					if ctx.fn_exit_label.len > 0 {
						ctx.fn_local_names[*id] = true
					}
				} else {
					raise(Exception{
						msg:    'Not implemented'
						source: token.source
						line:   token.line + 1
						hint:   'Not implemented'
					})
				}
			}
			.assign {
				id := &token.id
				if *id !in variables {
					raise(Exception{
						msg:    'Unknown variable'
						source: token.source
						line:   token.line + 1
						hint:   "Assign to unknown '${*id}'"
					})
				}
				v := variables[*id]
				if v.@const {
					raise(Exception{
						msg:    'Cannot assign to const'
						source: token.source
						line:   token.line + 1
						hint:   'Constants are immutable'
					})
				}
				if !is_scalar_int_type(v.@type) {
					raise(Exception{
						msg:    'Assignment not supported for this type'
						source: token.source
						line:   token.line + 1
						hint:   'Only scalar integers use ='
					})
				}
				e := parse_expr_string(token.value, token) or {
					raise(Exception{
						msg:    'Invalid expression'
						source: token.source
						line:   token.line + 1
						hint:   err.msg()
					})
					unsafe { nil }
				}
				emit_expr_into_eax(mut text, variables, e, token)
				emit_store_eax_to_var(mut text, v, *id)
			}
			.conditional {
				id := &token.id
				value := &token.value
				body := token.extra
				fl := ctx.flow_label_prefix
				if (*value).len > 0 {
					lhs, op, rhs := parse_if_while_condition(*value) or {
						raise(Exception{
							msg:    'Invalid if condition'
							source: token.source
							line:   token.line + 1
							hint:   err.msg()
						})
						'', '', ''
					}
					if op !in operands_inverted {
						raise(Exception{
							msg:    'Unknown comparison operator'
							source: token.source
							line:   token.line + 1
							hint:   'Use ==, !=, <, >, <=, or >='
						})
					}
					jmp_op := operands_inverted[op]
					emit_compare_pair(mut text, variables, lhs, rhs, token)
					text << '\t${jmp_op} ${fl}${*id}_ne\n'
					parse_tokens(body, mut bss, mut data, mut text, mut tailtext, mut
						variables, mut functions, mut buffers, builtin, mut ctx)
					if index + 1 < complete.len && complete[index + 1].source == 'else' {
						text << '\tjmp ${fl}${*id}_end\n'
					}
					text << '${fl}${*id}_ne:\n'
				} else {
					parse_tokens(body, mut bss, mut data, mut text, mut tailtext, mut
						variables, mut functions, mut buffers, builtin, mut ctx)
					text << '${fl}iftree_${(*id)[9..]}_end:\n'
				}
			}
			.while {
				id := &token.id
				value := &token.value
				body := token.extra
				fl := ctx.flow_label_prefix
				if (*value).len > 0 {
					lhs, op, rhs := parse_if_while_condition(*value) or {
						raise(Exception{
							msg:    'Invalid while condition'
							source: token.source
							line:   token.line + 1
							hint:   err.msg()
						})
						'', '', ''
					}
					if op !in operands_inverted {
						raise(Exception{
							msg:    'Unknown comparison operator'
							source: token.source
							line:   token.line + 1
							hint:   'Use ==, !=, <, >, <=, or >='
						})
					}
					jmp_exit := operands_inverted[op]
					text << '${fl}${*id}:\n'
					emit_compare_pair(mut text, variables, lhs, rhs, token)
					text << '\t${jmp_exit} ${fl}${*id}_exit\n'
					parse_tokens(body, mut bss, mut data, mut text, mut tailtext, mut
						variables, mut functions, mut buffers, builtin, mut ctx)
					text << '\tjmp ${fl}${*id}\n'
					text << '${fl}${*id}_exit:\n'
				}
			}
			.action {
				id := &token.id
				value := &token.value
				require_variable(*id, variables, token)
				require_variable(*value, variables, token)
				match variables[*id].@type {
					.buffer {
						if variables[*value].@type != Types.str
							&& variables[*value].@type != Types.buffer {
							raise(Exception{
								msg:    'Invalid variable type'
								source: token.source
								line:   token.line + 1
								hint:   "Calling an action '${*id}' with '${*value}' which isnt supported"
							})
						}
						if variables[*value].size > variables[*id].value.int()
							&& variables[*id].value.int() != 0 {
							raise(Exception{
								msg:    'Buffer overflow'
								source: token.source
								line:   token.line + 1
								hint:   'Value of ${*value}(${variables[*value].size}) is too big for the buffer ${*id}(${variables[*id].value.int()})'
							})
						}
						text << '\tlea rsi, [${*value}]\n'
						text << '\tmov eax, dword [${*id}_used]\n'
						text << '\tmovsxd rax, eax\n'
						text << '\tlea rdi, [${*id} + rax]\n'
						text << '\tmov ecx, ${*value}_len\n'
						text << '\tmov r8d, ecx\n'
						text << '\tcld\n'
						text << '\trep movsb\n'
						text << '\tmov eax, dword [${*id}_used]\n'
						text << '\tadd eax, r8d\n'
						text << '\tmov dword [${*id}_used], eax\n'
						buffers[*id] << *value
					}
					else {
						raise(Exception{
							msg:    'No actions available for type'
							source: token.source
							line:   token.line + 1
							hint:   "The type '${variables[*id].@type}' doesn't implement any actions"
						})
					}
				}
			}
			.function {
				id := &token.id.split('.')[1]
				value := &token.value
				if *id == 'ret' {
					emit_ret_stmt(mut text, ctx, variables, *value, token)
				} else if *id == 'poke8' {
					if !(*value).contains(',') {
						raise(Exception{
							msg:    'Invalid usage'
							source: token.source
							line:   token.line + 1
							hint:   ".poke8 expects buffer name and expression: .poke8 buf, expr\n" +
								'Writes the low 8 bits of expr into the first byte of buf.'
						})
					}
					pbuf := (*value).split(',')[0].trim(' ')
					pexpr := (*value).split(',')[1].trim(' ')
					require_variable(pbuf, variables, token)
					if variables[pbuf].@type != .buffer {
						raise(Exception{
							msg:    'Invalid type'
							source: token.source
							line:   token.line + 1
							hint:   ".poke8 target must be a buffer, got '${pbuf}'"
						})
					}
					if variables[pbuf].value.int() < 1 {
						raise(Exception{
							msg:    'Invalid buffer'
							source: token.source
							line:   token.line + 1
							hint:   '.poke8 needs a buffer with size at least 1 byte'
						})
					}
					e := parse_expr_string(pexpr, token) or {
						raise(Exception{
							msg:    'Invalid expression'
							source: token.source
							line:   token.line + 1
							hint:   err.msg()
						})
						unsafe { nil }
					}
					emit_expr_into_eax(mut text, variables, e, token)
					text << '\tmov byte [${pbuf}], al\n'
				} else {
					mut call := []string{}
					if *id in builtin {
						call = builtin[*id]
					} else {
						raise(Exception{
							msg:    'Unknown call'
							source: token.source
							line:   token.line + 1
							hint:   "Calling an undefined function '.${*id}'\n" +
								"Perhaps it's not present in the builtins?"
						})
					}
					if *id in ['add', 'sub'] {
						mut first_element_raw := ''
						mut second_element_raw := ''
						mut var_priority := 0
						if (*value).contains(',') {
							first_element_raw = value.split(',')[0]
							second_element_raw = value.split(',')[1]
						} else {
							raise(Exception{
								msg:    'Invalid usage'
								source: token.source
								line:   token.line + 1
								hint:   ".add expects two values separated with a ','\n" +
									'Example: .add x,1'
							})
						}
						if is_numeric(first_element_raw) {
							text << '\tmov ax, ${first_element_raw}\n'
							var_priority = 2
						} else {
							require_int_for_math(first_element_raw, variables, token)
							text << '\tmov ax, [${first_element_raw}]\n'
							var_priority = 1
						}
						if is_numeric(second_element_raw) {
							text << '\t${*id} ax, ${second_element_raw}\n'
							var_priority = 1
						} else {
							require_int_for_math(second_element_raw, variables, token)
							text << '\t${*id} ax, [${second_element_raw}]\n'
							var_priority = 2
						}
						if var_priority == 1 {
							text << '\tmov [${first_element_raw}], ax\n'
						} else if var_priority == 2 {
							text << '\tmov [${second_element_raw}], ax\n'
						} else {
							raise(Exception{
								msg:    'Invalid addition target'
								source: token.source
								line:   token.line + 1
								hint:   'This token was never constructed\n' +
									'Perhaps the lexer branch for this type is incomplete?'
							})
						}
					} else if *id == 'output' {
						require_variable(*value, variables, token)
						if variables[*value].@type != Types.buffer {
							raise(Exception{
								msg:    'Invalid type'
								source: token.source
								line:   token.line + 1
								hint:   "Function 'output' takes a buffer but '${*value}' is of type ${variables[*value].@type}"
							})
						}
						text << '\tmov rsi, ${*value}\n'
						text << '\tmov edx, dword [${*value}_used]\n'
						text << '\tmovsxd rdx, edx\n'
					} else if *id == 'input' {
						require_variable(*value, variables, token)
						if variables[*value].@type != Types.buffer {
							raise(Exception{
								msg:    'Invalid type'
								source: token.source
								line:   token.line + 1
								hint:   "Function 'input' takes a buffer but '${*value}' is of type ${variables[*value].@type}"
							})
						}
						text << '\tlea rsi, [${*value}]\n'
						text << '\tmov rdx, 16\n'
					} else if *id == 'clear_buff' {
						require_variable(*value, variables, token)
						if variables[*value].@type != Types.buffer {
							raise(Exception{
								msg:    'Invalid type'
								source: token.source
								line:   token.line + 1
								hint:   "Function 'clear_buff' takes a buffer but '${*value}' is of type ${variables[*value].@type}"
							})
						}
						text << '\tmov edi, ${*value}\n'
						text << '\tmov ecx, ${*value}_len\n'
						text << '\txor al, al\n' + '\tcld\n' + '\trep stosb\n'
						text << '\tmov dword [${*value}_used], 0\n'
						buffers[*value].clear()
					}
					for c in call {
						text << '${c}\n'
					}
				}
			}
			.decfunction {
				id := &token.id
				source := &token.source
				body := &token.extra
				ret := (&token.source).split(' ')[1]
				return_type := must_parse_return_word(ret)
				arguments := source.split('(')[1].split(')')[0].split(',').map(fn (arg string) string {
					return arg.trim(' ')
				})
				has_ret := token_tree_contains_ret(*body)
				if return_type != Types.@none && !has_ret {
					raise(Exception{
						msg:    'Return type not set or body contains no return'
						source: *source
						line:   token.line + 1
						hint:   'Add .ret <expr> before the closing brace'
					})
				}
				exit_lbl := '${*id}_fn_leave'
				tailtext << '\n${*id}:\n'
				tailtext << '\n; Function prologue
\tpush rbp
\tmov rbp, rsp\n'
				mut sub_ctx := fn_parse_ctx(exit_lbl, return_type, '${*id}_')
				mut arg_i := 0
				mut spill_argnames := []string{}
				mut spill_regs := []string{}
				mut spill_types := []Types{}
				for arg in arguments {
					if arg == '' {
						break
					}
					argtype, argname := arg.split_once(' ') or {
						raise(Exception{
							msg:    'Invalid function argument'
							source: *source
							line:   token.line + 1
							hint:   "Each argument must be written as 'type name', for example: i32 x"
						})
						'', ''
					}
					if argname in sub_ctx.fn_local_names {
						raise(Exception{
							msg:    'Duplicate parameter name'
							source: *source
							line:   token.line + 1
							hint:   "Two parameters named '${argname}'"
						})
					}
					if arg_i >= abi_arg_regs.len {
						raise(Exception{
							msg:    'Too many parameters'
							source: *source
							line:   token.line + 1
							hint:   'At most ${abi_arg_regs.len} parameters'
						})
					}
					pr := abi_arg_regs[arg_i]
					arg_i++
					arg_ty := must_parse_decl_type(argtype, *source, token.line + 1)
					scope_note_before_define(mut variables, mut sub_ctx, argname)
					declare_scalar_int(mut bss, mut data, argname, '0', arg_ty, false)
					variables[argname] = &Variable{
						id:        argname
						@type:     arg_ty
						value:     ''
						token:     Token{}
						param_reg: pr
					}
					sub_ctx.fn_local_names[argname] = true
					spill_argnames << argname
					spill_regs << pr
					spill_types << arg_ty
				}
				mut tail_text := []string{}
				for si := 0; si < spill_argnames.len; si++ {
					name := spill_argnames[si]
					pr := spill_regs[si]
					ty := spill_types[si]
					match ty {
						.i8 {
							tail_text << '\tmov al, ${abi_reg_low8(pr)}\n\tmov byte [${name}], al\n'
						}
						.i16 {
							tail_text << '\tmov ax, ${abi_reg_low16(pr)}\n\tmov word [${name}], ax\n'
						}
						.i32, .integer {
							tail_text << '\tmov eax, ${abi_reg_low32(pr)}\n\tmov dword [${name}], eax\n'
						}
						.i64 {
							tail_text << '\tmov rax, ${pr}\n\tmov qword [${name}], rax\n'
						}
						else {
							raise(Exception{
								msg:    'Unsupported parameter type'
								source: *source
								line:   token.line + 1
								hint:   'Only scalar int types may be function parameters'
							})
						}
					}
					v := variables[name]
					variables[name] = &Variable{
						id:        v.id
						@type:     v.@type
						value:     v.value
						token:     v.token
						size:      v.size
						@const:    v.@const
						param_reg: ''
					}
				}
				parse_tokens(*body, mut bss, mut data, mut tail_text, mut tailtext, mut
					variables, mut functions, mut buffers, builtin, mut sub_ctx)
				scope_restore_all(mut variables, mut sub_ctx)
				for elem in tail_text {
					tailtext << elem
				}
				tailtext << '${exit_lbl}:\n; Function epilogue
\tpop rbp
\tret\n'
			}
			.userfunction {
				id := &token.id
				val := &token.value
				emit_user_call(mut text, variables, *id, *val, token)
			}
			.@none {
				raise(Exception{
					msg:    'Token empty'
					source: token.source
					line:   token.line + 1
					hint:   'This token was never constructed\n' +
						'Perhaps the lexer branch for this type is incomplete?'
				})
			}
			else {
				raise(Exception{
					msg:    'Not implemented'
					source: token.source
					line:   token.line + 1
					hint:   'Not implemented'
				})
			}
		}
	}
}
