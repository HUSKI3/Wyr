module wyr

// IrProgram is the in-memory bundle of a parsed Wyr module (IR surface + version).
pub struct IrProgram {
pub:
	version int
	tokens  []&Token
}

pub fn bundle_ir(header IrModuleHeader, tokens []&Token) IrProgram {
	return IrProgram{
		version: header.version
		tokens:  tokens
	}
}
