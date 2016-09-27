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
		output += (byteString.characters.count == 1 ? "0" : "") + byteString + " "
		count += 1
		
		if count == 16 {
			count = 0
			output += "\n"
		}
	}
	
	return output
}

struct ExpressionConstantExpansion {
	let constants : [String: Expression]
	
	func expand(_ expression : Expression, constantStack : [String] = []) throws -> Expression {
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
				return try expand(value, constantStack: constantStack + [str])
			} else {
				return expr
			}
		}
		
		return newExpression
	}
}

struct Assembler<InstructionSetType : InstructionSet> {
	let constants : [String: Expression]
	let instructionSet : InstructionSetType
	
	init(constants : [String: Expression]) {
		var reducedConstants = constants
		
		for (key, value) in reducedConstants {
			reducedConstants[key] = value.reduced()
		}
		
		self.constants = reducedConstants
		
		instructionSet = InstructionSetType()
	}
	
	func assembleBlock(label : Label) throws -> Linker.Block {
		let data = try label.instructions.map(instructionSet.assembleInstruction).joined()
		
		let constantExpander = ExpressionConstantExpansion(constants: constants)
		let constantExpandedData = try data.map { opcode -> (Opcode) in
			switch opcode {
			case .expression(let expr, let resultType): return try .expression(constantExpander.expand(expr), resultType)
			case _: return opcode
			}
		}
		
		let origin = try label.options["org"]
			.map { expr in try constantExpander.expand(expr) }
			.flatMap { expr -> Int? in
				if case .value(let v) = expr { return v }
				else { return nil }
		}
		
		let block = Linker.Block(
			name: label.identifier.lowercased(),
			origin: origin,
			data: constantExpandedData
		)
		return block
	}
}

public func assembleProgram(source : [String]) throws -> [UInt8] {
	if let program = try State(source: source).getProgram()?.value {
		let assembler = Assembler<GameboyInstructionSet>(constants: program.constants)
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
