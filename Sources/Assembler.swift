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
		let assembledInstructions = try label.instructions.map(instructionSet.assembleInstruction).joined()
		
		let constantExpander = ExpressionConstantExpansion(constants: constants)
		let expandedInstructions = try assembledInstructions.map { try $0.expandExpression(using: constantExpander) }
		
		let origin = try originOfLabel(label: label, constantExpander: constantExpander)
		let block = Linker.Block(name: label.identifier.lowercased(), origin: origin, data: expandedInstructions)
		
		return block
	}
	
	func originOfLabel(label : Label, constantExpander : ExpressionConstantExpansion) throws -> Int? {
		guard let declaredOrigin = label.options["org"] else { return nil }
		let expandedOrigin = try constantExpander.expand(declaredOrigin)
		
		guard case .value(let origin) = expandedOrigin else { throw ErrorMessage("Invalid value `\(expandedOrigin)` for block origin") }
		return origin
	}
}
