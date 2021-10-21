//
//  AssemblyParser.swift
//  Assembler
//
//  Created by Ulrik Damm on 16/10/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

import Cocoa

extension ParserState {
	struct AssemblyParseError : LocalizedError {
		enum Reason {
			case constantRedefinition(constant : String)
            case optionRedefinition(option : String)
            case unknownOption(option : String)
            case expected(string : String)
			case expectedLabelOrDefine
			case expectedSeparator
			case expectedExpression
            case expectedParentLabel
		}
		
		let reason : Reason
		let state : ParserState
		
		init(reason : Reason, _ state : ParserState) {
			self.reason = reason
			self.state = state
		}
		
		var message : String {
			switch reason {
			case .constantRedefinition(let constant): return "Constant `\(constant)` already defined"
            case .optionRedefinition(let option): return "Option `\(option)` already defined"
            case .unknownOption(let option): return "Unknown option `\(option)`"
            case .expected(let string): return "Expected `\(string)`"
			case .expectedLabelOrDefine: return "Expected label or constant definition"
			case .expectedSeparator: return "Expected newline or semicolon"
			case .expectedExpression: return "Expected value, register or expression"
            case .expectedParentLabel: return "Can't make a local label without a parent label"
			}
		}
        
        var errorDescription : String? { "Error on line \(state.line): \(message)" }
	}
	
	mutating func getInstruction() throws -> Instruction? {
        skipCommentsAndWhitespace()
        let originalState = self
        let startLine = line
        
        var operands : [Expression] = []
		
        guard let mnemonic = getIdentifier() else { return nil }
        
        skipWhitespace()
        guard !match([":", "="]) else { self = originalState; return nil }
        
        while let op = try getExpression() {
            operands.append(op)
            
            skipWhitespace()
            if !match(",") { break }
        }
        
        guard getSeparator() else { throw AssemblyParseError(reason: .expectedSeparator, self) }
        
        return Instruction(mnemonic: mnemonic, operands: operands, line: startLine)
	}
	
	mutating func getInstructionList() throws -> [Instruction] {
        skipCommentsAndWhitespace()
        
        var instructions : [Instruction] = []
        
        while let instruction = try getInstruction() {
            instructions.append(instruction)
        }
        
        return instructions
	}
	
    mutating func getLabel(parentLabel : String?) throws -> Label? {
        skipCommentsAndWhitespace()
        let originalState = self
        let startLine = line
        
        let options = try getOptionList() ?? [:]
        
        skipCommentsAndWhitespace()
        
        var isLocal = false
        if match(".") {
            guard parentLabel != nil else { throw AssemblyParseError(reason: .expectedParentLabel, self) }
            isLocal = true
        }
        
        guard let name = getIdentifier() else { self = originalState; return nil }
        
        skipWhitespace()
        guard match(":") else { self = originalState; return nil }
        
        let instructions = try getInstructionList()
        
        return Label(identifier: name, parent: (isLocal ? parentLabel : nil), line: startLine, instructions: instructions, options: options)
	}
	
	mutating func getDefine() throws -> (name : String, constant : Expression)? {
        skipCommentsAndWhitespace()
        
        guard let identififer = getIdentifier() else { return nil }
        skipWhitespace()
        guard match("=") else { return nil }
        guard let value = try getExpression() else { throw AssemblyParseError(reason: .expectedExpression, self) }
        guard getSeparator() else { throw AssemblyParseError(reason: .expectedSeparator, self) }
        
        return (identififer, value)
	}
	
	mutating func getProgram() throws -> Program {
        var labels : [Label] = []
        var constants : [String: Expression] = [:]
        
        while true {
            skipCommentsAndWhitespace()
            
            let parentLabel = labels.last(where: { label in label.parent == nil })
            
            if let label = try getLabel(parentLabel: parentLabel?.identifier) {
                labels.append(label)
            } else if let define = try getDefine() {
                constants[define.name] = define.constant
            } else if !atEnd {
                throw AssemblyParseError(reason: .expectedLabelOrDefine, self)
            } else {
                break
            }
        }
        
//        guard !labels.isEmpty else { return nil }
        
        return Program(constants: constants, blocks: labels)
	}
	
	mutating func getOptionList() throws -> [String: Expression]? {
        skipCommentsAndWhitespace()
        
        var options : [String: Expression] = [:]
        
        guard match("[") else { return nil }
        
        while let option = try getOption() {
            skipCommentsAndWhitespace()
            if options[option.key] != nil { throw AssemblyParseError(reason: .optionRedefinition(option: option.key), self) }
            
            options[option.key] = option.value
            
            skipWhitespace()
            guard match(",") else { break }
        }
        
        skipCommentsAndWhitespace()
        guard match("]") else { throw AssemblyParseError(reason: .expected(string: "]"), self) }
        
        return options
	}
	
	mutating func getOption() throws -> (key : String, value : Expression)? {
        skipCommentsAndWhitespace()
        
        guard let key = getIdentifier() else { return nil }
        guard ["org"].contains(key) else { throw AssemblyParseError(reason: .unknownOption(option: key), self) }
        
        skipWhitespace()
        guard match("(") else { throw AssemblyParseError(reason: .expected(string: "("), self) }
        
        skipWhitespace()
        guard let value = try getExpression() else { throw AssemblyParseError(reason: .expectedExpression, self) }
        
        skipWhitespace()
        guard match(")") else { throw AssemblyParseError(reason: .expected(string: ")"), self) }
        
        return (key, value)
	}
	
	mutating func getExpression() throws -> Expression? {
        skipWhitespace()
		
		let expression : Expression
        
        if let constant = getIdentifier() {
            expression = .constant(constant)
        } else if let string = try getStringLiteral() {
            expression = .string(string)
        } else if let number = getNumber() {
            expression = .value(number)
        } else if match("(") {
            guard let subexpr = try getExpression() else { throw AssemblyParseError(reason: .expectedExpression, self) }
            skipWhitespace()
            try matchOrFail(")")
            expression = .parens(subexpr)
        } else if match("[") {
            guard let subexpr = try getExpression() else { throw AssemblyParseError(reason: .expectedExpression, self) }
            skipWhitespace()
            try matchOrFail("]")
            expression = .squareParens(subexpr)
        } else if let op = getExpressionOperator() {
            guard let next = try getExpression() else { throw AssemblyParseError(reason: .expectedExpression, self) }
            expression = .prefix(op, next)
        } else {
            return nil
        }
        
        if let op = getExpressionOperator() {
            if let next = try getExpression() {
                return .binaryExpr(expression, op, next)
            } else {
                return .suffix(expression, op)
            }
        }
        
        return expression
	}
	
	mutating func getExpressionOperator() -> String? {
        skipWhitespace()
        return ["+", "-", "*", "/", "%", "<<", ">>", "|", "&"].first(where: { op in match(op) })
	}
}
