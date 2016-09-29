//
//  Intel8080InstructionSet.swift
//  Assembler
//
//  Created by Ulrik Damm on 28/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

public struct Intel8080InstructionSet : InstructionSet {
	public init() {
		
	}
	
	public func assembleInstruction(instruction : Instruction) throws -> [Opcode] {
		switch instruction.mnemonic {
		case "nop": try instruction.getNoOperands(); return [.byte(0x00)]
		case "lxi":
			switch try instruction.getTwoOperands() {
			case (.constant("b"), let value): return try [.byte(0x01)] + value.uint16Opcode()
			case (.constant("d"), let value): return try [.byte(0x11)] + value.uint16Opcode()
			case (.constant("h"), let value): return try [.byte(0x21)] + value.uint16Opcode()
			case (.constant("sp"), let value): return try [.byte(0x31)] + value.uint16Opcode()
			case (let target, _): throw ErrorMessage("Invalid LXI target `\(target)`")
			}
		case "stax":
			switch try instruction.getSingleOperand() {
			case .constant("b"): return [.byte(0x02)]
			case .constant("d"): return [.byte(0x12)]
			case let target: throw ErrorMessage("Invalid STAX target: `\(target)`")
			}
		case "shld":
			let target = try instruction.getSingleOperand()
			return try [.byte(0x22)] + target.uint16Opcode()
		case "sta":
			let target = try instruction.getSingleOperand()
			return try [.byte(0x32)] + target.uint16Opcode()
		case "inx":
			switch try instruction.getSingleOperand() {
			case .constant("b"): return [.byte(0x03)]
			case .constant("d"): return [.byte(0x13)]
			case .constant("h"): return [.byte(0x23)]
			case .constant("sp"): return [.byte(0x33)]
			case let target: throw ErrorMessage("Invalid INX target `\(target)`")
			}
		case "inr":
			switch try instruction.getSingleOperand() {
			case .constant("b"): return [.byte(0x04)]
			case .constant("d"): return [.byte(0x14)]
			case .constant("h"): return [.byte(0x24)]
			case .constant("m"): return [.byte(0x34)]
			case .constant("c"): return [.byte(0x0c)]
			case .constant("e"): return [.byte(0x1c)]
			case .constant("l"): return [.byte(0x2c)]
			case .constant("a"): return [.byte(0x3c)]
			case let target: throw ErrorMessage("Invalid INR target `\(target)`")
			}
		case "dcr":
			switch try instruction.getSingleOperand() {
			case .constant("b"): return [.byte(0x05)]
			case .constant("d"): return [.byte(0x15)]
			case .constant("h"): return [.byte(0x25)]
			case .constant("m"): return [.byte(0x35)]
			case .constant("c"): return [.byte(0x0d)]
			case .constant("e"): return [.byte(0x1d)]
			case .constant("l"): return [.byte(0x2d)]
			case .constant("a"): return [.byte(0x3d)]
			case let target: throw ErrorMessage("Invalid DCR target `\(target)`")
			}
		case "mvi":
			switch try instruction.getTwoOperands() {
			case (.constant("b"), let value): return try [.byte(0x06), value.uint8Opcode()]
			case (.constant("d"), let value): return try [.byte(0x16), value.uint8Opcode()]
			case (.constant("h"), let value): return try [.byte(0x26), value.uint8Opcode()]
			case (.constant("m"), let value): return try [.byte(0x36), value.uint8Opcode()]
			case (.constant("c"), let value): return try [.byte(0x0e), value.uint8Opcode()]
			case (.constant("e"), let value): return try [.byte(0x1e), value.uint8Opcode()]
			case (.constant("l"), let value): return try [.byte(0x2e), value.uint8Opcode()]
			case (.constant("a"), let value): return try [.byte(0x3e), value.uint8Opcode()]
			case (let target, _): throw ErrorMessage("Invalid MVI target `\(target)`")
			}
		case "rlc": try instruction.getNoOperands(); return [.byte(0x07)]
		case "ral":  try instruction.getNoOperands(); return [.byte(0x17)]
		case "daa":  try instruction.getNoOperands(); return [.byte(0x27)]
		case "stc":  try instruction.getNoOperands(); return [.byte(0x37)]
		case "dad":
			switch try instruction.getSingleOperand() {
			case .constant("b"): return [.byte(0x09)]
			case .constant("d"): return [.byte(0x19)]
			case .constant("h"): return [.byte(0x29)]
			case .constant("sp"): return [.byte(0x39)]
			case let target: throw ErrorMessage("Invalid DAD target `\(target)`")
			}
		case "ldax":
			switch try instruction.getSingleOperand() {
			case .constant("b"): return [.byte(0x0a)]
			case .constant("d"): return [.byte(0x1a)]
			case let target: throw ErrorMessage("Invalid LDAX target `\(target)`")
			}
		case "lhld":
			let target = try instruction.getSingleOperand()
			return try [.byte(0x2a)] + target.uint16Opcode()
		case "lda":
			let target = try instruction.getSingleOperand()
			return try [.byte(0x3a)] + target.uint16Opcode()
		case "dcx":
			switch try instruction.getSingleOperand() {
			case .constant("b"): return [.byte(0x0b)]
			case .constant("d"): return [.byte(0x1b)]
			case .constant("h"): return [.byte(0x2b)]
			case .constant("sp"): return [.byte(0x3b)]
			case let target: throw ErrorMessage("Invalid DCX target `\(target)`")
			}
		case "rrc": try instruction.getNoOperands(); return [.byte(0x0f)]
		case "rar": try instruction.getNoOperands(); return [.byte(0x1f)]
		case "cma": try instruction.getNoOperands(); return [.byte(0x2f)]
		case "cmc": try instruction.getNoOperands(); return [.byte(0x3f)]
		case "mov":
			let (lhs, rhs) = try instruction.getTwoOperands()
			let target = try registerIndex(register: lhs)
			let source = try registerIndex(register: rhs)
			let opcode = 0b01_000_000 | (target << 3) | (source)
			guard opcode != 0x76 else { throw ErrorMessage("Can't MOV from M to M") }
			return [.byte(opcode)]
		case "hlt": try instruction.getNoOperands(); return [.byte(0x76)]
		case "add":
			let operand = try instruction.getSingleOperand()
			let register = try registerIndex(register: operand)
			return [.byte(0x80 | register)]
		case "adc":
			let operand = try instruction.getSingleOperand()
			let register = try registerIndex(register: operand)
			return [.byte(0x88 | register)]
		case "sub":
			let operand = try instruction.getSingleOperand()
			let register = try registerIndex(register: operand)
			return [.byte(0x90 | register)]
		case "sbb":
			let operand = try instruction.getSingleOperand()
			let register = try registerIndex(register: operand)
			return [.byte(0x98 | register)]
		case "ana":
			let operand = try instruction.getSingleOperand()
			let register = try registerIndex(register: operand)
			return [.byte(0xa0 | register)]
		case "xra":
			let operand = try instruction.getSingleOperand()
			let register = try registerIndex(register: operand)
			return [.byte(0xa8 | register)]
		case "ora":
			let operand = try instruction.getSingleOperand()
			let register = try registerIndex(register: operand)
			return [.byte(0xb0 | register)]
		case "cmp":
			let operand = try instruction.getSingleOperand()
			let register = try registerIndex(register: operand)
			return [.byte(0xb8 | register)]
		case "rnz": try instruction.getNoOperands(); return [.byte(0xc0)]
		case "rnc": try instruction.getNoOperands(); return [.byte(0xd0)]
		case "rpo": try instruction.getNoOperands(); return [.byte(0xe0)]
		case "rp": try instruction.getNoOperands(); return [.byte(0xf0)]
		case "pop":
			switch try instruction.getSingleOperand() {
			case .constant("b"): return [.byte(0xc1)]
			case .constant("d"): return [.byte(0xd1)]
			case .constant("h"): return [.byte(0xe1)]
			case .constant("psw"): return [.byte(0xf1)]
			case let target: throw ErrorMessage("Can't POP to `\(target)`") 
			}
		case "jnz":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xc2)] + target.uint16Opcode()
		case "jnc":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xd2)] + target.uint16Opcode()
		case "jpo":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xe2)] + target.uint16Opcode()
		case "jp":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xf2)] + target.uint16Opcode()
		case "jmp":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xc3)] + target.uint16Opcode()
		case "out":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xd3), target.uint8Opcode()]
		case "xthl": try instruction.getNoOperands(); return [.byte(0xe3)]
		case "di": try instruction.getNoOperands(); return [.byte(0xf3)]
		case "cnz":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xc4), target.uint8Opcode()]
		case "cnc":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xd4), target.uint8Opcode()]
		case "cpo":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xe4), target.uint8Opcode()]
		case "cp":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xf4), target.uint8Opcode()]
		case "push":
			switch try instruction.getSingleOperand() {
			case .constant("b"): return [.byte(0xc5)]
			case .constant("d"): return [.byte(0xd5)]
			case .constant("h"): return [.byte(0xe5)]
			case .constant("psw"): return [.byte(0xf5)]
			case let target: throw ErrorMessage("Can't PUSH `\(target)`") 
			}
		case "adi":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xc6), target.uint8Opcode()]
		case "sui":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xd6), target.uint8Opcode()]
		case "ani":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xe6), target.uint8Opcode()]
		case "ori":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xf6), target.uint8Opcode()]
		case "rst":
			switch try instruction.getSingleOperand() {
			case .value(0): return [.byte(0xc7)]
			case .value(2): return [.byte(0xd7)]
			case .value(4): return [.byte(0xe7)]
			case .value(6): return [.byte(0xf7)]
			case .value(1): return [.byte(0xcf)]
			case .value(3): return [.byte(0xdf)]
			case .value(5): return [.byte(0xef)]
			case .value(7): return [.byte(0xff)]
			case let target: throw ErrorMessage("Can't RST to `\(target)`")
			}
		case "rz": try instruction.getNoOperands(); return [.byte(0xc8)]
		case "rc": try instruction.getNoOperands(); return [.byte(0xd8)]
		case "rpe": try instruction.getNoOperands(); return [.byte(0xe8)]
		case "rm": try instruction.getNoOperands(); return [.byte(0xf8)]
		case "ret": try instruction.getNoOperands(); return [.byte(0xc9)]
		case "pchl": try instruction.getNoOperands(); return [.byte(0xe9)]
		case "sphl": try instruction.getNoOperands(); return [.byte(0xf9)]
		case "jz":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xca)] + target.uint16Opcode()
		case "jc":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xda)] + target.uint16Opcode()
		case "jpe":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xea)] + target.uint16Opcode()
		case "jm":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xfa)] + target.uint16Opcode()
		case "in":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xdb)] + target.uint16Opcode()
		case "xchg": try instruction.getNoOperands(); return [.byte(0xeb)]
		case "ei": try instruction.getNoOperands(); return [.byte(0xfb)]
		case "cz":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xcc)] + target.uint16Opcode()
		case "cc":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xdc)] + target.uint16Opcode()
		case "cpe":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xec)] + target.uint16Opcode()
		case "cm":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xfc)] + target.uint16Opcode()
		case "call":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xcd)] + target.uint16Opcode()
		case "aci":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xce), target.uint8Opcode()]
		case "sbi":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xde), target.uint8Opcode()]
		case "xri":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xee), target.uint8Opcode()]
		case "cpi":
			let target = try instruction.getSingleOperand()
			return try [.byte(0xfe), target.uint8Opcode()]
		case "db":
			return try assembleDb(instruction)
		case _: throw ErrorMessage("Unknown instruction `\(instruction.mnemonic)`")
		}
	}
	
	func registerIndex(register : Expression) throws -> UInt8 {
		switch register {
		case .constant("b"): return 0b000
		case .constant("c"): return 0b001
		case .constant("d"): return 0b010
		case .constant("e"): return 0b011
		case .constant("h"): return 0b100
		case .constant("l"): return 0b101
		case .constant("m"): return 0b110
		case .constant("a"): return 0b111
		case .constant(let name): throw ErrorMessage("Invalid register `\(name)`")
		case let expr: throw ErrorMessage("Invalid operand value `\(expr)`")
		}
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
}
