//
//  Data.swift
//  GameboyAssembler
//
//  Created by Ulrik Damm on 09/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

public struct Instruction {
	let mnemonic : String
	let operands : [Expression]
	let line : Int
}

extension Instruction : CustomStringConvertible {
	public var description: String {
		let ops = operands.map { $0.description }.joined(separator: ", ")
		return "\(mnemonic) \(ops)"
	}
}

struct Label {
	let identifier : String
	let instructions : [Instruction]
	let options : [String: Expression]
}

extension Label : CustomStringConvertible {
	var description : String {
		return "\(identifier): " + instructions.map { $0.description }.joined(separator: "; ")
	}
}

extension Character {
	var isNumeric : Bool {
		return self >= "0" && self <= "9"
	}
	
	var isHex : Bool {
		return (
			self >= "0" && self <= "9" ||
				self >= "a" && self <= "f" ||
				self >= "A" && self <= "F"
		)
	}
	
	var isAlpha : Bool {
		return (self >= "a" && self <= "z") || (self >= "A" && self <= "Z") || self == "_"
	}
	
	var isWhitespace : Bool {
		return (self == " " || self == "\t")
	}
}

struct Program {
	let constants : [String: Expression]
	let blocks : [Label]
}

public struct ErrorMessage : Error {
	public let message : String
	
	public init(_ message : String) {
		self.message = message
	}
}
