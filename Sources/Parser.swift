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
			case expectedMatch(match : String)
		}
		
		let reason : Reason
		let state : State
		
		init(reason : Reason, _ state : State) {
			self.reason = reason
			self.state = state
		}
		
		var message : String {
			switch reason {
			case .expectedMatch(let match): return "Expected `\(match)`"
			}
		}
		
		var localizedDescription : String {
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
			
			if let (c, newState) = newState.getChar(), c == "b" {
				state = newState
				return state.getBinaryNumber()
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
	
	func getBinaryNumber() -> (value : Int, state : State)? {
		var state = self
		
		guard let (char, newState) = state.getChar(), char == "0" || char == "1" else { return nil }
		var string = String(char)
		state = newState
		
		while let (char, newState) = state.getChar(), char == "0" || char == "1" || char == "_" {
			state = newState
			if char != "_" {
				string += String(char)
			}
		}
		
		return (Int(string, radix: 2)!, state)
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
	
	func getStringLiteral() throws -> (value : String, state : State)? {
		var state = ignoreWhitespace()
		
		guard let (c, newState1) = state.getChar(), c == "\"" else { return nil }
		state = newState1
		
		guard let (string, newState2) = state.getUntil(end: "\"") else {
			throw ParseError(reason: .expectedMatch(match: "\""), state)
		}
		
		return (string, newState2)
	}
	
	func getSeparator() -> State? {
		let state = ignoreWhitespace(allowNewline: false)
		if state.atEnd { return state }
		guard let (c, state1) = state.getChar(), c == "\n" || c == ";" else { return nil }
		return state1.getSeparator() ?? state1
	}
}
