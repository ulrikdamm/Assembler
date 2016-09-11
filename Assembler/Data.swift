//
//  Data.swift
//  GameboyAssembler
//
//  Created by Ulrik Damm on 09/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

struct Instruction {
	let mnemonic : String
	let operands : [Expression]
	let line : Int
}

extension Instruction : CustomStringConvertible {
	var description: String {
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

enum Opcode : CustomStringConvertible {
	case byte(UInt8)
	case label(String)
	
	var description : String {
		switch self {
		case .byte(let b): return String(b, radix: 16)
		case .label(let name): return name
		}
	}
	
	var byteLength : Int {
		switch self {
		case .byte(_): return 1
		case .label(_): return 2
		}
	}
	
	static func bytesFrom16bit(_ value : Int) throws -> [Opcode] {
		guard (0...0xffff).contains(value) else {
			throw ErrorMessage("Value outside of 16-bit bounds")
		}
		
		let lsb = UInt8(value & 0xff)
		let msb = UInt8((value >> 8) & 0xff)
		return [.byte(lsb), .byte(msb)]
	}
}

extension Opcode : Equatable {
	static func ==(lhs : Opcode, rhs : Opcode) -> Bool {
		switch (lhs, rhs) {
		case (.byte(let nl), .byte(let nr)) where nl == nr: return true
		case (.label(let sl), .label(let sr)) where sl == sr: return true
		case _: return false
		}
	}
}
