//
//  AssemblyParser.swift
//  Assembler
//
//  Created by Ulrik Damm on 16/10/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

struct AssemblyParser {
	struct AssemblyParseError : Error {
		enum Reason {
			case constantRedefinition(constant : String)
			case expectedLabelOrDefine
			case expectedSeparator
			case expectedExpression
		}
		
		let reason : Reason
		let state : State
		
		init(reason : Reason, _ state : State) {
			self.reason = reason
			self.state = state
		}
		
		var message : String {
			switch reason {
			case .constantRedefinition(let constant): return "Constant `\(constant)` already defined"
			case .expectedLabelOrDefine: return "Expected label or constant definition"
			case .expectedSeparator: return "Expected end of instruction (newline or semicolon)"
			case .expectedExpression: return "Expected value, register or expression"
			}
		}
		
		var localizedDescription : String {
			return "Error on line \(state.line): \(message)"
		}
	}
	
	let initialState : State
	
	static func getInstruction(_ initialState : State) throws -> (value : Instruction, state : State)? {
		var state = initialState.ignoreWhitespace(allowNewline: true)
		let line = state.line
		
		var operands : [Expression] = []
		
		guard let (mnemonic, newState1) = state.getIdentifier() else { return nil }
		state = newState1
		
		while let (op, newState2) = try getExpression(state) {
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
	
	static func getInstructionList(_ initialState : State) throws -> (value : [Instruction], state : State)? {
		var state = initialState.ignoreWhitespace()
		var instructions : [Instruction] = []
		
		while let (instruction, newState) = try getInstruction(state) {
			instructions.append(instruction)
			state = newState
		}
		
		return (instructions, state)
	}
	
    static func getLabel(_ initialState : State, parentLabel : String?) throws -> (value : Label, state : State)? {
		var state = initialState.ignoreWhitespace(allowNewline: true)
		let options : [String: Expression]
		
		if let (optionList, newState0) = try getOptionList(state) {
			state = newState0
			options = optionList
		} else {
			options = [:]
		}
		
		state = state.ignoreWhitespace(allowNewline: true)
        
        var isLocal = false
        if let (dot, newState5) = state.getChar(), dot == "." {
            guard parentLabel != nil else { throw ErrorMessage("Can't make a local label without a parent") }
            state = newState5
            isLocal = true
        }
		
		guard let (name, newState1) = state.getIdentifier() else { return nil }
		state = newState1
		
		guard let (c, newState2) = state.getChar(), c == ":" else { return nil }
		state = newState2
		
		guard let (instructions, newState3) = try getInstructionList(state) else { return nil }
		state = newState3
		
        let label = Label(identifier: name, parent: (isLocal ? parentLabel : nil), instructions: instructions, options: options)
		return (label, state)
	}
	
	static func getDefine(_ initialState : State) throws -> (value : (name : String, constant : Expression), state : State)? {
		var state = initialState.ignoreWhitespace(allowNewline: true)
		
		guard let (identifier, newState1) = state.getIdentifier() else { return nil }
		state = newState1
		
		guard let (c, newState2) = state.ignoreWhitespace().getChar(), c == "=" else { return nil }
		state = newState2
		
		guard let (value, newState3) = try getExpression(state) else { throw AssemblyParseError(reason: .expectedExpression, state) }
		state = newState3
		
		guard let newState4 = state.getSeparator() else { throw AssemblyParseError(reason: .expectedSeparator, state) }
		state = newState4
		
		return ((identifier, value), state)
	}
	
	static func getProgram(_ initialState : State) throws -> (value : Program, state : State)? {
		var state = initialState.ignoreWhitespace()
		var labels : [Label] = []
		var constants : [String: Expression] = [:]
		
		while true {
            let parentLabel = labels.last(where: { label in label.parent == nil })
            
            if let (label, newState) = try getLabel(state, parentLabel: parentLabel?.identifier) {
				labels.append(label)
				state = newState
			} else if let (define, newState) = try getDefine(state) {
				guard !constants.keys.contains(define.name) else {
					throw AssemblyParseError(reason: .constantRedefinition(constant: define.name), state)
				}
				
				state = newState
				constants[define.name] = define.constant
			} else {
				guard state.ignoreWhitespace(allowNewline: true).atEnd else {
					throw AssemblyParseError(reason: .expectedLabelOrDefine, state)
				}
				break
			}
		}
		
		guard !labels.isEmpty else { return nil }
		let program = Program(constants: constants, blocks: labels)
		return (program, state)
	}
	
	static func getOptionList(_ initialState : State) throws -> (value : [String: Expression], state : State)? {
		var state = initialState.ignoreWhitespace()
		var options : [String: Expression] = [:]
		
		guard let (c1, newState1) = state.getChar(), c1 == "[" else { return nil }
		state = newState1
		
		if let (option, newState2) = try getOption(state) {
			state = newState2
			options[option.key] = option.value
		}
		
		guard let (c2, newState3) = state.getChar(), c2 == "]" else { return nil }
		state = newState3
		
		return (options, state)
	}
	
	static func getOption(_ initialState : State) throws -> (value : (key : String, value : Expression), state : State)? {
		var state = initialState.ignoreWhitespace()
		
		guard let (key, newState1) = state.getIdentifier() else { return nil }
		state = newState1
		
		guard let (c, newState2) = state.getChar(), c == "(" else { return nil }
		state = newState2
		
		let value : Expression
		if let (number, newState3) = try getExpression(state) {
			state = newState3
			value = number
		} else {
			throw AssemblyParseError(reason: .expectedExpression, state)
		}
		
		guard let (c2, newState4) = state.getChar(), c2 == ")" else {
			throw State.ParseError(reason: .expectedMatch(match: ")"), state)
		}
		state = newState4
		
		return ((key, value), state)
	}
	
	static func getExpression(_ initialState : State) throws -> (value : Expression, state : State)? {
		var state = initialState.ignoreWhitespace()
		
		let expression : Expression
		
		if let (constant, newState1) = state.getIdentifier() {
			state = newState1
			expression = Expression.constant(constant)
		} else if let (string, newState1) = try state.getStringLiteral() {
			state = newState1
			expression = .string(string)
		} else if let (number, newState1) = state.getNumber() {
			state = newState1
			expression = .value(number)
		} else if let (c, newState1) = state.ignoreWhitespace().getChar(), c == "(" {
			state = newState1
			guard let (nextExpression, newState2) = try getExpression(state) else {
				throw AssemblyParseError(reason: .expectedExpression, state)
			}
			state = newState2
			guard let (c2, newState3) = state.ignoreWhitespace().getChar(), c2 == ")" else {
				throw State.ParseError(reason: .expectedMatch(match: ")"), state)
			}
			state = newState3
			expression = .parens(nextExpression)
		} else if let (c, newState1) = state.ignoreWhitespace().getChar(), c == "[" {
			state = newState1
			guard let (nextExpression, newState2) = try getExpression(state) else {
				throw AssemblyParseError(reason: .expectedExpression, state)
			}
			state = newState2
			guard let (c2, newState3) = state.ignoreWhitespace().getChar(), c2 == "]" else {
				throw State.ParseError(reason: .expectedMatch(match: ")"), state)
			}
			state = newState3
			expression = .squareParens(nextExpression)
		} else if let (op, newState1) = getExpressionOperator(state) {
			state = newState1
			guard let (nextExpression, newState2) = try getExpression(state) else {
				throw AssemblyParseError(reason: .expectedExpression, state)
			}
			state = newState2
			expression = .prefix(op, nextExpression)
		} else {
			return nil
		}
		
		if let (operatorCharacter, newState2) = getExpressionOperator(state) {
			state = newState2
			
			if let (nextExpression, newState3) = try getExpression(state) {
				return (.binaryExpr(expression, operatorCharacter, nextExpression), newState3)
			} else {
				return (.suffix(expression, operatorCharacter),  newState2)
			}
		} else {
			return (expression, state)
		}
	}
	
	static func getExpressionOperator(_ initialState : State) -> (value : String, state : State)? {
		let state = initialState.ignoreWhitespace()
		
		for op in ["+", "-", "*", "/", "%", "<<", ">>", "|", "&"] {
			if let newState = state.match(string: op) {
				return (op, newState)
			}
		}
		
		return nil
	}
}
