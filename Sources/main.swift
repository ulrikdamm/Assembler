//
//  main.swift
//  AssemblerCLI
//
//  Created by Ulrik Damm on 10/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

import Foundation
import AppKit

struct Arguments {
	let inputFile : URL
	let outputFile : URL
	let symbolsFile : URL?
	let systemType : String?
	let spriteSheet : URL?
	let spriteSheetMemoryLocation : UInt16?
	
	init(fromRaw arguments : [String]) throws {
		enum State { case none, parseOutput, parseSymbols, parseSystemType, parseSpriteSheet, parseSpriteSheetLocation }
		var state = State.none
		
		var inputURL : URL?
		var outputURL : URL?
		var symbolsURL : URL?
		var spriteSheetURL : URL?
		var spriteSheetLocation : UInt16?
		var systemType : String?
		
		for argument in arguments {
			switch (state, argument) {
			case (.parseOutput, let string):
				let url = URL(fileURLWithPath: string)
				guard outputURL == nil else { throw ErrorMessage("Output url redeclared") }
				outputURL = url
				state = .none
			case (.parseSymbols, let string):
				let url = URL(fileURLWithPath: string)
				guard symbolsURL == nil else { throw ErrorMessage("Symbols url redeclared") }
				symbolsURL = url
				state = .none
			case (.parseSystemType, let string):
				systemType = string
				state = .none
			case (.parseSpriteSheet, let string):
				let url = URL(fileURLWithPath: string)
				guard spriteSheetURL == nil else { throw ErrorMessage("Sprite sheet url redeclared") }
				spriteSheetURL = url
				state = .none
			case (.parseSpriteSheetLocation, let string):
				guard let location = UInt16(string, radix: 16) else { throw ErrorMessage("Invalid 16-bit hex sprite sheet memory location") }
				guard spriteSheetLocation == nil else { throw ErrorMessage("Sprite sheet memory location redeclared") }
				spriteSheetLocation = location
				state = .none
			case (.none, "-o"):
				state = .parseOutput
			case (.none, "--output-symbols"):
				state = .parseSymbols
			case (.none, "--target"):
				state = .parseSystemType
			case (.none, "--sprite-sheet"):
				state = .parseSpriteSheet
			case (.none, "--sprites-memory-location"):
				state = .parseSpriteSheetLocation
			case (.none, let string):
				let url = URL(fileURLWithPath: string)
				guard inputURL == nil else { throw ErrorMessage("Input url redeclared") }
				inputURL = url
			}
		}
		
		switch state {
		case .none: break
		case .parseOutput: throw ErrorMessage("Missing value for -o")
		case .parseSymbols: throw ErrorMessage("Missing value for --output-symbols")
		case .parseSystemType: throw ErrorMessage("Missing value for --target")
		case .parseSpriteSheet: throw ErrorMessage("Missing value for --sprite-sheet")
		case .parseSpriteSheetLocation: throw ErrorMessage("Missing value for --sprites-memory-location") 
		}
		
		guard let inputURLValue = inputURL else { throw ErrorMessage("Missing input") }
		inputFile = inputURLValue
		
		if let outputURL = outputURL {
			outputFile = outputURL
		} else {
			let filename = inputURLValue.deletingPathExtension().lastPathComponent 
			outputFile = inputURLValue
				.deletingLastPathComponent()
				.appendingPathComponent(filename)
				.appendingPathExtension("gb") 
		}
		
		self.symbolsFile = symbolsURL
		self.systemType = systemType
		self.spriteSheet = spriteSheetURL
		self.spriteSheetMemoryLocation = spriteSheetLocation
	}
}

func spriteSheetBlock(fileLocation : URL, memoryLocation : UInt16?, instructionSet : InstructionSet) throws -> Linker.Block {
	guard let sprites = NSImage(contentsOf: fileLocation) else {
		throw ErrorMessage("Sprite sheet image not found at location `\(fileLocation)`")
	}
	
	let spritesInstruction = SpriteReader.splitImageIntoSprites(sprites).map { $0.getAssemblyDataInstructions(line: 0) }
	let assembler = Assembler(instructionSet: instructionSet, constants: [:])
	
	let origin : UInt16
	if let memoryLocation = memoryLocation {
		origin = memoryLocation
	} else {
		print("No sprite sheet memory location declared, using 0x4000 (declare with --sprites-memory-location)")
		origin = 0x4000
	}
	
	return try assembler.assembleBlock(label: Label(identifier: "sprites", instructions: spritesInstruction, options: ["org": .value(Int(origin))]))
}

func main() throws {
	let rawArguments = Array(CommandLine.arguments.dropFirst())
	guard rawArguments.count > 0 else {
		print("Usage: input/file.asm\n"
			+ "\t[-o output/file.asm]\n"
			+ "\t[--output-symbols symbols/file.symbols]\n"
			+ "\t[--target gameboy | intel8080]")
		return
	}
	
	let arguments = try Arguments(fromRaw: rawArguments)
	let source = try String(contentsOf: arguments.inputFile)
	
	guard let program = try AssemblyParser.getProgram(State(source: source))?.value else { throw ErrorMessage("Couldn't parse source") }
	
	let instructionSet : InstructionSet
	
	switch (arguments.systemType ?? "gameboy") {
	case "intel8080":
		instructionSet = Intel8080InstructionSet()
		print("*** Warning: Assembling for Intel 8080 is still experimental ***")
	case "gameboy": instructionSet = GameboyInstructionSet()
	case let target: throw ErrorMessage("Unknown system target `\(target)` (Supported targets: gameboy, intel8080)")
	}
	
	let assembler = Assembler(instructionSet: instructionSet, constants: program.constants)
	var blocks = try program.blocks.map { block in try assembler.assembleBlock(label: block) }
	
	if let spriteSheet = arguments.spriteSheet {
		let spritesBlock = try spriteSheetBlock(fileLocation: spriteSheet, memoryLocation: arguments.spriteSheetMemoryLocation, instructionSet: instructionSet)
		blocks.append(spritesBlock)
	}
	
	let linker = Linker(blocks: blocks)
	let bytes = try linker.link()
	
	let data = Data(bytes: bytes)
	try data.write(to: arguments.outputFile)
	
	if let symbolsFile = arguments.symbolsFile {
		let symbols = linker.allocations.sorted { a, b in a.start < b.start }.map { allocation -> String in
			let start = String(allocation.start, radix: 16)
			let block = linker.blocks[allocation.blockId]
			return "$\(start): \(block.name)"
		}
		
		try symbols.joined(separator: "\n").write(to: symbolsFile, atomically: true, encoding: String.Encoding.utf8)
	}
}

do {
	try main()
} catch let error as ErrorMessage {
	print("Assembler error: \(error.message)")
} catch let error as State.ParseError {
	print("Parsing error: \(error.localizedDescription)")
} catch let error {
	print("Error: \(error.localizedDescription)")
}
