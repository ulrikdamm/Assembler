//
//  Parser.swift
//  Assembler
//
//  Created by Ulrik Damm on 08/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

struct ParserState {
	struct ParseError : Error {
		enum Reason {
			case expectedMatch(match : String)
            case invalidEscape(value : String)
            case invalidUnicodeEscape
		}
		
		let reason : Reason
		let state : ParserState
		
		init(reason : Reason, _ state : ParserState) {
			self.reason = reason
			self.state = state
		}
		
		var message : String {
			switch reason {
			case .expectedMatch(let match): return "Expected `\(match)`"
            case .invalidEscape(let value): return "Invalid escape sequence `\(value)`"
            case .invalidUnicodeEscape: return "Unicode escape sequence must be two hex digits"
			}
		}
		
		var localizedDescription : String {
			return "Error on line \(state.line): \(message)"
		}
	}
	
	let source : String
	var location : String.Index
	var line : Int
	
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
	
	var atEnd : Bool { return location >= source.endIndex }
    var current : Character? { return getAt(location) }
    
    mutating func advance() {
        guard let current = current else { return }
        
        if current.isNewline { line += 1 }
        location = source.index(after: location)
    }
	
	func getAt(_ location : String.Index) -> Character? {
		guard !atEnd else { return nil }
		return source[location]
	}
    
    mutating func skip(until condition : (Character) -> Bool) {
        while let char = current, !condition(char) {
            if char.isNewline { line += 1 }
            location = source.index(after: location)
        }
    }
    
    mutating func skipChars(_ char : Character) {
        skip(until: { c in c != char })
    }
    
    mutating func skipChars(in chars : [Character]) {
        skip(until: { c in !chars.contains(c) })
    }
    
    mutating func skipWhitespace(includingLineBreaks : Bool = false) {
        if (includingLineBreaks) {
            skip(until: { c in !c.isWhitespace && !c.isNewline })
        } else {
            skip(until: { c in !c.isWhitespace })
        }
    }
    
    mutating func skipComments() {
        guard let hashChar = current, hashChar == "#" else { return }
        skip(until: \Character.isNewline)
    }
    
    mutating func skipCommentsAndWhitespace(includingLineBreaks : Bool = true) {
        var inComment = false
        
        skip(until: { c in
            if inComment && c.isNewline {
                inComment = false
                return (includingLineBreaks ? false : true)
            }
            
            if inComment { return false }
            
            if c == "#" {
                inComment = true
                return false
            }
            
            if c.isWhitespace || (includingLineBreaks && c.isNewline) { return false }
            
            return true
        })
    }
    
    mutating func getChar() -> Character? {
        guard let char = getAt(location) else { return nil }
        advance()
        return char
    }
    
    mutating func getChar(_ char : Character) -> Character? {
        guard let c = getAt(location), char == c else { return nil }
        advance()
        return c
    }
    
    mutating func getChar(_ chars : [Character]) -> Character? {
        guard let c = getAt(location), chars.contains(c) else { return nil }
        advance()
        return c
    }
    
    mutating func getChar(where condition : (Character) -> Bool) -> Character? {
        guard let c = getAt(location), condition(c) else { return nil }
        advance()
        return c
    }
    
	mutating func getNumericChar() -> Character? {
        guard let char = current, char.isNumeric else { return nil }
        advance()
        return char
	}
	
	mutating func getAlphaChar() -> Character? {
        guard let char = current, char.isAlpha else { return nil }
        advance()
        return char
	}
    
    mutating func match(_ char : Character) -> Bool {
        guard let c = current, c == char else { return false }
        advance()
        return true
    }
    
    mutating func match(_ chars : [Character]) -> Bool {
        guard let c = current, chars.contains(c) else { return false }
        advance()
        return true
    }
    
    mutating func match(_ string : String) -> Bool {
        let originalState = self
        
        for character in string {
            guard match(character) else { self = originalState; return false }
        }
        
        return true
    }
    
    mutating func matchOrFail(_ string : String) throws {
        for character in string {
            guard match(character) else { throw ParseError(reason: .expectedMatch(match: string), self) }
        }
    }
    
    mutating func getUntil(_ end : Character) -> String? {
        let originalState = self
        var string = ""
        
        while !match(end) {
            guard let c = getChar() else { self = originalState; return nil }
            string.append(c)
        }
        
        return string
    }
    
    mutating func getUntil(_ end : [Character]) -> String? {
        let originalState = self
        var string = ""
        
        while !match(end) {
            guard let c = getChar() else { self = originalState; return nil }
            string.append(c)
        }
        
        return string
    }
    
	mutating func getUntil(_ end : String) -> String? {
		let originalState = self
		var string = ""
		
		while !match(end) {
            guard let c = getChar() else { self = originalState; return nil }
            string.append(c)
		}
        
        return string
	}
    
	mutating func getIdentifier() -> String? {
		skipWhitespace()
        let originalState = self
		
        guard let char = getAlphaChar() ?? getChar(".") else { self = originalState; return nil }
		var string = String(char)
		
		while let char = getAlphaChar() ?? getNumericChar() ?? getChar(".") {
            string.append(char)
		}
		
		return string
	}
	
	mutating func getNumber() -> Int? {
        skipWhitespace()
        let originalState = self
        
        if match("0") {
            if match("d") { return getDecimalNumber() }
            if match("x") { return getHexNumber() }
            if match("b") { return getBinaryNumber() }
            self = originalState
        }
        
        return getDecimalNumber()
	}
	
	mutating func getHexNumber() -> Int? {
        skipWhitespace()
        let originalState = self
        
        var string = ""
        
        while let char = getChar(where: \.isHex) {
            string.append(char)
            skipChars("_")
        }
        
        if string.count == 0 { self = originalState; return nil }
        
        return Int(string, radix: 16)!
	}
	
	mutating func getDecimalNumber() -> Int? {
        skipWhitespace()
        let originalState = self
        
        var string = ""
        
        while let char = getNumericChar() {
            string.append(char)
            skipChars("_")
        }
        
        if string.count == 0 { self = originalState; return nil }
        
        return Int(string)!
	}
	
	mutating func getBinaryNumber() -> Int? {
        skipWhitespace()
        let originalState = self
        
        var string = ""
        
        while let char = getChar(["0", "1"]) {
            string.append(char)
            skipChars("_")
        }
        
        if string.count == 0 { self = originalState; return nil }
        
        return Int(string, radix: 2)!
	}
	
	mutating func getStringLiteral() throws -> String? {
		skipWhitespace()
		
        guard match("\"") else { return nil }
        
        var string = ""
        
        while true {
            guard let c = getChar() else { throw ParseError(reason: .expectedMatch(match: "\""), self) }
            
            switch c {
            case "\"": return string
            case "\\":
                guard let escapeChar = getChar() else { throw ParseError(reason: .invalidEscape(value: ""), self) }
                
                switch escapeChar {
                case "\"": string.append("\"")
                case "\\": string.append("\\")
                case "0": string.append("\0")
                case "n": string.append("\n")
                case "t": string.append("\t")
                case "r": string.append("\r")
                case "u":
                    guard
                        let c1 = getChar(where: \.isHex),
                        let c2 = getChar(where: \.isHex),
                        let unicodeValue = Int(String(c1) + String(c2), radix: 16),
                        let scalar = Unicode.Scalar(unicodeValue) else {
                        throw ParseError(reason: .invalidUnicodeEscape, self)
                    }
                    string.append(Character(scalar))
                case _: throw ParseError(reason: .invalidEscape(value: String(escapeChar)), self)
                }
            case _: string.append(c)
            }
        }
	}
	
	mutating func getSeparator() -> Bool {
        skipCommentsAndWhitespace(includingLineBreaks: false)
        
        if atEnd { return true }
        if !match(["\n", ";"]) { return false }
        
        skipCommentsAndWhitespace()
        let _ = getSeparator()
        return true
	}
}
