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

func assembleBlock(label : Label, constants : [String: Expression]) throws -> Linker.Block {
	let assembler = Assembler(constants: constants)
	let data = try label.instructions.map(assembler.assembleInstruction)
	
	let origin = try label.options["org"]
		.map { try assembler.expandExpressionConstants(expression: $0) }
		.flatMap { expr -> Int? in
			if case .value(let v) = expr { return v }
			else { return nil }
	}
	
	let block = Linker.Block(
		name: label.identifier,
		origin: origin,
		data: Array(data.joined())
	)
	return block
}

public func assembleProgram(source : [String]) throws -> [UInt8] {
	if let program = try State(source: source).getProgram()?.value {
		let blocks = try program.blocks.map { block in try assembleBlock(label: block, constants: program.constants) }
		let bytes = try Linker.link(blocks: blocks)
		return bytes
	} else {
		throw ErrorMessage("Couldn't parse source")
	}
}
