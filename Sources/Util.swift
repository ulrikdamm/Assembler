//
//  Util.swift
//  GameboyAssembler
//
//  Created by Ulrik Damm on 09/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

public func formatBytes(bytes : [UInt8]) -> String {
	var output = ""
	
	var count = 0
	for byte in bytes {
		let byteString = String(byte, radix: 16)
		output += (byteString.count == 1 ? "0" : "") + byteString + " "
		count += 1
		
		if count == 16 {
			count = 0
			output += "\n"
		}
	}
	
	return output
}

public func assembleProgram(source : [String], instructionSet : InstructionSet) throws -> [UInt8] {
	let initialState = State(source: source)
	if let program = try AssemblyParser.getProgram(initialState)?.value {
		let assembler = Assembler(instructionSet: instructionSet, constants: program.constants)
		let blocks = try program.blocks.map { block in try assembler.assembleBlock(label: block) }
		let bytes = try Linker(blocks: blocks).link()
		return bytes
	} else {
		throw ErrorMessage("Couldn't parse source")
	}
}

extension UInt16 {
	static func fromInt(value : Int) throws -> UInt16 {
		guard (0...0xffff).contains(value) else { throw ErrorMessage("Value out of range") }
		return UInt16(value)
	}
	
	var lsb : UInt8 { return UInt8(self & 0xff) }
	var msb : UInt8 { return UInt8(self >> 8) }
}

extension UInt8 {
	static func fromInt(value : Int) throws -> UInt8 {
		guard (0...0xff).contains(value) else { throw ErrorMessage("Value out of range") }
		return UInt8(value)
	}
}

extension Int8 {
	static func fromInt(value : Int) throws -> Int8 {
		guard (-128...127).contains(value) else { throw ErrorMessage("Value out of signed byte range") }
		return Int8(value)
	}
}

extension Expression {
	func uint16Opcode() throws -> [Opcode] {
		switch reduced() {
		case .value(let value):
			let n16 = try UInt16.fromInt(value: value)
			return [.byte(n16.lsb), .byte(n16.msb)]
		case let expr:
			return [.expression(expr, .uint16)]
		}
	}
	
	func uint8Opcode(signed : Bool = false) throws -> Opcode {
		switch reduced() {
		case .value(let value):
			let n8 : UInt8
			
			if signed {
				n8 = try UInt8(bitPattern: Int8.fromInt(value: value))
			} else {
				n8 = try UInt8.fromInt(value: value)
			}
			
			return .byte(n8)
		case let expr:
			if signed {
				throw ErrorMessage("Invalid expression `\(self)`") 
			} else {
				return .expression(expr, .uint8)
			}
		}
	}
}

extension Instruction {
	func getSingleOperand() throws -> Expression {
		guard operands.count > 0 else {
			throw ErrorMessage("Missing operand")
		}
		
		guard operands.count == 1 else {
			throw ErrorMessage("Only one operand required")
		}
		
		return operands[0].reduced()
	}
	
	func getTwoOperands() throws -> (Expression, Expression) {
		guard operands.count == 2 else {
			throw ErrorMessage("Missing operand")
		}
		
		return (operands[0].reduced(), operands[1].reduced())
	}
	
	func getOperandRaw(index : Int) throws -> Expression {
		guard operands.count >= index else {
			throw ErrorMessage("Missing operand")
		}
		
		return operands[index]
	}
	
	func getNoOperands() throws {
		guard operands.count == 0 else {
			throw ErrorMessage("No operands required")
		}
	}
	
	func getAtLeastOneOperand() throws -> [Expression] {
		guard operands.count > 0 else {
			throw ErrorMessage("Operands required")
		}
		
		return operands.map { expr in expr.reduced() }
	}
}

extension Array {
	func map<U>(_ transform : KeyPath<Element, U>) -> [U] {
		return map { $0[keyPath: transform] }
	}
}

extension Array where Element : Numeric {
	func sum() -> Element { return reduce(0, +) }
}
