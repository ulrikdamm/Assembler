//
//  GameboyInstructionSet.swift
//  Assembler
//
//  Created by Ulrik Damm on 27/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

public struct GameboyInstructionSet : InstructionSet {
	public init() {
		
	}
	
	func assembleLogicOperation(_ instruction : Instruction, mask : UInt8, directOpcode : UInt8) throws -> [Opcode] {
		let operand = try instruction.getSingleOperand()
		
		if let targetReg = try? getRegister8Value(operand: operand) {
			return [.byte(mask | targetReg)]
		} else {
			return [.byte(directOpcode), try operand.uint8Opcode()]
		}
	}
	
	func assembleAdd(_ instruction : Instruction) throws -> [Opcode] {
		let (operandLeft, operandRight) = try instruction.getTwoOperands()
		
		switch (operandLeft, operandRight) {
		case (.constant("a"), _): return try assembleArithmeticOperation(instruction, mask: 0x80, directOpcode: 0xc6)
		case (.constant("hl"), .constant("bc")): return [.byte(0x09)]
		case (.constant("hl"), .constant("de")): return [.byte(0x19)]
		case (.constant("hl"), .constant("hl")): return [.byte(0x29)]
		case (.constant("hl"), .constant("sp")): return [.byte(0x39)]
		case (.constant("sp"), .value(let n)):
			guard (-128...127).contains(n) else { throw ErrorMessage("Value outside of bounds for signed byte") }
			return [.byte(0xe8), .byte(UInt8(bitPattern: Int8(n)))]
		case (.constant(let left), .constant(let right)): throw ErrorMessage("Unable to add `\(left)` and `\(right)`")
		case _: throw ErrorMessage("Invalid operands to add")
		}
	}
	
	func assembleArithmeticOperation(_ instruction : Instruction, mask : UInt8, directOpcode : UInt8) throws -> [Opcode] {
		let (operandA, operandR) = try instruction.getTwoOperands()
		guard case .constant("a") = operandA else { throw ErrorMessage("Can only be register A") }
		
		if let targetReg = try? getRegister8Value(operand: operandR) {
			return [.byte(mask | targetReg)]
		} else {
			return [.byte(directOpcode), try operandR.uint8Opcode()]
		}
	}
	
	func assembleBitOperation(_ instruction : Instruction, mask : UInt8) throws -> [Opcode] {
		let (bitOperand, registerOperand) = try instruction.getTwoOperands()
		let regValue = try getRegister8Value(operand: registerOperand)
		guard case .value(let bit) = bitOperand else { throw ErrorMessage("Invalid bit value") }
		guard (0..<8).contains(bit) else { throw ErrorMessage("Bit value out of range") }
		return [.byte(0xcb), .byte(mask | (UInt8(bit) << 3) | regValue)]
	}
	
	func assembleCBOperation(_ instruction : Instruction, mask : UInt8) throws -> [Opcode] {
		let operand = try instruction.getSingleOperand()
		let regValue = try getRegister8Value(operand: operand)
		return [.byte(0xcb), .byte(mask | regValue)]
	}
	
	func assembleJp(_ instruction : Instruction, call : Bool) throws -> [Opcode] {
		if let (conditionOperand, labelOperand) = try? instruction.getTwoOperands() {
			let target = try labelOperand.uint16Opcode()
			
			let jpOpcode : UInt8
			switch conditionOperand {
			case .constant("z"): jpOpcode = (call ? 0xcc : 0xca)
			case .constant("nz"): jpOpcode = (call ? 0xc4 : 0xc2)
			case .constant("c"): jpOpcode = (call ? 0xdc : 0xda)
			case .constant("nc"): jpOpcode = (call ? 0xd4 : 0xd2)
			case _: throw ErrorMessage("Invalid condition ’\(conditionOperand)‘")
			}
			
			return [.byte(jpOpcode)] + target
		}
		
		let labelOperand = try instruction.getSingleOperand()
		
		switch labelOperand {
		case .constant("hl"):
			guard !call else { throw ErrorMessage("Invalid call operand") }
			return [.byte(0xe9)]
		case _:
			return try [.byte(call ? 0xcd : 0xc3)] + labelOperand.uint16Opcode()
		}
	}
	
	func assembleJr(_ instruction : Instruction) throws -> [Opcode] {
		let condition : Expression?
		let target : Expression
		
		if let (conditionOperand, labelOperand) = try? instruction.getTwoOperands() {
			condition = conditionOperand
			target = labelOperand
		} else {
			condition = nil
			target = try instruction.getSingleOperand()
		}
		
		let targetCode : Opcode
		let opcode : UInt8
		
		switch target {
		case .constant(let name):
			targetCode = .expression(.constant(name), .int8relative)
		case .value(let value):
			let s8 = try Int8.fromInt(value: value)
			targetCode = .byte(UInt8(bitPattern: s8))
		case _: throw ErrorMessage("Invalid jump target: `\(target)`")
		}
		
		switch condition {
		case .constant("z")?: opcode = 0x28
		case .constant("nz")?: opcode = 0x20
		case .constant("c")?: opcode = 0x38
		case .constant("nc")?: opcode = 0x30
		case nil: opcode = 0x18
		case _: throw ErrorMessage("Invalid condition ’\(condition)‘")
		}
		
		return [.byte(opcode), targetCode]
	}
	
	func assembleRet(_ instruction : Instruction) throws -> [Opcode] {
		let opcode : UInt8
		
		if let operand = try? instruction.getSingleOperand() {
			switch operand {
			case .constant("z"): opcode = 0xc8
			case .constant("nz"): opcode = 0xc0
			case .constant("c"): opcode = 0xd8
			case .constant("nc"): opcode = 0xd0
			case _: throw ErrorMessage("Invalid condition ’\(operand)‘")
			}
		} else if let _ = try? instruction.getNoOperands() {
			opcode = 0xc9
		} else {
			throw ErrorMessage("Ret takes zero or one operand")
		}
		
		return [.byte(opcode)]
	}
	
	func assembleRst(_ instruction : Instruction) throws -> [Opcode] {
		switch try instruction.getSingleOperand() {
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
		switch try instruction.getSingleOperand() {
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
		switch try instruction.getSingleOperand() {
		case .constant("af"): opcode = 0xf1
		case .constant("bc"): opcode = 0xc1
		case .constant("de"): opcode = 0xd1
		case .constant("hl"): opcode = 0xe1
		case _: throw ErrorMessage("Invalid operand for pop")
		}
		return [.byte(opcode)]
	}
	
	func assembleDb(_ instruction : Instruction) throws -> [Opcode] {
		let operands = try instruction.getAtLeastOneOperand()
		
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
			case _:
				try bytes.append(operand.uint8Opcode())
			}
		}
		
		return bytes
	}
	
	func assembleDec(_ instruction : Instruction) throws -> [Opcode] {
		let operand = try instruction.getSingleOperand()
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
		let operand = try instruction.getSingleOperand()
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
		let (to, from) = try instruction.getTwoOperands()
		
		switch (to, from) {
		case (.constant("a"), .squareParens(.constant("bc"))): return [.byte(0x0a)]
		case (.constant("a"), .squareParens(.constant("de"))): return [.byte(0x1a)]
		case (.constant("a"), .squareParens(.constant("hl"))): return [.byte(0x7e)]
		case (.squareParens(.constant("bc")), .constant("a")): return [.byte(0x02)]
		case (.squareParens(.constant("de")), .constant("a")): return [.byte(0x12)]
		case (.squareParens(.constant("hl")), .constant("a")): return [.byte(0x77)]
		case (.constant("a"), .squareParens(.binaryExpr(.value(0xff00), "+", .constant("c")))): return [.byte(0xf2)]
		case (.squareParens(.binaryExpr(.value(0xff00), "+", .constant("c"))), .constant("a")): return [.byte(0xe2)]
		case (.constant("sp"), .constant("hl")): return [.byte(0xf9)]
		case (.constant("hl"), .binaryExpr(.constant("sp"), "+", .value(let n))):
			let n8 = try Int8.fromInt(value: n)
			return [.byte(0xf8), .byte(UInt8(bitPattern: n8))]
		case (.constant("hl"), .binaryExpr(.constant("sp"), "-", .value(let n))):
			let n8 = try Int8.fromInt(value: -n)
			return [.byte(0xf8), .byte(UInt8(bitPattern: n8))]
		case (.value(let n), .constant("sp")):
			let n16 = try UInt16.fromInt(value: n)
			return [.byte(0x08), .byte(n16.lsb), .byte(n16.msb)]
		case (.constant("a"), .squareParens(.suffix(.constant("hl"), "+"))): return [.byte(0x2a)]
		case (.constant("a"), .squareParens(.suffix(.constant("hl"), "-"))): return [.byte(0x3a)]
		case (.squareParens(.suffix(.constant("hl"), "+")), .constant("a")): return [.byte(0x22)]
		case (.squareParens(.suffix(.constant("hl"), "-")), .constant("a")): return [.byte(0x32)]
		case (.constant("bc"), let value): return try [.byte(0x01)] + value.uint16Opcode() 
		case (.constant("de"), let value): return try [.byte(0x11)] + value.uint16Opcode()
		case (.constant("hl"), let value): return try [.byte(0x21)] + value.uint16Opcode()
		case (.constant("sp"), let value):  return try [.byte(0x31)] + value.uint16Opcode()
		case (.constant("a"), .squareParens(.value(let n))) where n >= 0xff00:
			let n8 = try UInt16.fromInt(value: n).lsb
			return [.byte(0xf0), .byte(n8)]
		case (.squareParens(.value(let n)), .constant("a")) where n >= 0xff00:
			let n8 = try UInt16.fromInt(value: n).lsb
			return [.byte(0xe0), .byte(n8)]
		case (.constant("a"), .squareParens(let expr)):
			return try [.byte(0xfa)] + expr.uint16Opcode()
		case (.squareParens(let expr), .constant("a")):
			return try [.byte(0xea)] + expr.uint16Opcode()
		case _: break
		}
		
		if let toReg = try? getRegister8Value(operand: to) {
			if let fromReg = try? getRegister8Value(operand: from) {
				if fromReg == 6 && toReg == 6 { throw ErrorMessage("Cannot load between (HL) and (HL)") }
				return [.byte(0x40 | (toReg << 3) | fromReg)]
			}
			
			return [.byte(0x06 | (toReg << 3)), try from.uint8Opcode()]
		}
		
		throw ErrorMessage("Invalid load from \(from) to \(to)")
	}
	
	func assembleSpecial(_ instruction : Instruction, result : [UInt8]) throws -> [Opcode] {
		try instruction.getNoOperands()
		return result.map { Opcode.byte($0) }
	}
	
	public func assembleInstruction(instruction : Instruction) throws -> [Opcode] {
		do {
			switch instruction.mnemonic {
			case "xor": return try assembleLogicOperation(instruction, mask: 0xa8, directOpcode: 0xee)
			case "or": return try assembleLogicOperation(instruction, mask: 0xb0, directOpcode: 0xf6)
			case "and": return try assembleLogicOperation(instruction, mask: 0xa0, directOpcode: 0xe6)
			case "cp": return try assembleLogicOperation(instruction, mask: 0xb8, directOpcode: 0xfe)
				
			case "add": return try assembleAdd(instruction)
			case "adc": return try assembleArithmeticOperation(instruction, mask: 0x88, directOpcode: 0xce)
			case "sub": return try assembleArithmeticOperation(instruction, mask: 0x90, directOpcode: 0xd6)
			case "sbc": return try assembleArithmeticOperation(instruction, mask: 0x98, directOpcode: 0xde)
				
			case "db": return try assembleDb(instruction)
			case "dec": return try assembleDec(instruction)
			case "inc": return try assembleInc(instruction)
			case "ld": return try assembleLd(instruction)
				
			case "jp": return try assembleJp(instruction, call: false)
			case "jr": return try assembleJr(instruction)
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
			throw ErrorMessage("Error assembling instruction on line \(instruction.line) `\(instruction)`: \(error.message)")
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
		case .squareParens(.constant("hl")): return 6
		case .constant("a"): return 7
		default: throw ErrorMessage("Not a valid register: \(operand)")
		}
	}
}
