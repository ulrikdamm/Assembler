//
//  Linker.swift
//  Assembler
//
//  Created by Ulrik Damm on 08/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

enum Opcode : CustomStringConvertible {
	case byte(UInt8)
	case word(UInt16)
	case label(String, relative : Bool)
	case expression(Expression, ResultType)
	
	enum ResultType { case uint16, uint8 }
	
	var description : String {
		switch self {
		case .byte(let b): return String(b, radix: 16)
		case .word(let w): return String(w, radix: 16)
		case .label(let name, _): return name
		case .expression(let expr, _): return expr.description
		}
	}
	
	var byteLength : Int {
		switch self {
		case .byte(_): return 1
		case .word(_): return 2
		case .label(_, true): return 1
		case .label(_, false): return 2
		case .expression(_, .uint16): return 2
		case .expression(_, .uint8): return 1
		}
	}
	
	static func bytesFrom16bit(_ value : Int) throws -> [Opcode] {
		let n16 = try UInt16.fromInt(value: value)
		return [.byte(n16.lsb), .byte(n16.msb)]
	}
}

extension Opcode : Equatable {
	static func ==(lhs : Opcode, rhs : Opcode) -> Bool {
		switch (lhs, rhs) {
		case (.byte(let nl), .byte(let nr)) where nl == nr: return true
		case (.word(let nl), .word(let nr)) where nl == nr: return true
		case (.label(let sl, let rl), .label(let sr, let rr)) where sl == sr && rl == rr: return true
		case (.expression(let el, let rl), .expression(let er, let rr)) where el == er && rl == rr: return true
		case _: return false
		}
	}
}

struct Linker {
	struct Block {
		let name : String
		let origin : Int?
		let data : [Opcode]
	}
	
	struct Allocation {
		let start : Int
		let length : Int
		let blockId : Int
	}
	
	let blocks : [Block]
	let allocations : [Allocation]
	
	init(blocks : [Block]) {
		self.blocks = blocks
		self.allocations = Linker.createAllocations(blocks: blocks)
	}
	
	func link() throws -> [UInt8] {
		let size = calculateBinarySize()
		var data = Array<UInt8>(repeating: 0, count: size)
		
		for allocation in allocations {
			var offset = 0
			for byte in blocks[allocation.blockId].data {
				switch byte {
				case .byte(let n):
					data[allocation.start + offset] = n
					offset += 1
				case .word(let n):
					data[allocation.start + offset] = n.lsb
					data[allocation.start + offset + 1] = n.msb
					offset += 2
				case .label(let name, relative: false):
					if let start = blockStart(name: name) {
						let n16 = try UInt16.fromInt(value: start)
						data[allocation.start + offset] = n16.lsb
						data[allocation.start + offset + 1] = n16.msb
						offset += 2
					} else {
						throw ErrorMessage("Unknown label ’\(name)‘")
					}
				case .label(let name, relative: true):
					if let start = blockStart(name: name) {
						let n16 = try UInt16.fromInt(value: start)
						let current = allocation.start + offset + 1
						let difference = Int(n16) - Int(current)
						print(difference)
						
						do {
							let value = try Int8.fromInt(value: difference)
							data[allocation.start + offset] = UInt8(bitPattern: value)
							offset += 1
						} catch {
							throw ErrorMessage("Label out of range for relative jump (\(difference) bytes away)")
						}
					} else {
						throw ErrorMessage("Unknown label ’\(name)‘")
					}
				case .expression(let expr, let type):
					let mapped = try expr.mapSubExpressions(map: replaceExpressionLabelValue)
					let reduced = mapped.reduced()
					guard case .value(let value) = reduced else {
						throw ErrorMessage("Invalid value `\(reduced)`")
					}
					
					switch type {
					case .uint8:
						data[allocation.start + offset] = try UInt8.fromInt(value: value)
						offset += 1
					case .uint16:
						let n16 = try UInt16.fromInt(value: value)
						data[allocation.start + offset] = n16.lsb
						data[allocation.start + offset + 1] = n16.msb
						offset += 2
					}
				}	
			}
		}
		
		return data
	}
	
	func replaceExpressionLabelValue(expression : Expression) throws -> Expression {
		switch expression {
		case .constant(let name):
			guard let location = blockStart(name: name) else {
				throw ErrorMessage("Unknown label `\(name)`")
			}
			return .value(location)
		case _: return expression
		}
	}
	
	static func createAllocations(blocks : [Block]) -> [Allocation] {
		var allocations : [Allocation] = []
		
		for (blockId, block) in blocks.enumerated() {
			let start = block.origin
				?? allocations.last.map { $0.start + $0.length }
				?? 0
			let length = blockLength(block: block)
			let allocation = Allocation(start: start, length: length, blockId: blockId)
			allocations.append(allocation)
		}
		
		return allocations
	}
	
	static func blockLength(block : Block) -> Int {
		return block.data.map { $0.byteLength }.reduce(0, +)
	}
	
	func calculateBinarySize() -> Int {
		var furthestEnd = 0
		
		for allocation in allocations {
			let end = allocation.start + allocation.length
			
			if end > furthestEnd {
				furthestEnd = end
			}
		}
		
		return furthestEnd
	}
	
	func blockStart(name : String) -> Int? {
		for allocation in allocations {
			let block = blocks[allocation.blockId]
			if block.name == name {
				return allocation.start
			}
		}
		
		return nil
	}
}
