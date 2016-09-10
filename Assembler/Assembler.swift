//
//  Assembler.swift
//  Assembler
//
//  Created by Ulrik Damm on 08/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

struct Assembler {
	let constants : [String: Expression]
	
	init(constants : [String: Expression]) {
		var c : [String: Expression] = [:]
		
		for (key, value) in constants {
			c[key.lowercased()] = value
		}
		
		self.constants = c
	}
	
	func expandExpressionConstants(expression : Expression, constantStack : [String] = []) throws -> Expression {
		let lowercased = expression.mapSubExpressions { (expr) -> Expression in
			switch expr {
			case .constant(let str): return .constant(str.lowercased())
			case _: return expr
			}
		}
		
		let newExpression = try lowercased.mapSubExpressions { expr throws -> Expression in
			if case .constant(let str) = expr, let value = self.constants[str] {
				guard !constantStack.contains(str) else {
					throw ErrorMessage("Cannot recursively expand constants")
				}
				return try self.expandExpressionConstants(expression: value, constantStack: constantStack + [str])
			} else {
				return expr
			}
		}
		
		return newExpression.reduce()
	}
	
	func assembleLogicOperation(_ instruction : Instruction, mask : UInt8, directOpcode : UInt8) throws -> [Opcode] {
		let operand = try getSingleOperand(instruction: instruction)
		
		if case .value(let n) = operand {
			guard (0...0xff).contains(n) else { throw ErrorMessage("Value of out byte range") }
			return [.byte(directOpcode), .byte(UInt8(n))]
		} else {
			let regValue = try getRegister8Value(operand: operand)
			return [.byte(mask | regValue)]
		}
	}
	
	func assembleArithmeticOperation(_ instruction : Instruction, mask : UInt8, directOpcode : UInt8) throws -> [Opcode] {
		let (operandA, operandR) = try getTwoOperands(instruction: instruction)
		guard case .constant("a") = operandA else { throw ErrorMessage("Can only be register A") }
		
		if case .value(let n) = operandR {
			guard (0...0xff).contains(n) else { throw ErrorMessage("Value of out byte range") }
			return [.byte(directOpcode), .byte(UInt8(n))]
		} else {
			let regValue = try getRegister8Value(operand: operandR)
			return [.byte(mask | regValue)]
		}
	}
	
	func assembleBitOperation(_ instruction : Instruction, mask : UInt8) throws -> [Opcode] {
		let (bitOperand, registerOperand) = try getTwoOperands(instruction: instruction)
		let regValue = try getRegister8Value(operand: registerOperand)
		guard case .value(let bit) = bitOperand else { throw ErrorMessage("Invalid bit value") }
		guard (0..<8).contains(bit) else { throw ErrorMessage("Bit value out of range") }
		return [.byte(0xcb), .byte(mask | (UInt8(bit) << 3) | regValue)]
	}
	
	func assembleCBOperation(_ instruction : Instruction, mask : UInt8) throws -> [Opcode] {
		let operand = try getSingleOperand(instruction: instruction)
		let regValue = try getRegister8Value(operand: operand)
		return [.byte(0xcb), .byte(mask | regValue)]
	}
	
	func assembleJp(_ instruction : Instruction, call : Bool) throws -> [Opcode] {
		if let (conditionOperand, labelOperand) = try? getTwoOperands(instruction: instruction) {
			let condition = try getLabelValue(operand: conditionOperand)
			let target : [Opcode]
			
			switch labelOperand {
			case .constant(let labelName): target = [.label(labelName)]
			case .value(let n): target = try Opcode.bytesFrom16bit(n)
			case _: throw ErrorMessage("Invalid jump target")
			}
			
			let jpOpcode : UInt8
			switch condition {
			case "z": jpOpcode = (call ? 0xcc : 0xca)
			case "nz": jpOpcode = (call ? 0xc4 : 0xc2)
			case "c": jpOpcode = (call ? 0xdc : 0xda)
			case "nc": jpOpcode = (call ? 0xd4 : 0xd2)
			case _: throw ErrorMessage("Invalid condition ’\(condition)‘")
			}
			
			return [.byte(jpOpcode)] + target
		} else {
			let labelOperand = try getSingleOperand(instruction: instruction)
			
			switch labelOperand {
			case .constant("hl"):
				guard !call else { throw ErrorMessage("Invalid call operand") }
				return [.byte(0xe9)]
			case .constant(let label): return [.byte(call ? 0xcd : 0xc3), .label(label)]
			case .value(let n): return try [.byte(call ? 0xcd : 0xc3)] + Opcode.bytesFrom16bit(n)
			case _: throw ErrorMessage("Invalid jump target")
			}
		}
	}
	
	func assembleRet(_ instruction : Instruction) throws -> [Opcode] {
		let opcode : UInt8
		
		if let operand = try? getSingleOperand(instruction: instruction) {
			switch operand {
			case .constant("z"): opcode = 0xc8
			case .constant("nz"): opcode = 0xc0
			case .constant("c"): opcode = 0xd8
			case .constant("nc"): opcode = 0xd0
			case _: throw ErrorMessage("Invalid condition ’\(operand)‘")
			}
		} else if let _ = try? getNoOperands(instruction: instruction) {
			opcode = 0xc9
		} else {
			throw ErrorMessage("Ret takes zero or one operand")
		}
		
		return [.byte(opcode)]
	}
	
	func assembleRst(_ instruction : Instruction) throws -> [Opcode] {
		switch try getSingleOperand(instruction: instruction) {
		case .value(0x00): return [.byte(0xc7)]
		case .value(0x08): return [.byte(0xcf)]
		case .value(0x10): return [.byte(0xd7)]
		case .value(0x18): return [.byte(0xdf)]
		case .value(0x20): return [.byte(0xe7)]
		case .value(0x28): return [.byte(0xef)]
		case .value(0x30): return [.byte(0xf7)]
		case .value(0x38): return [.byte(0xff)]
		case .value(_): throw ErrorMessage("Unsupported reset target")
		case _: throw ErrorMessage("Invalid reset target")
		}
	}
	
	func assemblePush(_ instruction : Instruction) throws -> [Opcode] {
		let opcode : UInt8
		switch try getSingleOperand(instruction: instruction) {
		case .constant("af"): opcode = 0xf5
		case .constant("bc"): opcode = 0xc5
		case .constant("de"): opcode = 0xd5
		case .constant("hl"): opcode = 0xe5
		case _: throw ErrorMessage("Invalid operand for push")
		}
		return [.byte(opcode)]
	}
	
	func assemblePop(_ instruction : Instruction) throws -> [Opcode] {
		let opcode : UInt8
		switch try getSingleOperand(instruction: instruction) {
		case .constant("af"): opcode = 0xf1
		case .constant("bc"): opcode = 0xc1
		case .constant("de"): opcode = 0xd1
		case .constant("hl"): opcode = 0xe1
			case _: throw ErrorMessage("Invalid operand for pop")
		}
		return [.byte(opcode)]
	}
	
	func assembleDb(_ instruction : Instruction) throws -> [Opcode] {
		let operands = try getAtLeastOneOperand(instruction: instruction)
		
		var bytes : [Opcode] = []
		for operand in operands {
			switch operand {
			case .value(let n) where (0...0xff).contains(n):
				bytes.append(.byte(UInt8(n)))
			case .string(let string):
				for scalar in string.unicodeScalars {
					guard scalar.isASCII else {
						throw ErrorMessage("Only ASCII supported")
					}
					bytes.append(.byte(UInt8(scalar.value)))
				}
			default: throw ErrorMessage("Expected direct value")
			}
		}
		
		return bytes
	}
	
	func assembleDec(_ instruction : Instruction) throws -> [Opcode] {
		let operand = try getSingleOperand(instruction: instruction)
		let opcode : UInt8
		
		if let register = try? getRegister8Value(operand: operand) {
			opcode = 0b00_000_101 | (register << 3)
		} else if case .constant(let c) = operand {
			switch c {
			case "bc": opcode = 0x0b
			case "de": opcode = 0x1b
			case "hl": opcode = 0x2b
			case "sp": opcode = 0x3b
			case _: throw ErrorMessage("Unsupported register")
			}
		} else {
			throw ErrorMessage("Invalid operand")
		}
		
		return [.byte(opcode)]
	}
	
	func assembleInc(_ instruction : Instruction) throws -> [Opcode] {
		let operand = try getSingleOperand(instruction: instruction)
		let opcode : UInt8
		
		if let register = try? getRegister8Value(operand: operand) {
			opcode = 0b00_000_100 | (register << 3)
		} else if case .constant(let c) = operand {
			switch c {
			case "bc": opcode = 0x03
			case "de": opcode = 0x13
			case "hl": opcode = 0x23
			case "sp": opcode = 0x33
			case _: throw ErrorMessage("Unsupported register")
			}
		} else {
			throw ErrorMessage("Invalid operand")
		}
		
		return [.byte(opcode)]
	}
	
	func assembleLd(_ instruction : Instruction) throws -> [Opcode] {
		let (to, from) = try getTwoOperands(instruction: instruction)
		
		if let toReg = try? getRegister8Value(operand: to) {
			if let fromReg = try? getRegister8Value(operand: from) {
				if fromReg == 6 && toReg == 6 { throw ErrorMessage("Cannot load between (HL) and (HL)") }
				return [.byte(0x40 | (toReg << 3) | fromReg)]
			}
			
			switch from {
			case .value(let n):
				guard (0...0xff).contains(n) else { throw ErrorMessage("Value of out range for one byte") }
				return [.byte(0x06 | (toReg << 3)), .byte(UInt8(n))]
			case .parens(.constant("bc")): return [.byte(0x0a)]
			case .parens(.constant("de")): return [.byte(0x1a)]
			case _: throw ErrorMessage("Invalid load source: \(from))") 
			}
		} else {
			switch (to, from) {
			case (.parens(.constant("bc")), .constant("a")): return [.byte(0x02)]
			case (.parens(.constant("de")), .constant("a")): return [.byte(0x12)]
			case _: throw ErrorMessage("Invalid load from \(from) to \(to)")
			}
		}
	}
	
	func assembleSpecial(_ instruction : Instruction, result : [UInt8]) throws -> [Opcode] {
		try getNoOperands(instruction: instruction)
		return result.map { Opcode.byte($0) }
	}
	
	func assembleInstruction(instruction : Instruction) throws -> [Opcode] {
		do {
			switch instruction.mnemonic {
			case "xor": return try assembleLogicOperation(instruction, mask: 0xa8, directOpcode: 0xee)
			case "or": return try assembleLogicOperation(instruction, mask: 0xb0, directOpcode: 0xf6)
			case "and": return try assembleLogicOperation(instruction, mask: 0xa0, directOpcode: 0xe6)
			case "cp": return try assembleLogicOperation(instruction, mask: 0xb8, directOpcode: 0xfe)
				
			case "add": return try assembleArithmeticOperation(instruction, mask: 0x80, directOpcode: 0xc6)
			case "adc": return try assembleArithmeticOperation(instruction, mask: 0x88, directOpcode: 0xce)
			case "sub": return try assembleArithmeticOperation(instruction, mask: 0x90, directOpcode: 0xd6)
			case "sbc": return try assembleArithmeticOperation(instruction, mask: 0x98, directOpcode: 0xde)
				
			case "db": return try assembleDb(instruction)
			case "dec": return try assembleDec(instruction)
			case "inc": return try assembleInc(instruction)
			case "ld": return try assembleLd(instruction)
				
			case "jp": return try assembleJp(instruction, call: false)
			case "call": return try assembleJp(instruction, call: true)
			case "rst": return try assembleRst(instruction)
			case "ret": return try assembleRet(instruction)
				
			case "push": return try assemblePush(instruction)
			case "pop": return try assemblePop(instruction)
				
			case "bit": return try assembleBitOperation(instruction, mask: 0x40)
			case "set": return try assembleBitOperation(instruction, mask: 0xc0)
			case "res": return try assembleBitOperation(instruction, mask: 0x80)
				
			case "rlc": return try assembleCBOperation(instruction, mask: 0x00)
			case "rrc": return try assembleCBOperation(instruction, mask: 0x08)
			case "rl": return try assembleCBOperation(instruction, mask: 0x10)
			case "rr": return try assembleCBOperation(instruction, mask: 0x18)
			case "sla": return try assembleCBOperation(instruction, mask: 0x20)
			case "sra": return try assembleCBOperation(instruction, mask: 0x28)
			case "swap": return try assembleCBOperation(instruction, mask: 0x30)
			case "srl": return try assembleCBOperation(instruction, mask: 0x38)
				
			case "nop": return try assembleSpecial(instruction, result: [0x00])
			case "halt": return try assembleSpecial(instruction, result: [0x76])
			case "stop": return try assembleSpecial(instruction, result: [0x10, 0x00])
			case "di": return try assembleSpecial(instruction, result: [0xf3])
			case "ei": return try assembleSpecial(instruction, result: [0xfb])
			case "reti": return try assembleSpecial(instruction, result: [0xd9])
			case "rlca": return try assembleSpecial(instruction, result: [0x07])
			case "rla": return try assembleSpecial(instruction, result: [0x17])
			case "rrca": return try assembleSpecial(instruction, result: [0x0f])
			case "rra": return try assembleSpecial(instruction, result: [0x1f])
			case "daa": return try assembleSpecial(instruction, result: [0x27])
			case "cpl": return try assembleSpecial(instruction, result: [0x2f])
			case "ccf": return try assembleSpecial(instruction, result: [0x3f])
			case "scf": return try assembleSpecial(instruction, result: [0x37])
				
			case _: throw ErrorMessage("Unknown mnemonic \(instruction.mnemonic)")
			}
		} catch let error as ErrorMessage {
			throw ErrorMessage("Error assembling instruction `\(instruction)`: \(error.message)")
		} catch let error {
			throw error
		}
	}
	
	func getRegister8Value(operand : Expression) throws -> UInt8 {
		switch operand {
		case .constant("b"): return 0
		case .constant("c"): return 1
		case .constant("d"): return 2
		case .constant("e"): return 3
		case .constant("h"): return 4
		case .constant("l"): return 5
		case .parens(.constant("hl")): return 6
		case .constant("a"): return 7
		default: throw ErrorMessage("Not a valid register: \(operand)")
		}
	}
	
	func getLabelValue(operand : Expression) throws -> String {
		guard case .constant(let name) = operand else {
			throw ErrorMessage("Expected label")
		}
		
		return name
	}
	
	func getSingleOperand(instruction : Instruction) throws -> Expression {
		guard instruction.operands.count > 0 else {
			throw ErrorMessage("Missing operand")
		}
		
		guard instruction.operands.count == 1 else {
			throw ErrorMessage("Only one operand required")
		}
		
		return try expandExpressionConstants(expression: instruction.operands[0])
	}
	
	func getTwoOperands(instruction : Instruction) throws -> (Expression, Expression) {
		guard instruction.operands.count == 2 else {
			throw ErrorMessage("Missing operand")
		}
		
		return (
			try expandExpressionConstants(expression: instruction.operands[0]),
			try expandExpressionConstants(expression: instruction.operands[1])
		)
	}
	
	func getNoOperands(instruction : Instruction) throws {
		guard instruction.operands.count == 0 else {
			throw ErrorMessage("No operands required")
		}
	}
	
	func getAtLeastOneOperand(instruction : Instruction) throws -> [Expression] {
		guard instruction.operands.count > 0 else {
			throw ErrorMessage("Operands required")
		}
		
		return try instruction.operands.map { try expandExpressionConstants(expression: $0) }
	}
}
