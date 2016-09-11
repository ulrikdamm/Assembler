//
//  Parser.swift
//  Assembler
//
//  Created by Ulrik Damm on 08/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

struct State {
	struct ParseError : Error {
		enum Reason {
			case constantRedefinition(constant : String)
			case expectedLabelOrDefine
			case expectedSeparator
			case expectedExpression
			case expectedMatch(match : String)
		}
		
		let reason : Reason
		let state : State
		
		init(reason : Reason, _ state : State) {
			self.reason = reason
			self.state = state
		}
		
		var localizedDescription : String {
			let message : String
			
			switch reason {
			case .constantRedefinition(let constant): message = "Constant `\(constant)` already defined"
			case .expectedLabelOrDefine: message = "Expected label or constant definition"
			case .expectedSeparator: message = "Expected end of instruction (newline or semicolon)"
			case .expectedExpression: message = "Expected value, register or expression"
			case .expectedMatch(let match): message = "Expected `\(match)`"
			}
			
			return "Error on line \(state.line): \(message)"
		}
	}
	
	let source : String
	let location : String.Index
	let line : Int
	
	init(source : String, location : String.Index, line : Int) {
		self.source = source
		self.location = location
		self.line = line
	}
	
	init(source : [String]) {
		self.source = source.joined(separator: "\n")
		self.location = self.source.startIndex
		self.line = 1
	}
	
	init(source : String) {
		self.source = source
		self.location = source.startIndex
		self.line = 1
	}
	
	var atEnd : Bool {
		return location == source.endIndex
	}
	
	func getAt(location : String.Index) -> Character? {
		guard location < source.endIndex else { return nil }
		return source[location]
	}
	
	func getChar(ignoreComments : Bool = true) -> (value : Character, state : State)? {
		guard var next = getAt(location: location) else { return nil }
		var nextLocation = source.index(after: location)
		let lineBreaks = (next == "\n" ? 1 : 0)
		
		while next == "#" {
			while true {
				nextLocation = source.index(after: nextLocation)
				guard let c = getAt(location: nextLocation) else { return nil }
				if c == "\n" {
					next = c
					break
				}
			}
		}
		
		let state = State(source: source, location: nextLocation, line: line + lineBreaks)
		return (next, state)
	}
	
	func getNumericChar() -> (value : String, state : State)? {
		if let (c, state) = getChar(), c.isNumeric { return (String(c), state) }
		return nil
	}
	
	func getAlphaChar() -> (value : String, state : State)? {
		if let (c, state) = getChar(), c.isAlpha { return (String(c), state) }
		return nil
	}
	
	func getAlphaOrNumericChar() -> (value : String, state : State)? {
		return getAlphaChar() ?? getNumericChar()
	}
	
	func getString() -> (value : String, state : State)? {
		var state = ignoreWhitespace()
		var string = ""
		
		while let (char, newState) = state.getAlphaChar() {
			string += char
			state = newState
		}
		
		guard string != "" else { return nil }
		return (string, state)
	}
	
	func getUntil(end : String) -> (value : String, state : State)? {
		var state = self
		var string = ""
		
		while true {
			if let newState = state.match(string: end) {
				return (string, newState)
			}
			
			guard let (c, newState) = state.getChar() else { return nil }
			state = newState
			string += String(c)
		}
	}
	
	func get(predicate : (State) -> (String, State)?) -> (value : String, state : State)? {
		var state = ignoreWhitespace()
		var string = ""
		
		while let (char, newState) = predicate(state) {
			string += char
			state = newState
		}
		
		guard string != "" else { return nil }
		return (string, state)
	}
	
	func getIdentifier() -> (value : String, state : State)? {
		var state = ignoreWhitespace()
		
		guard let (char, newState) = state.getAlphaChar() else { return nil }
		var string = char
		state = newState
		
		while let (char, newState) = state.getAlphaChar() ?? state.getNumericChar() {
			string += char
			state = newState
		}
		
		return (string, state)
	}
	
	func getNumber() -> (value : Int, state : State)? {
		var state = ignoreWhitespace()
		
		if let (z, newState) = state.getChar(), z == "0" {
			if let (c, newState) = newState.getChar(), c == "d" {
				state = newState
				return state.getDecimalNumber()
			}
			
			if let (c, newState) = newState.getChar(), c == "x" {
				state = newState
				return state.getHexNumber()
			}
		}
		
		return state.getDecimalNumber()
	}
	
	func getHexNumber() -> (value : Int, state : State)? {
		var state = self
		
		guard let (char, newState) = state.getChar(), char.isHex else { return nil }
		var string = String(char)
		state = newState
		
		while let (char, newState) = state.getChar(), char.isHex {
			string += String(char)
			state = newState
		}
		
		return (Int(string, radix: 16)!, state)
	}
	
	func getDecimalNumber() -> (value : Int, state : State)? {
		var state = self
		
		guard let (char, newState) = state.getNumericChar() else { return nil }
		var string = char
		state = newState
		
		while let (char, newState) = state.getNumericChar() {
			string += char
			state = newState
		}
		
		return (Int(string)!, state)
	}
	
	func ignoreWhitespace(allowNewline : Bool = false) -> State {
		guard let (char, state) = getChar(), char.isWhitespace || (allowNewline && char == "\n") else { return self }
		return state.ignoreWhitespace(allowNewline: allowNewline)
	}
	
	func match(string : String) -> State? {
		var state = self
		for character in string.characters {
			guard let (c, newState) = state.getChar(), character == c else { return nil }
			state = newState
		}
		return state
	}
	
	func getKeyword(keyword : String) -> State? {
		guard let (string, state) = getString() else { return nil }
		guard string == keyword else { return nil }
		return state
	}
	
	func getSeparator() -> State? {
		let state = ignoreWhitespace(allowNewline: false)
		if state.atEnd { return state }
		guard let (c, state1) = state.getChar(), c == "\n" || c == ";" else { return nil }
		return state1.getSeparator() ?? state1
	}
	
	func getStringLiteral() -> (value : String, state : State)? {
		var state = ignoreWhitespace()
		
		guard let (c, newState1) = state.getChar(), c == "\"" else { return nil }
		state = newState1
		
		guard let (string, newState2) = state.getUntil(end: "\"") else { return nil }
		return (string, newState2)
	}
	
	func getInstruction() throws -> (value : Instruction, state : State)? {
		var state = ignoreWhitespace(allowNewline: true)
		let line = state.line
		
		var operands : [Expression] = []
		
		guard let (mnemonic, newState1) = state.getIdentifier() else { return nil }
		state = newState1
		
		while let (op, newState2) = try state.getExpression() {
			state = newState2
			operands.append(op)
			
			if let (char, newState3) = state.ignoreWhitespace().getChar(), char == "," {
				state = newState3
			} else {
				break
			}
		}
		
		guard let newState2 = state.getSeparator() else { return nil }
		state = newState2
		
		let instruction = Instruction(mnemonic: mnemonic, operands: operands, line: line)
		return (instruction, state)
	}
	
	func getInstructionList() throws -> (value : [Instruction], state : State)? {
		var state = ignoreWhitespace()
		var instructions : [Instruction] = []
		
		while let (instruction, newState) = try state.getInstruction() {
			instructions.append(instruction)
			state = newState
		}
		
		guard !instructions.isEmpty else { return nil }
		return (instructions, state)
	}
	
	func getLabel() throws -> (value : Label, state : State)? {
		var state = ignoreWhitespace(allowNewline: true)
		let options : [String: Expression]
		
		if let (optionList, newState0) = try state.getOptionList() {
			state = newState0
			options = optionList
		} else {
			options = [:]
		}
		
		state = state.ignoreWhitespace(allowNewline: true)
		
		guard let (name, newState1) = state.getIdentifier() else { return nil }
		state = newState1
		
		guard let (c, newState2) = state.getChar(), c == ":" else { return nil }
		state = newState2
		
		guard let (instructions, newState3) = try state.getInstructionList() else { return nil }
		state = newState3
		
		let label = Label(identifier: name, instructions: instructions, options: options)
		return (label, state)
	}
	
	func getDefine() throws -> (value : (name : String, constant : Expression), state : State)? {
		var state = ignoreWhitespace(allowNewline: true)
		
		guard let (identifier, newState1) = state.getIdentifier() else { return nil }
		state = newState1
		
		guard let (c, newState2) = state.ignoreWhitespace().getChar(), c == "=" else { return nil }
		state = newState2
		
		guard let (value, newState3) = try state.getExpression() else { throw ParseError(reason: .expectedExpression, state) }
		state = newState3
		
		guard let newState4 = state.getSeparator() else { throw ParseError(reason: .expectedSeparator, state) }
		state = newState4
		
		return ((identifier, value), state)
	}
	
	func getProgram() throws -> (value : Program, state : State)? {
		var state = ignoreWhitespace()
		var labels : [Label] = []
		var constants : [String: Expression] = [:]
		
		while true {
			if let (label, newState) = try state.getLabel() {
				labels.append(label)
				state = newState
			} else if let (define, newState) = try state.getDefine() {
				guard !constants.keys.contains(define.name) else {
					throw ParseError(reason: .constantRedefinition(constant: define.name), state)
				}
				
				state = newState
				constants[define.name] = define.constant
			} else {
				guard state.ignoreWhitespace(allowNewline: true).atEnd else {
					throw ParseError(reason: .expectedLabelOrDefine, state)
				}
				break
			}
		}
		
		guard !labels.isEmpty else { return nil }
		let program = Program(constants: constants, blocks: labels)
		return (program, state)
	}
	
	func getOptionList() throws -> (value : [String: Expression], state : State)? {
		var state = ignoreWhitespace()
		var options : [String: Expression] = [:]
		
		guard let (c1, newState1) = state.getChar(), c1 == "[" else { return nil }
		state = newState1
		
		if let (option, newState2) = try state.getOption() {
			state = newState2
			options[option.key] = option.value
		}
		
		guard let (c2, newState3) = state.getChar(), c2 == "]" else { return nil }
		state = newState3
		
		return (options, state)
	}
	
	func getOption() throws -> (value : (key : String, value : Expression), state : State)? {
		var state = ignoreWhitespace()
		
		guard let (key, newState1) = state.getIdentifier() else { return nil }
		state = newState1
		
		guard let (c, newState2) = state.getChar(), c == "(" else { return nil }
		state = newState2
		
		let value : Expression
		if let (number, newState3) = try state.getExpression() {
			state = newState3
			value = number
		} else {
			throw ParseError(reason: .expectedExpression, state)
		}
		
		guard let (c2, newState4) = state.getChar(), c2 == ")" else {
			throw ParseError(reason: .expectedMatch(match: ")"), state)
		}
		state = newState4
		
		return ((key, value), state)
	}
	
	func getExpression() throws -> (value : Expression, state : State)? {
		var state = ignoreWhitespace()
		
		let expression : Expression
		
		if let (constant, newState1) = state.getIdentifier() {
			state = newState1
			expression = Expression.constant(constant)
		} else if let (string, newState1) = state.getStringLiteral() {
			state = newState1
			expression = .string(string)
		} else if let (number, newState1) = state.getNumber() {
			state = newState1
			expression = .value(number)
		} else if let (c, newState1) = state.ignoreWhitespace().getChar(), c == "(" {
			state = newState1
			guard let (nextExpression, newState2) = try state.getExpression() else {
				throw ParseError(reason: .expectedExpression, state)
			}
			state = newState2
			guard let (c2, newState3) = state.ignoreWhitespace().getChar(), c2 == ")" else {
				throw ParseError(reason: .expectedMatch(match: ")"), state)
			}
			state = newState3
			expression = .parens(nextExpression)
		} else if let (op, newState1) = state.getExpressionOperator() {
			state = newState1
			guard let (nextExpression, newState2) = try state.getExpression() else {
				throw ParseError(reason: .expectedExpression, state)
			}
			state = newState2
			expression = .prefix(op, nextExpression)
		} else {
			return nil
		}
		
		if let (operatorCharacter, newState2) = state.getExpressionOperator() {
			state = newState2
			
			if let (nextExpression, newState3) = try state.getExpression() {
				return (.binaryExp(expression, operatorCharacter, nextExpression), newState3)
			} else {
				return (.suffix(expression, operatorCharacter),  newState2)
			}
		} else {
			return (expression, state)
		}
	}
	
	func getExpressionOperator() -> (value : String, state : State)? {
		let state = ignoreWhitespace()
		
		for op in ["+", "-", "*", "/", "%", "<<", ">>", "|", "&"] {
			if let newState = state.match(string: op) {
				return (op, newState)
			}
		}
		
		return nil
	}
}
