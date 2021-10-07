//
//  Disassembler.swift
//  Assembler
//
//  Created by Ulrik Damm on 06/07/2018.
//  Copyright © 2018 Ufd.dk. All rights reserved.
//

import Foundation

let boundsError = "Unexpected end of data"

extension Array {
	mutating func safeRemove(at : Int) -> Element? {
		guard at < count else { return nil }
		return remove(at: at)
	}
	
	mutating func remove(at : Int, or error : String) -> Element {
		guard at < count else { fatalError(error) }
		return remove(at: at)
	}
	
	func get(_ at : Int) -> Element? {
		guard at < count else { return nil }
		return self[at]
	}
}

extension Array where Element == UInt8 {
	mutating func getUInt8Expression() -> Expression {
		let byte = remove(at: 0, or: boundsError)
		return .value(Int(byte))
	}
	
	mutating func getInt8Expression() -> Expression {
		let byte = remove(at: 0, or: boundsError)
		let signedByte = Int8(bitPattern: byte)
		return .value(Int(signedByte))
	}
	
	mutating func getUInt16Expression() -> Expression {
		let lsb = UInt16(remove(at: 0, or: boundsError))
		let msb = UInt16(remove(at: 0, or: boundsError))
		return .value(Int((msb << 8) | lsb))
	}
}

class Disassembler {
	func disassemble(file url : URL) throws {
		let bytes = try Data(contentsOf: url)
		let instructions = disassemble(data: Array(bytes))
		let labels = labelsFromInstructionList(instructions: instructions)
		let finalSource = labels.map { $0.description }.joined(separator: "\n\n")
		print(finalSource)
	}
	
	func labelsFromInstructionList(instructions : [(Instruction, offset : Int)]) -> [Label] {
		var jumpTargets : [UInt16] = [0x100]
		var labels : [Label] = []
		
		var i = 0
		while let target = jumpTargets.get(i) {
			i += 1
			
			var instructionIndex = 0
			
			for (index, instruction) in instructions.enumerated() {
				if target == instruction.offset { instructionIndex = index; break }
			}
			
			let length = getBlockLength(in: instructions, startingAt: instructionIndex, jumpTargets: &jumpTargets)
			
			let blockName = "label_\(String(target, radix: 16))"
			let blockInstructions = Array(instructions[instructionIndex ..< instructionIndex + length]).map { $0.0 }
            let label = Label(identifier: blockName, parent: nil, instructions: blockInstructions, options: ["org": .value(Int(target))])
			labels.append(label)
		}
		
		return labels
	}
	
	func getBlockLength(in instructions : [(Instruction, offset : Int)], startingAt index : Int, jumpTargets : inout [UInt16]) -> Int {
		var count = 0
		while let instructionAndOffset = instructions.get(index + count) {
			let instruction = instructionAndOffset.0
			
			if let jumpTarget = jumpTarget(for: instruction, withOffset: index + count) {
				if !jumpTargets.contains(jumpTarget) { jumpTargets.append(jumpTarget) }
			}
			
			count += 1
			guard continuesExecutionAfterInstruction(instruction) else { break }
		}
		
		return count
	}
	
	func jumpTarget(for instruction : Instruction, withOffset offset : Int) -> UInt16? {
		switch (instruction.mnemonic, instruction.operands.get(0), instruction.operands.get(1)) {
		case ("jp", .value(let int)?, nil): return UInt16(int)
		case ("jp", .constant(_)?, .value(let int)?): return UInt16(int)
		case ("jp", .squareParens(.constant("HL"))?, nil): return nil // ¯\_(ツ)_/¯
		case ("jr", .value(let int)?, nil): return UInt16(offset + int)
		case ("jr", .constant(_)?, .value(let int)?): return UInt16(offset + int)
		case ("call", .value(let int)?, nil): return UInt16(int)
		case ("call", .constant(_)?, .value(let int)?): return UInt16(int)	
		case _: return nil
		}
	}
	
	func continuesExecutionAfterInstruction(_ instruction : Instruction) -> Bool {
		switch instruction.mnemonic {
		case "ret": return false
		case "reti": return false
		case "rst": return false
		case "jp": return false
		case _: return true
		}
	}
	
	func disassemble(data : [UInt8]) -> [(Instruction, offset : Int)] {
		var instructions : [(Instruction, offset : Int)] = []
		var mutableData = data
		let length = data.count
		
		while !data.isEmpty {
			let beforeLength = mutableData.count
			guard let instruction = disassembleInstruction(data : &mutableData) else { break }
			instructions.append((instruction, offset: length - beforeLength))
		}
		
		return instructions
	}
	
	func disassembleInstruction(data : inout [UInt8]) -> Instruction? {
		guard let byte = data.safeRemove(at: 0) else { return nil }
		
		switch byte {
		case 0x00: return Instruction("nop")
		case 0x01: return Instruction("ld", .constant("BC"), data.getUInt16Expression())
		case 0x02: return Instruction("ld", .squareParens(.constant("BC")), .constant("A"))
		case 0x03: return Instruction("inc", .constant("BC"))
		case 0x04: return Instruction("inc", .constant("B"))
		case 0x05: return Instruction("dec", .constant("B"))
		case 0x06: return Instruction("ld", .constant("B"), data.getUInt8Expression())
		case 0x07: return Instruction("rlca")
		case 0x08: return Instruction("ld", .squareParens(data.getUInt16Expression()), .constant("SP"))
		case 0x09: return Instruction("add", .constant("HL"), .constant("BC"))
		case 0x0a: return Instruction("ld", .constant("A"), .squareParens(.constant("BC")))
		case 0x0b: return Instruction("dec", .constant("BC"))
		case 0x0c: return Instruction("inc", .constant("C"))
		case 0x0d: return Instruction("dec", .constant("C"))
		case 0x0e: return Instruction("ld", .constant("C"), data.getUInt8Expression())
		case 0x0f: return Instruction("rrca")
		
		case 0x10: return Instruction("stop", .constant("0"))
		case 0x11: return Instruction("ld", .constant("de"), data.getUInt16Expression())
		case 0x12: return Instruction("ld", .squareParens(.constant("DE")), .constant("A"))
		case 0x13: return Instruction("inc", .constant("DE"))
		case 0x14: return Instruction("inc", .constant("D"))
		case 0x15: return Instruction("dec", .constant("D"))
		case 0x16: return Instruction("ld", .constant("D"), data.getUInt8Expression())
		case 0x17: return Instruction("rla")
		case 0x18: return Instruction("jr", data.getInt8Expression())
		case 0x19: return Instruction("add", .constant("HL"), .constant("DE"))
		case 0x1a: return Instruction("ld", .constant("A"), .squareParens(.constant("DE")))
		case 0x1b: return Instruction("dec", .constant("DE"))
		case 0x1c: return Instruction("inc", .constant("E"))
		case 0x1d: return Instruction("dec", .constant("E"))
		case 0x1e: return Instruction("ld", .constant("E"), data.getUInt8Expression())
		case 0x1f: return Instruction("rra")
			
		case 0x20: return Instruction("jr", .constant("NZ"), data.getInt8Expression())
		case 0x21: return Instruction("ld", .constant("HL"), data.getUInt16Expression())
		case 0x22: return Instruction("ld", .squareParens(.suffix(.constant("HL"), "+")), .constant("A"))
		case 0x23: return Instruction("inc", .constant("HL"))
		case 0x24: return Instruction("inc", .constant("H"))
		case 0x25: return Instruction("dec", .constant("H"))
		case 0x26: return Instruction("ld", .constant("H"), data.getUInt8Expression())
		case 0x27: return Instruction("daa")
		case 0x28: return Instruction("jr", .constant("Z"), data.getInt8Expression())
		case 0x29: return Instruction("add", .constant("HL"), .constant("HL"))
		case 0x2a: return Instruction("ld", .constant("A"), .squareParens(.suffix(.constant("HL"), "+")))
		case 0x2b: return Instruction("dec", .constant("HL"))
		case 0x2c: return Instruction("inc", .constant("L"))
		case 0x2d: return Instruction("dec", .constant("L"))
		case 0x2e: return Instruction("ld", .constant("L"), data.getUInt8Expression())
		case 0x2f: return Instruction("cpl")
			
		case 0x30: return Instruction("jr", .constant("NC"), data.getInt8Expression())
		case 0x31: return Instruction("ld", .constant("SP"), data.getUInt16Expression())
		case 0x32: return Instruction("ld", .squareParens(.suffix(.constant("HL"), "-")), .constant("A"))
		case 0x33: return Instruction("inc", .constant("SP"))
		case 0x34: return Instruction("inc", .squareParens(.constant("HL")))
		case 0x35: return Instruction("dec", .squareParens(.constant("HL")))
		case 0x36: return Instruction("ld", .squareParens(.constant("HL")), data.getUInt8Expression())
		case 0x37: return Instruction("scf")
		case 0x38: return Instruction("jr", .constant("C"), data.getInt8Expression())
		case 0x39: return Instruction("add", .constant("HL"), .constant("SP"))
		case 0x3a: return Instruction("ld", .constant("A"), .squareParens(.suffix(.constant("HL"), "-")))
		case 0x3b: return Instruction("dec", .constant("SP"))
		case 0x3c: return Instruction("inc", .constant("A"))
		case 0x3d: return Instruction("dec", .constant("A"))
		case 0x3e: return Instruction("ld", .constant("A"), data.getUInt8Expression())
		case 0x3f: return Instruction("ccf")
			
		case 0x40: return Instruction("ld", .constant("B"), .constant("B"))
		case 0x41: return Instruction("ld", .constant("B"), .constant("C"))
		case 0x42: return Instruction("ld", .constant("B"), .constant("D"))
		case 0x43: return Instruction("ld", .constant("B"), .constant("E"))
		case 0x44: return Instruction("ld", .constant("B"), .constant("H"))
		case 0x45: return Instruction("ld", .constant("B"), .constant("L"))
		case 0x46: return Instruction("ld", .constant("B"), .squareParens(.constant("HL")))
		case 0x47: return Instruction("ld", .constant("B"), .constant("A"))
		case 0x48: return Instruction("ld", .constant("C"), .constant("B"))
		case 0x49: return Instruction("ld", .constant("C"), .constant("C"))
		case 0x4a: return Instruction("ld", .constant("C"), .constant("D"))
		case 0x4b: return Instruction("ld", .constant("C"), .constant("E"))
		case 0x4c: return Instruction("ld", .constant("C"), .constant("H"))
		case 0x4d: return Instruction("ld", .constant("C"), .constant("L"))
		case 0x4e: return Instruction("ld", .constant("C"), .squareParens(.constant("HL")))
		case 0x4f: return Instruction("ld", .constant("C"), .constant("A"))
			
		case 0x50: return Instruction("ld", .constant("D"), .constant("B"))
		case 0x51: return Instruction("ld", .constant("D"), .constant("C"))
		case 0x52: return Instruction("ld", .constant("D"), .constant("D"))
		case 0x53: return Instruction("ld", .constant("D"), .constant("E"))
		case 0x54: return Instruction("ld", .constant("D"), .constant("H"))
		case 0x55: return Instruction("ld", .constant("D"), .constant("L"))
		case 0x56: return Instruction("ld", .constant("D"), .squareParens(.constant("HL")))
		case 0x57: return Instruction("ld", .constant("D"), .constant("A"))
		case 0x58: return Instruction("ld", .constant("E"), .constant("B"))
		case 0x59: return Instruction("ld", .constant("E"), .constant("C"))
		case 0x5a: return Instruction("ld", .constant("E"), .constant("D"))
		case 0x5b: return Instruction("ld", .constant("E"), .constant("E"))
		case 0x5c: return Instruction("ld", .constant("E"), .constant("H"))
		case 0x5d: return Instruction("ld", .constant("E"), .constant("L"))
		case 0x5e: return Instruction("ld", .constant("E"), .squareParens(.constant("HL")))
		case 0x5f: return Instruction("ld", .constant("E"), .constant("A"))
			
		case 0x60: return Instruction("ld", .constant("H"), .constant("B"))
		case 0x61: return Instruction("ld", .constant("H"), .constant("C"))
		case 0x62: return Instruction("ld", .constant("H"), .constant("D"))
		case 0x63: return Instruction("ld", .constant("H"), .constant("E"))
		case 0x64: return Instruction("ld", .constant("H"), .constant("H"))
		case 0x65: return Instruction("ld", .constant("H"), .constant("L"))
		case 0x66: return Instruction("ld", .constant("H"), .squareParens(.constant("HL")))
		case 0x67: return Instruction("ld", .constant("H"), .constant("A"))
		case 0x68: return Instruction("ld", .constant("L"), .constant("B"))
		case 0x69: return Instruction("ld", .constant("L"), .constant("C"))
		case 0x6a: return Instruction("ld", .constant("L"), .constant("D"))
		case 0x6b: return Instruction("ld", .constant("L"), .constant("E"))
		case 0x6c: return Instruction("ld", .constant("L"), .constant("H"))
		case 0x6d: return Instruction("ld", .constant("L"), .constant("L"))
		case 0x6e: return Instruction("ld", .constant("L"), .squareParens(.constant("HL")))
		case 0x6f: return Instruction("ld", .constant("L"), .constant("A"))
			
		case 0x70: return Instruction("ld", .squareParens(.constant("HL")), .constant("B"))
		case 0x71: return Instruction("ld", .squareParens(.constant("HL")), .constant("C"))
		case 0x72: return Instruction("ld", .squareParens(.constant("HL")), .constant("D"))
		case 0x73: return Instruction("ld", .squareParens(.constant("HL")), .constant("E"))
		case 0x74: return Instruction("ld", .squareParens(.constant("HL")), .constant("H"))
		case 0x75: return Instruction("ld", .squareParens(.constant("HL")), .constant("L"))
		case 0x76: return Instruction("halt")
		case 0x77: return Instruction("ld", .squareParens(.constant("HL")), .constant("A"))
		case 0x78: return Instruction("ld", .constant("A"), .constant("B"))
		case 0x79: return Instruction("ld", .constant("A"), .constant("C"))
		case 0x7a: return Instruction("ld", .constant("A"), .constant("D"))
		case 0x7b: return Instruction("ld", .constant("A"), .constant("E"))
		case 0x7c: return Instruction("ld", .constant("A"), .constant("H"))
		case 0x7d: return Instruction("ld", .constant("A"), .constant("L"))
		case 0x7e: return Instruction("ld", .constant("A"), .squareParens(.constant("HL")))
		case 0x7f: return Instruction("ld", .constant("A"), .constant("A"))
			
		case 0x80: return Instruction("add", .constant("A"), .constant("B"))
		case 0x81: return Instruction("add", .constant("A"), .constant("C"))
		case 0x82: return Instruction("add", .constant("A"), .constant("D"))
		case 0x83: return Instruction("add", .constant("A"), .constant("E"))
		case 0x84: return Instruction("add", .constant("A"), .constant("H"))
		case 0x85: return Instruction("add", .constant("A"), .constant("L"))
		case 0x86: return Instruction("add", .constant("A"), .squareParens(.constant("HL")))
		case 0x87: return Instruction("add", .constant("A"), .constant("A"))
		case 0x88: return Instruction("adc", .constant("A"), .constant("B"))
		case 0x89: return Instruction("adc", .constant("A"), .constant("C"))
		case 0x8a: return Instruction("adc", .constant("A"), .constant("D"))
		case 0x8b: return Instruction("adc", .constant("A"), .constant("E"))
		case 0x8c: return Instruction("adc", .constant("A"), .constant("H"))
		case 0x8d: return Instruction("adc", .constant("A"), .constant("L"))
		case 0x8e: return Instruction("adc", .constant("A"), .squareParens(.constant("HL")))
		case 0x8f: return Instruction("adc", .constant("A"), .constant("A"))
			
		case 0x90: return Instruction("sub", .constant("A"), .constant("B"))
		case 0x91: return Instruction("sub", .constant("A"), .constant("C"))
		case 0x92: return Instruction("sub", .constant("A"), .constant("D"))
		case 0x93: return Instruction("sub", .constant("A"), .constant("E"))
		case 0x94: return Instruction("sub", .constant("A"), .constant("H"))
		case 0x95: return Instruction("sub", .constant("A"), .constant("L"))
		case 0x96: return Instruction("sub", .constant("A"), .squareParens(.constant("HL")))
		case 0x97: return Instruction("sub", .constant("A"), .constant("A"))
		case 0x98: return Instruction("sbc", .constant("A"), .constant("B"))
		case 0x99: return Instruction("sbc", .constant("A"), .constant("C"))
		case 0x9a: return Instruction("sbc", .constant("A"), .constant("D"))
		case 0x9b: return Instruction("sbc", .constant("A"), .constant("E"))
		case 0x9c: return Instruction("sbc", .constant("A"), .constant("H"))
		case 0x9d: return Instruction("sbc", .constant("A"), .constant("L"))
		case 0x9e: return Instruction("sbc", .constant("A"), .squareParens(.constant("HL")))
		case 0x9f: return Instruction("sbc", .constant("A"), .constant("A"))
			
		case 0xa0: return Instruction("and", .constant("B"))
		case 0xa1: return Instruction("and", .constant("C"))
		case 0xa2: return Instruction("and", .constant("D"))
		case 0xa3: return Instruction("and", .constant("E"))
		case 0xa4: return Instruction("and", .constant("H"))
		case 0xa5: return Instruction("and", .constant("L"))
		case 0xa6: return Instruction("and", .squareParens(.constant("HL")))
		case 0xa7: return Instruction("and", .constant("A"))
		case 0xa8: return Instruction("xor", .constant("B"))
		case 0xa9: return Instruction("xor", .constant("C"))
		case 0xaa: return Instruction("xor", .constant("D"))
		case 0xab: return Instruction("xor", .constant("E"))
		case 0xac: return Instruction("xor", .constant("H"))
		case 0xad: return Instruction("xor", .constant("L"))
		case 0xae: return Instruction("xor", .squareParens(.constant("HL")))
		case 0xaf: return Instruction("xor", .constant("A"))
			
		case 0xb0: return Instruction("or", .constant("B"))
		case 0xb1: return Instruction("or", .constant("C"))
		case 0xb2: return Instruction("or", .constant("D"))
		case 0xb3: return Instruction("or", .constant("E"))
		case 0xb4: return Instruction("or", .constant("H"))
		case 0xb5: return Instruction("or", .constant("L"))
		case 0xb6: return Instruction("or", .squareParens(.constant("HL")))
		case 0xb7: return Instruction("or", .constant("A"))
		case 0xb8: return Instruction("cp", .constant("B"))
		case 0xb9: return Instruction("cp", .constant("C"))
		case 0xba: return Instruction("cp", .constant("D"))
		case 0xbb: return Instruction("cp", .constant("E"))
		case 0xbc: return Instruction("cp", .constant("H"))
		case 0xbd: return Instruction("cp", .constant("L"))
		case 0xbe: return Instruction("cp", .squareParens(.constant("HL")))
		case 0xbf: return Instruction("cp", .constant("A"))
			
		case 0xc0: return Instruction("ret", .constant("NZ"))
		case 0xc1: return Instruction("pop", .constant("BC"))
		case 0xc2: return Instruction("jp", .constant("NZ"), data.getUInt16Expression())
		case 0xc3: return Instruction("jp", data.getUInt16Expression())
		case 0xc4: return Instruction("call", .constant("NZ"), data.getUInt16Expression())
		case 0xc5: return Instruction("push", .constant("BC"))
		case 0xc6: return Instruction("add", .constant("A"), data.getUInt8Expression())
		case 0xc7: return Instruction("rst", .value(0x00))
		case 0xc8: return Instruction("ret", .constant("Z"))
		case 0xc9: return Instruction("ret")
		case 0xca: return Instruction("jp", .constant("Z"), data.getUInt16Expression())
		case 0xcb: return disassembleCB(byte: data.remove(at: 0, or: boundsError))
		case 0xcc: return Instruction("call", .constant("Z"), data.getUInt16Expression())
		case 0xcd: return Instruction("call", data.getUInt16Expression())
		case 0xce: return Instruction("adc", .constant("A"), data.getUInt8Expression())
		case 0xcf: return Instruction("rst", .value(0x08))
			
		case 0xd0: return Instruction("ret", .constant("NC"))
		case 0xd1: return Instruction("pop", .constant("DE"))
		case 0xd2: return Instruction("jp", .constant("NC"), data.getUInt16Expression())
		case 0xd3: break
		case 0xd4: return Instruction("call", .constant("NC"), data.getUInt16Expression())
		case 0xd5: return Instruction("push", .constant("DE"))
		case 0xd6: return Instruction("sub", data.getUInt8Expression())
		case 0xd7: return Instruction("rst", .value(0x10))
		case 0xd8: return Instruction("ret", .constant("C"))
		case 0xd9: return Instruction("reti")
		case 0xda: return Instruction("jp", .constant("C"), data.getUInt16Expression())
		case 0xdb: break
		case 0xdc: return Instruction("call", .constant("C"), data.getUInt16Expression())
		case 0xdd: break
		case 0xde: return Instruction("sbc", .constant("A"), data.getUInt8Expression())
		case 0xdf: return Instruction("rst", .value(0x18))
			
		case 0xe0: return Instruction("ldh", .squareParens(data.getUInt16Expression()), .constant("A"))
		case 0xe1: return Instruction("pop", .constant("HL"))
		case 0xe2: return Instruction("ld", .squareParens(.constant("C")), .constant("A"))
		case 0xe3: break
		case 0xe4: break
		case 0xe5: return Instruction("push", .constant("HL"))
		case 0xe6: return Instruction("and", data.getUInt8Expression())
		case 0xe7: return Instruction("rst", .value(0x20))
		case 0xe8: return Instruction("add", .constant("SP"), data.getInt8Expression())
		case 0xe9: return Instruction("jp", .squareParens(.constant("HL")))
		case 0xea: return Instruction("ld", .squareParens(data.getUInt16Expression()), .constant("A"))
		case 0xeb: break
		case 0xec: break
		case 0xed: break
		case 0xee: return Instruction("xor", data.getUInt8Expression())
		case 0xef: return Instruction("rst", .value(0x28))
			
		case 0xf0: return Instruction("ldh", .squareParens(data.getUInt8Expression()))
		case 0xf1: return Instruction("pop", .constant("AF"))
		case 0xf2: return Instruction("ld", .constant("A"), .squareParens(.constant("C")))
		case 0xf3: return Instruction("di")
		case 0xf4: break
		case 0xf5: return Instruction("push", .constant("AF"))
		case 0xf6: return Instruction("or", data.getUInt8Expression())
		case 0xf7: return Instruction("rst", .value(0x30))
		case 0xf8: return Instruction("ld", .constant("HL"), .binaryExpr(.constant("SP"), "+", data.getInt8Expression()))
		case 0xf9: return Instruction("ld", .constant("SP"), .constant("HL"))
		case 0xfa: return Instruction("ld", .constant("A"), .squareParens(data.getUInt16Expression()))
		case 0xfb: return Instruction("ei")
		case 0xfc: break
		case 0xfd: break
		case 0xfe: return Instruction("cp", data.getUInt8Expression())
		case 0xff: return Instruction("rst", .value(0x38))
			
		case _: fatalError("Unhandled opcode \(byte)")
		}
		
		return Instruction("db", .value(Int(byte)))
	}
	
	func disassembleCB(byte : UInt8) -> Instruction {
		switch byte {
			
		case 0x00: return Instruction("rlc", .constant("B"))
		case 0x01: return Instruction("rlc", .constant("C"))
		case 0x02: return Instruction("rlc", .constant("D"))
		case 0x03: return Instruction("rlc", .constant("E"))
		case 0x04: return Instruction("rlc", .constant("H"))
		case 0x05: return Instruction("rlc", .constant("L"))
		case 0x06: return Instruction("rlc", .squareParens(.constant("HL")))
		case 0x07: return Instruction("rlc", .constant("A"))
		case 0x08: return Instruction("rrc", .constant("B"))
		case 0x09: return Instruction("rrc", .constant("C"))
		case 0x0a: return Instruction("rrc", .constant("D"))
		case 0x0b: return Instruction("rrc", .constant("E"))
		case 0x0c: return Instruction("rrc", .constant("H"))
		case 0x0d: return Instruction("rrc", .constant("L"))
		case 0x0e: return Instruction("rrc", .squareParens(.constant("HL")))
		case 0x0f: return Instruction("rrc", .constant("A"))
			
		case 0x10: return Instruction("rl", .constant("B"))
		case 0x11: return Instruction("rl", .constant("C"))
		case 0x12: return Instruction("rl", .constant("D"))
		case 0x13: return Instruction("rl", .constant("E"))
		case 0x14: return Instruction("rl", .constant("H"))
		case 0x15: return Instruction("rl", .constant("L"))
		case 0x16: return Instruction("rl", .squareParens(.constant("HL")))
		case 0x17: return Instruction("rl", .constant("A"))
		case 0x18: return Instruction("rr", .constant("B"))
		case 0x19: return Instruction("rr", .constant("C"))
		case 0x1a: return Instruction("rr", .constant("D"))
		case 0x1b: return Instruction("rr", .constant("E"))
		case 0x1c: return Instruction("rr", .constant("H"))
		case 0x1d: return Instruction("rr", .constant("L"))
		case 0x1e: return Instruction("rr", .squareParens(.constant("HL")))
		case 0x1f: return Instruction("rr", .constant("A"))
			
		case 0x20: return Instruction("sla", .constant("B"))
		case 0x21: return Instruction("sla", .constant("C"))
		case 0x22: return Instruction("sla", .constant("D"))
		case 0x23: return Instruction("sla", .constant("E"))
		case 0x24: return Instruction("sla", .constant("H"))
		case 0x25: return Instruction("sla", .constant("L"))
		case 0x26: return Instruction("sla", .squareParens(.constant("HL")))
		case 0x27: return Instruction("sla", .constant("A"))
		case 0x28: return Instruction("sra", .constant("B"))
		case 0x29: return Instruction("sra", .constant("C"))
		case 0x2a: return Instruction("sra", .constant("D"))
		case 0x2b: return Instruction("sra", .constant("E"))
		case 0x2c: return Instruction("sra", .constant("H"))
		case 0x2d: return Instruction("sra", .constant("L"))
		case 0x2e: return Instruction("sra", .squareParens(.constant("HL")))
		case 0x2f: return Instruction("sra", .constant("A"))
			
		case 0x30: return Instruction("swap", .constant("B"))
		case 0x31: return Instruction("swap", .constant("C"))
		case 0x32: return Instruction("swap", .constant("D"))
		case 0x33: return Instruction("swap", .constant("E"))
		case 0x34: return Instruction("swap", .constant("H"))
		case 0x35: return Instruction("swap", .constant("L"))
		case 0x36: return Instruction("swap", .squareParens(.constant("HL")))
		case 0x37: return Instruction("swap", .constant("A"))
		case 0x38: return Instruction("srl", .constant("B"))
		case 0x39: return Instruction("srl", .constant("C"))
		case 0x3a: return Instruction("srl", .constant("D"))
		case 0x3b: return Instruction("srl", .constant("E"))
		case 0x3c: return Instruction("srl", .constant("H"))
		case 0x3d: return Instruction("srl", .constant("L"))
		case 0x3e: return Instruction("srl", .squareParens(.constant("HL")))
		case 0x3f: return Instruction("srl", .constant("A"))
			
		case 0x40: return Instruction("bit", .value(0), .constant("B"))
		case 0x41: return Instruction("bit", .value(0), .constant("C"))
		case 0x42: return Instruction("bit", .value(0), .constant("D"))
		case 0x43: return Instruction("bit", .value(0), .constant("E"))
		case 0x44: return Instruction("bit", .value(0), .constant("H"))
		case 0x45: return Instruction("bit", .value(0), .constant("L"))
		case 0x46: return Instruction("bit", .value(0), .squareParens(.constant("HL")))
		case 0x47: return Instruction("bit", .value(0), .constant("A"))
		case 0x48: return Instruction("bit", .value(1), .constant("B"))
		case 0x49: return Instruction("bit", .value(1), .constant("C"))
		case 0x4a: return Instruction("bit", .value(1), .constant("D"))
		case 0x4b: return Instruction("bit", .value(1), .constant("E"))
		case 0x4c: return Instruction("bit", .value(1), .constant("H"))
		case 0x4d: return Instruction("bit", .value(1), .constant("L"))
		case 0x4e: return Instruction("bit", .value(1), .squareParens(.constant("HL")))
		case 0x4f: return Instruction("bit", .value(1), .constant("A"))
			
		case 0x50: return Instruction("bit", .value(2), .constant("B"))
		case 0x51: return Instruction("bit", .value(2), .constant("C"))
		case 0x52: return Instruction("bit", .value(2), .constant("D"))
		case 0x53: return Instruction("bit", .value(2), .constant("E"))
		case 0x54: return Instruction("bit", .value(2), .constant("H"))
		case 0x55: return Instruction("bit", .value(2), .constant("L"))
		case 0x56: return Instruction("bit", .value(2), .squareParens(.constant("HL")))
		case 0x57: return Instruction("bit", .value(2), .constant("A"))
		case 0x58: return Instruction("bit", .value(3), .constant("B"))
		case 0x59: return Instruction("bit", .value(3), .constant("C"))
		case 0x5a: return Instruction("bit", .value(3), .constant("D"))
		case 0x5b: return Instruction("bit", .value(3), .constant("E"))
		case 0x5c: return Instruction("bit", .value(3), .constant("H"))
		case 0x5d: return Instruction("bit", .value(3), .constant("L"))
		case 0x5e: return Instruction("bit", .value(3), .squareParens(.constant("HL")))
		case 0x5f: return Instruction("bit", .value(3), .constant("A"))
			
		case 0x60: return Instruction("bit", .value(4), .constant("B"))
		case 0x61: return Instruction("bit", .value(4), .constant("C"))
		case 0x62: return Instruction("bit", .value(4), .constant("D"))
		case 0x63: return Instruction("bit", .value(4), .constant("E"))
		case 0x64: return Instruction("bit", .value(4), .constant("H"))
		case 0x65: return Instruction("bit", .value(4), .constant("L"))
		case 0x66: return Instruction("bit", .value(4), .squareParens(.constant("HL")))
		case 0x67: return Instruction("bit", .value(4), .constant("A"))
		case 0x68: return Instruction("bit", .value(5), .constant("B"))
		case 0x69: return Instruction("bit", .value(5), .constant("C"))
		case 0x6a: return Instruction("bit", .value(5), .constant("D"))
		case 0x6b: return Instruction("bit", .value(5), .constant("E"))
		case 0x6c: return Instruction("bit", .value(5), .constant("H"))
		case 0x6d: return Instruction("bit", .value(5), .constant("L"))
		case 0x6e: return Instruction("bit", .value(5), .squareParens(.constant("HL")))
		case 0x6f: return Instruction("bit", .value(5), .constant("A"))
			
		case 0x70: return Instruction("bit", .value(6), .constant("B"))
		case 0x71: return Instruction("bit", .value(6), .constant("C"))
		case 0x72: return Instruction("bit", .value(6), .constant("D"))
		case 0x73: return Instruction("bit", .value(6), .constant("E"))
		case 0x74: return Instruction("bit", .value(6), .constant("H"))
		case 0x75: return Instruction("bit", .value(6), .constant("L"))
		case 0x76: return Instruction("bit", .value(6), .squareParens(.constant("HL")))
		case 0x77: return Instruction("bit", .value(6), .constant("A"))
		case 0x78: return Instruction("bit", .value(7), .constant("B"))
		case 0x79: return Instruction("bit", .value(7), .constant("C"))
		case 0x7a: return Instruction("bit", .value(7), .constant("D"))
		case 0x7b: return Instruction("bit", .value(7), .constant("E"))
		case 0x7c: return Instruction("bit", .value(7), .constant("H"))
		case 0x7d: return Instruction("bit", .value(7), .constant("L"))
		case 0x7e: return Instruction("bit", .value(7), .squareParens(.constant("HL")))
		case 0x7f: return Instruction("bit", .value(7), .constant("A"))
			
		case 0x80: return Instruction("res", .value(0), .constant("B"))
		case 0x81: return Instruction("res", .value(0), .constant("C"))
		case 0x82: return Instruction("res", .value(0), .constant("D"))
		case 0x83: return Instruction("res", .value(0), .constant("E"))
		case 0x84: return Instruction("res", .value(0), .constant("H"))
		case 0x85: return Instruction("res", .value(0), .constant("L"))
		case 0x86: return Instruction("res", .value(0), .squareParens(.constant("HL")))
		case 0x87: return Instruction("res", .value(0), .constant("A"))
		case 0x88: return Instruction("res", .value(1), .constant("B"))
		case 0x89: return Instruction("res", .value(1), .constant("C"))
		case 0x8a: return Instruction("res", .value(1), .constant("D"))
		case 0x8b: return Instruction("res", .value(1), .constant("E"))
		case 0x8c: return Instruction("res", .value(1), .constant("H"))
		case 0x8d: return Instruction("res", .value(1), .constant("L"))
		case 0x8e: return Instruction("res", .value(1), .squareParens(.constant("HL")))
		case 0x8f: return Instruction("res", .value(1), .constant("A"))
			
		case 0x90: return Instruction("res", .value(2), .constant("B"))
		case 0x91: return Instruction("res", .value(2), .constant("C"))
		case 0x92: return Instruction("res", .value(2), .constant("D"))
		case 0x93: return Instruction("res", .value(2), .constant("E"))
		case 0x94: return Instruction("res", .value(2), .constant("H"))
		case 0x95: return Instruction("res", .value(2), .constant("L"))
		case 0x96: return Instruction("res", .value(2), .squareParens(.constant("HL")))
		case 0x97: return Instruction("res", .value(2), .constant("A"))
		case 0x98: return Instruction("res", .value(3), .constant("B"))
		case 0x99: return Instruction("res", .value(3), .constant("C"))
		case 0x9a: return Instruction("res", .value(3), .constant("D"))
		case 0x9b: return Instruction("res", .value(3), .constant("E"))
		case 0x9c: return Instruction("res", .value(3), .constant("H"))
		case 0x9d: return Instruction("res", .value(3), .constant("L"))
		case 0x9e: return Instruction("res", .value(3), .squareParens(.constant("HL")))
		case 0x9f: return Instruction("res", .value(3), .constant("A"))
			
		case 0xa0: return Instruction("res", .value(4), .constant("B"))
		case 0xa1: return Instruction("res", .value(4), .constant("C"))
		case 0xa2: return Instruction("res", .value(4), .constant("D"))
		case 0xa3: return Instruction("res", .value(4), .constant("E"))
		case 0xa4: return Instruction("res", .value(4), .constant("H"))
		case 0xa5: return Instruction("res", .value(4), .constant("L"))
		case 0xa6: return Instruction("res", .value(4), .squareParens(.constant("HL")))
		case 0xa7: return Instruction("res", .value(4), .constant("A"))
		case 0xa8: return Instruction("res", .value(5), .constant("B"))
		case 0xa9: return Instruction("res", .value(5), .constant("C"))
		case 0xaa: return Instruction("res", .value(5), .constant("D"))
		case 0xab: return Instruction("res", .value(5), .constant("E"))
		case 0xac: return Instruction("res", .value(5), .constant("H"))
		case 0xad: return Instruction("res", .value(5), .constant("L"))
		case 0xae: return Instruction("res", .value(5), .squareParens(.constant("HL")))
		case 0xaf: return Instruction("res", .value(5), .constant("A"))
			
		case 0xb0: return Instruction("res", .value(6), .constant("B"))
		case 0xb1: return Instruction("res", .value(6), .constant("C"))
		case 0xb2: return Instruction("res", .value(6), .constant("D"))
		case 0xb3: return Instruction("res", .value(6), .constant("E"))
		case 0xb4: return Instruction("res", .value(6), .constant("H"))
		case 0xb5: return Instruction("res", .value(6), .constant("L"))
		case 0xb6: return Instruction("res", .value(6), .squareParens(.constant("HL")))
		case 0xb7: return Instruction("res", .value(6), .constant("A"))
		case 0xb8: return Instruction("res", .value(7), .constant("B"))
		case 0xb9: return Instruction("res", .value(7), .constant("C"))
		case 0xba: return Instruction("res", .value(7), .constant("D"))
		case 0xbb: return Instruction("res", .value(7), .constant("E"))
		case 0xbc: return Instruction("res", .value(7), .constant("H"))
		case 0xbd: return Instruction("res", .value(7), .constant("L"))
		case 0xbe: return Instruction("res", .value(7), .squareParens(.constant("HL")))
		case 0xbf: return Instruction("res", .value(7), .constant("A"))
			
		case 0xc0: return Instruction("set", .value(0), .constant("B"))
		case 0xc1: return Instruction("set", .value(0), .constant("C"))
		case 0xc2: return Instruction("set", .value(0), .constant("D"))
		case 0xc3: return Instruction("set", .value(0), .constant("E"))
		case 0xc4: return Instruction("set", .value(0), .constant("H"))
		case 0xc5: return Instruction("set", .value(0), .constant("L"))
		case 0xc6: return Instruction("set", .value(0), .squareParens(.constant("HL")))
		case 0xc7: return Instruction("set", .value(0), .constant("A"))
		case 0xc8: return Instruction("set", .value(1), .constant("B"))
		case 0xc9: return Instruction("set", .value(1), .constant("C"))
		case 0xca: return Instruction("set", .value(1), .constant("D"))
		case 0xcb: return Instruction("set", .value(1), .constant("E"))
		case 0xcc: return Instruction("set", .value(1), .constant("H"))
		case 0xcd: return Instruction("set", .value(1), .constant("L"))
		case 0xce: return Instruction("set", .value(1), .squareParens(.constant("HL")))
		case 0xcf: return Instruction("set", .value(1), .constant("A"))
			
		case 0xd0: return Instruction("set", .value(2), .constant("B"))
		case 0xd1: return Instruction("set", .value(2), .constant("C"))
		case 0xd2: return Instruction("set", .value(2), .constant("D"))
		case 0xd3: return Instruction("set", .value(2), .constant("E"))
		case 0xd4: return Instruction("set", .value(2), .constant("H"))
		case 0xd5: return Instruction("set", .value(2), .constant("L"))
		case 0xd6: return Instruction("set", .value(2), .squareParens(.constant("HL")))
		case 0xd7: return Instruction("set", .value(2), .constant("A"))
		case 0xd8: return Instruction("set", .value(3), .constant("B"))
		case 0xd9: return Instruction("set", .value(3), .constant("C"))
		case 0xda: return Instruction("set", .value(3), .constant("D"))
		case 0xdb: return Instruction("set", .value(3), .constant("E"))
		case 0xdc: return Instruction("set", .value(3), .constant("H"))
		case 0xdd: return Instruction("set", .value(3), .constant("L"))
		case 0xde: return Instruction("set", .value(3), .squareParens(.constant("HL")))
		case 0xdf: return Instruction("set", .value(3), .constant("A"))
			
		case 0xe0: return Instruction("set", .value(4), .constant("B"))
		case 0xe1: return Instruction("set", .value(4), .constant("C"))
		case 0xe2: return Instruction("set", .value(4), .constant("D"))
		case 0xe3: return Instruction("set", .value(4), .constant("E"))
		case 0xe4: return Instruction("set", .value(4), .constant("H"))
		case 0xe5: return Instruction("set", .value(4), .constant("L"))
		case 0xe6: return Instruction("set", .value(4), .squareParens(.constant("HL")))
		case 0xe7: return Instruction("set", .value(4), .constant("A"))
		case 0xe8: return Instruction("set", .value(5), .constant("B"))
		case 0xe9: return Instruction("set", .value(5), .constant("C"))
		case 0xea: return Instruction("set", .value(5), .constant("D"))
		case 0xeb: return Instruction("set", .value(5), .constant("E"))
		case 0xec: return Instruction("set", .value(5), .constant("H"))
		case 0xed: return Instruction("set", .value(5), .constant("L"))
		case 0xee: return Instruction("set", .value(5), .squareParens(.constant("HL")))
		case 0xef: return Instruction("set", .value(5), .constant("A"))
			
		case 0xf0: return Instruction("set", .value(6), .constant("B"))
		case 0xf1: return Instruction("set", .value(6), .constant("C"))
		case 0xf2: return Instruction("set", .value(6), .constant("D"))
		case 0xf3: return Instruction("set", .value(6), .constant("E"))
		case 0xf4: return Instruction("set", .value(6), .constant("H"))
		case 0xf5: return Instruction("set", .value(6), .constant("L"))
		case 0xf6: return Instruction("set", .value(6), .squareParens(.constant("HL")))
		case 0xf7: return Instruction("set", .value(6), .constant("A"))
		case 0xf8: return Instruction("set", .value(7), .constant("B"))
		case 0xf9: return Instruction("set", .value(7), .constant("C"))
		case 0xfa: return Instruction("set", .value(7), .constant("D"))
		case 0xfb: return Instruction("set", .value(7), .constant("E"))
		case 0xfc: return Instruction("set", .value(7), .constant("H"))
		case 0xfd: return Instruction("set", .value(7), .constant("L"))
		case 0xfe: return Instruction("set", .value(7), .squareParens(.constant("HL")))
		case 0xff: return Instruction("set", .value(7), .constant("A"))
			
		case _: fatalError("Unhandled opcode CB \(byte)")
		}
	}
}
