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

extension InstructionSet {
    func assembleInstructionWithLine(instruction : Instruction) throws -> [(Opcode, Int?)] {
        return try assembleInstruction(instruction: instruction).map { ins in (ins, instruction.line) }
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
        let assembledInstructions = try label.instructions.map(instructionSet.assembleInstructionWithLine).joined()
        
        let constantExpander = ExpressionConstantExpansion(constants: constants)
        let expandedInstructions = try assembledInstructions.map { (ins, line) in (try ins.expandExpression(using: constantExpander, inParentLabel: label.parent ?? label.identifier), line) }
        
        let origin = try originOfLabel(label: label, constantExpander: constantExpander)
        let block = Linker.Block(name: label.identifier, parent: label.parent, origin: origin, data: expandedInstructions)
        return block
	}
	
	func originOfLabel(label : Label, constantExpander : ExpressionConstantExpansion) throws -> Int? {
		guard let declaredOrigin = label.options["org"] else { return nil }
        let expandedOrigin = try constantExpander.expand(declaredOrigin, labelParent: label.parent ?? label.identifier, line: label.line)
		
        guard case .value(let origin) = expandedOrigin else { throw AssemblyError("Invalid value `\(expandedOrigin)` for block origin", line: label.line) }
		return origin
	}
}
