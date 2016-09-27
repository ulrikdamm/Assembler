//
//  main.swift
//  AssemblerCLI
//
//  Created by Ulrik Damm on 10/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

import Foundation

struct Arguments {
	let inputFile : URL
	let outputFile : URL
	let symbolsFile : URL?
	
	init(fromRaw arguments : [String]) throws {
		enum State { case none, parseOutput, parseSymbols }
		var state = State.none
		
		var inputURL : URL?
		var outputURL : URL?
		var symbolsURL : URL?
		
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
			case (.none, "-o"):
				state = .parseOutput
			case (.none, "--output-symbols"):
				state = .parseSymbols
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
		
		if let symbolsURL = symbolsURL {
			symbolsFile = symbolsURL
		} else {
			symbolsFile = nil
		}
	}
}

func main() {
	do {
		let rawArguments = Array(CommandLine.arguments.dropFirst())
		guard rawArguments.count > 0 else { print("Usage: input/file.asm [-o output/file.asm] [--output-symbols symbols/file.symbols]"); return } 
		let arguments = try Arguments(fromRaw: rawArguments)
		let source = try String(contentsOf: arguments.inputFile)
		
		guard let program = try State(source: source).getProgram()?.value else { throw ErrorMessage("Couldn't parse source") }
		
		let assembler = Assembler<GameboyInstructionSet>(constants: program.constants)
		let blocks = try program.blocks.map { block in try assembler.assembleBlock(label: block) }
		
//		let blocks = try program.blocks.map { block in try assembleBlock(label: block, constants: program.constants) }
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
	} catch let error as ErrorMessage {
		print(error.message)
	} catch let error as State.ParseError {
		print(error.localizedDescription)
	} catch let error {
		print(error.localizedDescription)
	}
}

main()
