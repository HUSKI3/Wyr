module main
import flag
import os
import encoding.hex
import strconv

fn is_numeric(s string) bool {
    _ := strconv.parse_int(s, 10, 32) or {
		return false
	}
    return true
}

struct Exception {
	msg string
	source string
	line int
	hint string
}

fn raise(e &Exception) {
	println("\033[31;1;4m[Exception] at ${e.line} => ${e.msg}\033[0m")
	println("\033[32;49;3m${e.line}\033[0m\033[37;49;1m\t${e.source}\033[0m")
	if e.hint.len != 0 {
		println("\033[36;49;3m${e.hint}\033[0m")
	}
	exit(1)
}

enum Types {
	@none
	ident
	str
	i8
	i16
	i32
	i64
	integer
	buffer
}

const typesizes = {
	Types.ident: 0,
	Types.str: 2,
	Types.integer: 8,
	Types.buffer: 0
}

const loadsizes = {
	0: "invalid",
	1: "db",
	2: "dw",
	4: "dd",
	8: "dq"
}

enum TokenTypes {
	@none
	variable
	function
	action
	extra
	conditional
}

const operands = {
	"==": "cmp"
}

enum Flags {
	@none
	@const
}

struct Token {
	id string
	@type TokenTypes
	valtype Types
	value string
	source string
	flag Flags
	line int
	extra []&Token
}

struct Variable {
	id string
	@type Types
	value string
	token Token
	size int
	@const bool
}

fn main() {
	mut fp := flag.new_flag_parser(os.args)

	fp.application("wyr")
	fp.version("0.0.1")
	fp.description('Simple language to abstract nasm')
	fp.skip_executable()

	source := fp.string('source', `s`, '', 'specify .wyr source')
	debug  := fp.bool('debug', `d`, false, 'enable debugging')

	fp.finalize() or {
		eprintln(err.msg())
		exit(1)
	}

	// Ensure programs required for compilation are installed
	if ensure_dep("nasm") {
		if debug {
			println("[Check] nasm is present")
		}
	}
	if ensure_dep("ld") {
		if debug {
			println("[Check] ld is present")
		}
	}
	

	if source.len == 0 {
		println("Source not provided")
		exit(1)
	} 

	if debug {
		println("Loading -> ${source}")
	}

	code := os.read_lines(source) or {
		panic(err)
	}

	mut clean_code := []string{}

	for line in code {
		mut txt := line
			.trim(" ")
			.trim_indent()
		clean_code << txt
	}

	mut complete := lextokens(clean_code, false, debug, 0)

	if debug {
		println("Finished constructing tokens")
	}

	// Process tokens and convert to nasm
	
	// builtin functions
	mut builtin := {
		"output": [
			"\tmov rax, 1\n" +
    		"\tmov rdi, 1\n"+
			"\tsyscall\n"
		],
		"input": [
			"\tmov rax, 0\n" +
			"\tmov rdi, 0\n" +
			"\tsyscall\n"
		],
		"clear_buff": [],
		"add": [],
		"sub": []
	}

	// remember declarations
	mut variables := map[string]&Variable{}
	mut buffers   := map[string][]string{}

	// sections
	mut bss := [
		"section .bss\n"
	]
	mut data := [
		"section .data\n"
	]

	mut text := [
		"section .text\n",
		"\tglobal _start\n",
		"\t_start:\n"
	]

	parsetokens(
		complete, 
		mut bss, 
		mut data, 
		mut text, 
		mut variables, 
		mut buffers, 
		builtin
	)


	text << "done:
    mov rax, 60
    xor rdi, rdi
    syscall"

	if debug {
		println("Finished asm")
	}

	mut output := os.create('out.asm') or {
    	os.open('out.asm')!
	}

	for elem in bss {
		output.write(elem.bytes())!
	}
	for elem in data {
		output.write(elem.bytes())!
	}
	for elem in text {
		output.write(elem.bytes())!
	}

	println("Built!")
	// mut out := os.execute("nasm -felf64 out.asm && ld out.o && ./a.out")
	// println(out.output)
}

fn parsetokens(
	complete []&Token, 
	mut bss []string, 
	mut data []string, 
	mut text []string,
	mut variables map[string]&Variable,
	mut buffers map[string][]string,
	builtin map[string][]string
) {

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

				// Make sure id is not already present
				if *id in variables {
					e := &Exception{
							msg: "Variable already exists"
							source: token.source
							line: token.line+1
							hint: "A variable with this name is already declared\n" +
								  "Please use a new identifier"
					}
					raise(e)
				} 

				match token.valtype {
					.i8 {
						if token.flag == Flags.@const {
							// Write to bss
							bss << "\t${*id} equ ${*value}\n"
						} else {
							data << "\t${*id}: db ${*value}\n"
						}
						// Add to variables
						variables[*id] = &Variable{
							id: *id
							@type: token.valtype
							value: *value
							token: token
							@const: token.flag == Flags.@const
						}
					}
					.i16 {
						if token.flag == Flags.@const {
							// Write to bss
							bss << "\t${*id} equ ${*value}\n"
						} else {
							data << "\t${*id}: dw ${*value}\n"
						}
						// Add to variables
						variables[*id] = &Variable{
							id: *id
							@type: token.valtype
							value: *value
							token: token
							@const: token.flag == Flags.@const
						}
					}
					.i32 {
						if token.flag == Flags.@const {
							// Write to bss
							bss << "\t${*id} equ ${*value}\n"
						} else {
							data << "\t${*id}: dd ${*value}\n"
						}
						// Add to variables
						variables[*id] = &Variable{
							id: *id
							@type: token.valtype
							value: *value
							token: token
							@const: token.flag == Flags.@const
						}
					}
					.i64 {
						if token.flag == Flags.@const {
							// Write to bss
							bss << "\t${*id} equ ${*value}\n"
						} else {
							data << "\t${*id}: dq ${*value}\n"
						}
						// Add to variables
						variables[*id] = &Variable{
							id: *id
							@type: token.valtype
							value: *value
							token: token
							@const: token.flag == Flags.@const
						}
					}
					.integer {
						if token.flag == Flags.@const {
							// Write to bss
							bss << "\t${*id} equ ${*value}\n"
						} else {
							data << "\t${*id}: dd ${*value}\n"
						}
						// Add to variables
						variables[*id] = &Variable{
							id: *id
							@type: token.valtype
							value: *value
							token: token
							@const: token.flag == Flags.@const
						}
					}
					.str{
						// String construction
						// Example:
						// 		hello_msg: db "Hello " 
    					//		hello_len equ $ - hello_msg

						data << "\t${*id}: db ${*value}\n"
						data << "\t${*id}_len: equ $ - ${*id}\n"

						// Add to variables
						variables[*id] = &Variable{
							id: *id
							@type: token.valtype
							value: *value
							size: typesizes[token.valtype] * ((*value).len)
							token: token
						}
					}
					.buffer{
						// Buffer should be constant
						// Example:
						//		output_len equ 255
						//		output resb output_len

						if (*value).int() == 0 {
							// Example: f_len: equ $ - msg
							data << "\t${*id}_len: equ ${*id}_len\n"
						} else {
							bss << "\t${*id}_len equ ${*value}\n"
						}

						bss << "\t${*id} resb ${*id}_len\n"
						

						// Add to variables
						variables[*id] = &Variable{
							id: *id
							@type: token.valtype
							value: *value
							token: token
						}
						buffers[*id] = []
					}

					else {
						e := &Exception{
							msg: "Not implemented"
							source: token.source
							line: token.line+1
							hint: "Not implemented"
						}
						raise(e)
					}
				}
			}

			.conditional {
				id := &token.id
				value := &token.value
				body := token.extra

				if (*value).len > 0 {

					first_element_raw  := (*value).split(' ')[0]
					operand            := (*value).split(' ')[1]
					second_element_raw := (*value).split(' ')[2]

					op := operands[operand]

					mut comparison_type := "i32:i64"

					if is_numeric(first_element_raw) {
						text << "\tmov eax, ${first_element_raw}\n"
					} else {
						if !(first_element_raw in variables) {
							e := &Exception{
								msg: "Unknown variable"
								source: token.source
								line: token.line+1
								hint: "No such variable '${first_element_raw}'\n" +
									"Perhaps it's not declared?"
							}
							raise(e)
						}
						if !(variables[first_element_raw].@type in [
							Types.integer,
							Types.i8, Types.i16, Types.i32, Types.i64
						]) {
							e := &Exception{
								msg: "Invalid item for comparison"
								source: token.source
								line: token.line+1
								hint: "Variable '${first_element_raw}'<${variables[first_element_raw].@type}> is not of type int\n" +
									"Only integers can be used for evaluation"
							}
							raise(e)
						}
						if variables[first_element_raw].@type in [
							Types.i8, Types.i16
						] {
							text << "\tmov al, byte [${first_element_raw}]\n"
							comparison_type = "i8:i16"
						} else {
							text << "\tmov eax, [${first_element_raw}]\n"
						}
					}

					if is_numeric(second_element_raw) {
						text << "\tcmp eax, ${second_element_raw}\n"
					} else {
						if !(second_element_raw in variables) {
							e := &Exception{
								msg: "Unknown variable"
								source: token.source
								line: token.line+1
								hint: "No such variable '${second_element_raw}'\n" +
									"Perhaps it's not declared?"
							}
							raise(e)
						}
						if !(variables[second_element_raw].@type in [
							Types.integer,
							Types.i8, Types.i16, Types.i32, Types.i64
						]) {
							e := &Exception{
								msg: "Invalid item for comparison"
								source: token.source
								line: token.line+1
								hint: "Variable '${second_element_raw}'<${variables[second_element_raw].@type}>  is not of type int\n" +
									"Only integers can be used for evaluation"
							}
							raise(e)
						}
						if variables[second_element_raw].@type in [
							Types.i8, Types.i16
						] {
							text << "\tcmp al, byte [${second_element_raw}]\n"
						} else {
							text << "\tcmp al, [${second_element_raw}]\n"
						}
					}

					text << "\tjne ${*id}_ne\n"

					// Build body
					parsetokens(
						body, 
						mut bss, 
						mut data, 
						mut text, 
						mut variables, 
						mut buffers, 
						builtin
					)

					skip = body.len
					
					// Add jump to end or something
					text << "\tjmp ${*id}_end\n"

					text << "${*id}_ne:\n"

				} else {
					// Else
					
					// Build body
					parsetokens(
						body, 
						mut bss, 
						mut data, 
						mut text, 
						mut variables, 
						mut buffers, 
						builtin
					)

					skip = body.len
					
					text << "iftree_${(*id)[9..]}_end:\n"
				}
				
			}

			.action {
				id := &token.id
				value := &token.value

				if !(*id in variables) {
					e := &Exception{
						msg: "Unknown variable"
						source: token.source
						line: token.line+1
						hint: "Calling an action on unknown '${*id}'\n" +
							  "Perhaps it's not declared?"
					}
					raise(e)
				}

				if !(*value in variables) {
					e := &Exception{
						msg: "Unknown variable"
						source: token.source
						line: token.line+1
						hint: "Calling an action with unknown '${*value}'\n" +
							  "Perhaps it's not declared?"
					}
					raise(e)
				}
				
				
				match variables[*id].@type {
					.buffer {

						if variables[*value].@type != Types.str && variables[*value].@type != Types.buffer {
							e := &Exception{
								msg: "Invalid variable type"
								source: token.source
								line: token.line+1
								hint: "Calling an action '${*id}' with '${*value}' which isnt supported"
							}
							raise(e)
						}

						if (variables[*value].size > variables[*id].value.int()) && variables[*id].value.int() != 0 {
							e := &Exception{
								msg: "Buffer oveflow"
								source: token.source
								line: token.line+1
								hint: "Value of ${*value}(${variables[*value].size}) is too big for the buffer ${*id}(${variables[*id].value.int()})"
							}
							raise(e)
						}

						// We want to add a new value at an offset
						// Example:
						//		concat:
    					//		lea rsi, [output + hello_len] ; origin
    					//		lea rdi, [output + hello_len] ; destination
    					//		mov rcx, rax
    					//		std
    					//		rep movsb

						mut follow := " "//+ ${*value}_len"
						for elem in buffers[*id] {
							follow += " + ${elem}_len"
						}

						text << "\tlea rsi, [${*value}]\n"
						text << "\tlea rdi, [${*id}$follow]\n"
						text << "\tmov rcx, ${*value}_len\n"
						text << "\tcld\n"
						text << "\trep movsb\n"

						// Add a follower
						buffers[*id] << *value
					}
					else {
						e := &Exception{
							msg: "No actions available for type"
							source: token.source
							line: token.line+1
							hint: "The type '${variables[*id].@type}' doesn't implement any actions"
						}
						raise(e)
					}
				}


			}

			.function {
				id := &token.id.split(".")[1]
				value := &token.value
				mut call := []string{}

				// Build the base
				if *id in builtin {
					call = builtin[*id]  
				} else {
					e := &Exception{
						msg: "Unknown call"
						source: token.source
						line: token.line+1
						hint: "Calling an undefined function '${*id}'\n" +
							  "Perhaps it's not present in the builtins?"
					}
					raise(e)
				}

				if *id in ["add", "sub"] {
					mut first_element_raw := ""
					mut second_element_raw := ""
					mut var_priority := 0
					if (*value).contains(",") {
						first_element_raw = value.split(",")[0]
						second_element_raw = value.split(",")[1]
					} else {
						e := &Exception{
							msg: "Invalid usage"
							source: token.source
							line: token.line+1
							hint: ".add expects two values separated with a ','\n" +
								  "Example: .add x,1"
						}
						raise(e)
					}
						/*
						Example:
							mov ax, [my_variable] ; Move the value of my_variable into AX register
						    add ax, 10           ; Add 10 to the value in AX
						    mov [my_variable], ax ; Move the result from AX back to my_variable
						*/

					if is_numeric(first_element_raw) {
						text << "\tmov ax, ${first_element_raw}\n"
						var_priority = 2
					} else {
						if !(first_element_raw in variables) {
							e := &Exception{
								msg: "Unknown variable"
								source: token.source
								line: token.line+1
								hint: "No such variable '${first_element_raw}'\n" +
									  "Perhaps it's not declared?"
							}
							raise(e)
						}
						if !(variables[first_element_raw].@type in [
							Types.integer,
							Types.i8, Types.i16, Types.i32, Types.i64
						]) {
							e := &Exception{
								msg: "Invalid item for mathematical operations"
								source: token.source
								line: token.line+1
								hint: "Variable '${first_element_raw}' is not of type int\n" +
									  "Only integers can be used"
							}
							raise(e)
						}
						text << "\tmov ax, [${first_element_raw}]\n"
						var_priority = 1
					}

					if is_numeric(second_element_raw) {
						text << "\t${*id} ax, ${second_element_raw}\n"
						var_priority = 1
					} else {
						if !(second_element_raw in variables) {
							e := &Exception{
								msg: "Unknown variable"
								source: token.source
								line: token.line+1
								hint: "No such variable '${second_element_raw}'\n" +
									  "Perhaps it's not declared?"
							}
							raise(e)
						}
						if !(variables[second_element_raw].@type in [
							Types.integer,
							Types.i8, Types.i16, Types.i32, Types.i64
						]) {
							e := &Exception{
								msg: "Invalid item for mathematical operations"
								source: token.source
								line: token.line+1
								hint: "Variable '${first_element_raw}' is not of type int\n" +
									  "Only integers can be used"
							}
							raise(e)
						}
						text << "\t${*id} ax, [${second_element_raw}]\n"
						var_priority = 2
					}

					if var_priority == 1 {
						text << "\tmov [${first_element_raw}], ax\n"
					} else if var_priority == 2 {
						text << "\tmov [${second_element_raw}], ax\n"
					} else {
						e := &Exception{
							msg: "Invalid addition target"
							source: token.source
							line: token.line+1
							hint: "This token was never constructed\n" +
								  "Perhaps the lexer branch for this type is incomplete?"
						}
						raise(e)
					}
				}

				// Add our data
				// Example:
				//		mov rsi, output
    			//		mov rdx, output_len + input

				// output override
				else if *id == "output" {
					if !(*value in variables) {
						e := &Exception{
							msg: "Unknown variable"
							source: token.source
							line: token.line+1
							hint: "Calling a function '${*id}' with unknown variable '${*value}'\n" +
								  "Perhaps it's not declared?"
						}
						raise(e)
					} 
				
					if variables[*value].@type != Types.buffer {
						e := &Exception{
							msg: "Invalid type"
							source: token.source
							line: token.line+1
							hint: "Function 'output' takes a buffer but '${*value}' is of type ${variables[*value].@type}"
						}
						raise(e)
					}

					text << "\tmov rsi, ${*value}\n"
					text << "\tmov rdx, ${*value}_len\n"
				}

				else if *id == "input" {
					if !(*value in variables) {
						e := &Exception{
							msg: "Unknown variable"
							source: token.source
							line: token.line+1
							hint: "Calling a function '${*id}' with unknown variable '${*value}'\n" +
								  "Perhaps it's not declared?"
						}
						raise(e)
					} 

					if variables[*value].@type != Types.buffer {
						e := &Exception{
							msg: "Invalid type"
							source: token.source
							line: token.line+1
							hint: "Function 'input' takes a buffer but '${*value}' is of type ${variables[*value].@type}"
						}
						raise(e)
					}

					text << "\tlea rsi, [${*value}]\n"
					text << "\tmov rdx, 16\n"
				}

				else if *id == "clear_buff" {
					if !(*value in variables) {
						e := &Exception{
							msg: "Unknown variable"
							source: token.source
							line: token.line+1
							hint: "Calling a function '${*id}' with unknown variable '${*value}'\n" +
								  "Perhaps it's not declared?"
						}
						raise(e)
					} 

					if variables[*value].@type != Types.buffer {
						e := &Exception{
							msg: "Invalid type"
							source: token.source
							line: token.line+1
							hint: "Function 'clear_buff' takes a buffer but '${*value}' is of type ${variables[*value].@type}"
						}
						raise(e)
					}

					/*
					Example:
						mov edi, f     ; Set the destination address (f)
	    				mov ecx, f_len ; Set the number of bytes to clear (f_len)
	    				xor al, al     ; Set the value to zero
	    				cld            ; Clear the direction flag (forward movement)
	    				rep stosb      ; Store zero in the buffer
					*/
					text << "\tmov edi, ${*value}\n"
					text << "\tmov ecx, ${*value}_len\n"
					text << "\txor al, al\n" +
							"\tcld\n" +
							"\trep stosb\n"

					buffers[*id] = []
				}

				for c in call {
					text << "$c\n"
				}

			}
			.@none {
				e := &Exception{
					msg: "Token empty"
					source: token.source
					line: token.line+1
					hint: "This token was never constructed\n" +
						  "Perhaps the lexer branch for this type is incomplete?"
				}
				raise(e)
			}
			else {
				e := &Exception{
					msg: "Not implemented"
					source: token.source
					line: token.line+1
					hint: "Not implemented"
				}
				raise(e)
			}
		}
	}
}

fn lextokens(clean_code []string, record_flag bool, debug bool, lineoverride int) []&Token {
	// Start translation
	mut complete := []&Token{}
	mut ifdepth  := 0
	mut recorded := []&Token

	for line, chunk in clean_code {
		mut token := &Token{
			@type: TokenTypes.@none
			line: line+lineoverride
			source: chunk
		}
		
		if debug {
			if record_flag {
				println("\x1b[35;43;1m$line\x1b[0m -> $chunk\x1b[0m")
			} else {
				println("\x1b[37;42;1m$line\x1b[0m -> $chunk\x1b[0m")
			}
		}
		
		if chunk.len == 0 {
			continue
		} 

		else if chunk[0..2] == "//" {
			continue
		}

		else if chunk[0..2] == "if" {
			mut proc_head := chunk.split('(')[1].split(')')[0]

			newtokens := lextokens(clean_code[line+1..], true, debug, line+1)

			token = &Token{
				id: "iftree_${ifdepth}"
				value: proc_head
				source: chunk
				line: line+lineoverride
				@type: TokenTypes.conditional
				extra: newtokens
			}

			ifdepth++
		}

		else if  chunk[0..2] == "fi" {
			if debug {println("Done recording")}
			if record_flag {return complete} else {continue}
		}

		else if chunk.len >= 4 && chunk[0..4] == "else" {

			newtokens := lextokens(clean_code[line+1..], true, debug, line+1)

			token = &Token{
				id: "elsetree_${ifdepth-1}"
				value: ""
				source: chunk
				line: line+lineoverride
				@type: TokenTypes.conditional
				extra: newtokens
			}
		}

		else if chunk.len >= 4 && chunk[0..4] == "esle" {
			if debug {println("Done recording")}
			if record_flag {return complete} else {continue}
		}

		else if chunk.contains("<<") {
			// Found a buffer manipulation
			if chunk.split("<<").len < 2 {
				e := &Exception{
					msg: "Incomplete declaration"
					source: chunk
					line: line+lineoverride
					hint: "Make sure that the declaration follows the format\n" +
						  "Example > buffer<<var"
				}
				raise(e)
			}

			mut id := chunk.split("<<")[0]
			mut value := chunk.split("<<")[1]

			token = &Token{
				id: id
				line: line+lineoverride
				@type: TokenTypes.action
				source: chunk
				valtype: Types.ident
				value: value
			}
		}

		else if chunk[0] == `.` {
			// Found a call
			if chunk.split(" ").len < 2 {
				e := &Exception{
					msg: "Incomplete declaration"
					source: chunk
					line: line+lineoverride
					hint: "Make sure that the declaration follows the format\n" +
						  "Example > .output buffer"
				}
				raise(e)
			}

			mut id := chunk.split(" ")[0]
			mut value := chunk.split(" ")[1]

			token = &Token{
				id: id
				line: line+lineoverride
				@type: TokenTypes.function
				source: chunk
				valtype: Types.ident
				value: value
			}
		}
		
		else if chunk.contains(" ") && chunk.split(" ")[0].contains(":") {
			// Call to create something
			// Let's check the type and id
			mut id := chunk.split(" ")[0].split(":")[0]
			mut @type := chunk.split(" ")[0].split(":")[1]
			_, mut value := chunk.split_once(" ")
			mut tflag := Flags.@none

			// flag
			// if chunk.split(" ").len == 3 {
			// 	match chunk.split(" ")[2] {
			// 		"const" {
			// 			tflag = Flags.@const
			// 		}

			// 		else {
			// 			e := &Exception{
			// 				msg: "Unknown flag"
			// 				source: chunk
			// 				line: line+lineoverride
			// 				hint: "Does this flag exist?\n" +
			// 					  "Known flags: 'const'"
			// 			}
			// 			raise(e)
			// 		}
			// 	}
			// }

			if id.len == 0 || @type.len == 0 {
				e := &Exception{
					msg: "Incomplete declaration"
					source: chunk
					line: line+lineoverride
					hint: "Make sure that the declaration follows the format\n" +
						  "Example > x:int 2"
				}
				raise(e)
			}

			token = &Token{
				id: id
				line: line+lineoverride
				@type: TokenTypes.variable
				flag: tflag
				source: chunk
				valtype: match @type {
					"string" {Types.str}
					"i8" {Types.i8}
					"i16" {Types.i16}
					"i32" {Types.i32}
					"i64" {Types.i64}
					"int" {Types.integer}
					"buffer" {Types.buffer}
					else {
						e := &Exception{
							msg: "Unknown type ${@type}"
							source: chunk
							line: line+lineoverride
							hint: "No type '${@type}' exists. Is it spelt correctly?"
						}
						raise(e)
						Types.@none
					}
				}
				value: value
			}
		} else {
			e := &Exception{
				msg: "Unknown statement"
				source: chunk
				line: line+lineoverride
				hint: "Refer to the guidebook for language documentation"
			}
			raise(e)
		}

		complete << token
	}

	return complete
}

fn ensure_dep(dep string) bool {
	if os.exists_in_system_path(dep) {
		return true
	} else {
		e := &Exception{
			msg: "Missing dependency ${dep}"
			source: dep
			line: 0
			hint: "Refer to the guidebook for language documentation"
		}
		raise(e)
	}
	return false
}