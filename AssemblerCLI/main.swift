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
	
	init(fromRaw arguments : [String]) throws {
		enum State { case none, parseOutput }
		var state = State.none
		
		var inputURL : URL?
		var outputURL : URL?
		
		for argument in arguments {
			switch (state, argument) {
			case (.parseOutput, let string):
				let url = URL(fileURLWithPath: string)
				guard outputURL == nil else { throw ErrorMessage("Output url redeclared") }
				outputURL = url
				state = .none
			case (.none, "-o"):
				state = .parseOutput
			case (.none, let string):
				let url = URL(fileURLWithPath: string)
				guard inputURL == nil else { throw ErrorMessage("Input url redeclared") }
				inputURL = url
			}
		}
		
		switch state {
		case .none: break
		case .parseOutput: throw ErrorMessage("Missing value for -o")
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
	}
}

do {
	let arguments = try Arguments(fromRaw: Array(CommandLine.arguments.dropFirst()))
	let source = try String(contentsOf: arguments.inputFile)
	let bytes = try assembleProgram(source: [source])
	let data = Data(bytes: bytes)
	try data.write(to: arguments.outputFile)
} catch let error as ErrorMessage {
	print(error.message)
} catch let error as State.ParseError {
	print(error.localizedDescription)
} catch let error {
	print(error.localizedDescription)
}
