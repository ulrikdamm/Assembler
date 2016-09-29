//
//  Assembler.swift
//  Assembler
//
//  Created by Ulrik Damm on 08/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

public protocol InstructionSet {
	func assembleInstruction(instruction : Instruction) throws -> [Opcode]
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

struct Assembler {
	let constants : [String: Expression]
	let instructionSet : InstructionSet
	
	init(instructionSet : InstructionSet, constants : [String: Expression]) {
		var reducedConstants = constants
		
		for (key, value) in reducedConstants {
			reducedConstants[key] = value.reduced()
		}
		
		self.constants = reducedConstants
		self.instructionSet = instructionSet
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
