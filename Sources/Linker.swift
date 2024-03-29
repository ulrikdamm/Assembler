//
//  Linker.swift
//  Assembler
//
//  Created by Ulrik Damm on 08/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

public enum Opcode : CustomStringConvertible {
	case byte(UInt8)
	case word(UInt16)
	case expression(Expression, ResultType)
	
	public enum ResultType { case uint16, uint8, int8relative }
	
	public var description : String {
		switch self {
		case .byte(let b): return String(b, radix: 16)
		case .word(let w): return String(w, radix: 16)
		case .expression(let expr, .uint16): return "\(expr.description) (uint16)"
		case .expression(let expr, .uint8): return "\(expr.description) (uint8)"
		case .expression(let expr, .int8relative): return "\(expr.description) (uint8 relative)"
		}
	}
	
	var byteLength : Int {
		switch self {
		case .byte(_): return 1
		case .word(_): return 2
		case .expression(_, .uint16): return 2
		case .expression(_, .uint8): return 1
		case .expression(_, .int8relative): return 1
		}
	}
	
	static func bytesFrom16bit(_ value : Int) throws -> [Opcode] {
		let n16 = try UInt16.fromInt(value: value)
		return [.byte(n16.lsb), .byte(n16.msb)]
	}
	
    func expandExpression(using constantExpander : ExpressionConstantExpansion, inParentLabel parent : String?, line : Int? = nil) throws -> Opcode {
        guard case let .expression(expr, resultType) = self else { return self }
        
        let expanded = try constantExpander.expand(expr, labelParent: parent, line: line)
        return .expression(expanded, resultType)
	}
}

extension Opcode : Equatable {
	public static func ==(lhs : Opcode, rhs : Opcode) -> Bool {
		switch (lhs, rhs) {
		case (.byte(let nl), .byte(let nr)) where nl == nr: return true
		case (.word(let nl), .word(let nr)) where nl == nr: return true
		case (.expression(let el, let rl), .expression(let er, let rr)) where el == er && rl == rr: return true
		case _: return false
		}
	}
}

struct Linker {
	struct Block {
		let name : String
        let parent : String?
		let origin : Int?
        let data : [(code : Opcode, line : Int?)]
		
        var length : Int { return data.map(\.code).map(\.byteLength).sum() }
        
        var nameAndParent : (String, String?) { (name, parent) }
        
        init(name : String, parent : String? = nil, origin : Int? = nil, data : [Opcode]) {
            self.name = name
            self.parent = parent
            self.origin = origin
            self.data = data.map { code in (code, nil) }
        }
        
        init(name : String, parent : String? = nil, origin : Int? = nil, data : [(code : Opcode, line : Int?)]) {
            self.name = name
            self.parent = parent
            self.origin = origin
            self.data = data
        }
	}
	
	struct Allocation {
		let start : Int
		let length : Int
		let blockId : Int
		
		var end : Int { return start + length }
	}
	
	struct Buffer {
		var data : [UInt8]
		var index : Int = 0
		
		init(size : Int) {
			data = [UInt8](repeating: 0, count: size)
		}
		
		mutating func append(_ values : UInt8...) {
			for value in values {
				data[index] = value
				index += 1
			}
		}
	}
	
	let blocks : [Block]
	let allocations : [Allocation]
	
	init(blocks : [Block]) {
		self.blocks = blocks
		self.allocations = Linker.createAllocations(blocks: blocks)
	}
	
	func link() throws -> [UInt8] {
		var buffer = Buffer(size: calculateBinarySize())
		
		for allocation in allocations {
			try copyAllocation(allocation, to: &buffer)
		}
		
		return buffer.data
	}
	
	func copyAllocation(_ allocation : Allocation, to buffer : inout Buffer) throws {
		buffer.index = allocation.start
		
		for (byte, line) in blocks[allocation.blockId].data {
			switch byte {
			case .byte(let n): buffer.append(n)
			case .word(let n): buffer.append(n.lsb, n.msb)
			case .expression(let expr, let type):
                do {
                    try appendExpression(expr, of: type, to: &buffer)
                } catch let error as ErrorMessage {
                    throw AssemblyError(error.message, line: line)
                }
			}	
		}
	}
	
	func appendExpression(_ expression : Expression, of type : Opcode.ResultType, to buffer : inout Buffer) throws {
		let value = try finalValue(of: expression)
		
		switch type {
		case .uint8:
			buffer.append(try UInt8.fromInt(value: value))
		case .uint16:
			let n16 = try UInt16.fromInt(value: value)
			buffer.append(n16.lsb, n16.msb)
		case .int8relative:
			let n16 = try UInt16.fromInt(value: value)
			let current = buffer.index + 1
			let difference = Int(n16) - Int(current)
			
			do {
				let value = try Int8.fromInt(value: difference)
				buffer.append(UInt8(bitPattern: value))
			} catch {
				throw ErrorMessage("Label out of range for relative jump (\(difference) bytes away)")
			}
		}
	}
	
	func finalValue(of expression : Expression) throws -> Int {
		let mapped = try expression.mapSubExpressions(map: replaceExpressionLabelValue)
		let reduced = mapped.reduced()
		
		guard case .value(let value) = reduced else {
			throw ErrorMessage("Invalid value `\(reduced)`")
		}
		
		return value
	}
	
	func replaceExpressionLabelValue(expression : Expression) throws -> Expression {
        guard case let .constant(name) = expression else { return expression }
        
        guard let location = findAllocation(name: name)?.start else { throw ErrorMessage("Unknown label `\(name)`") }
        return .value(location)
	}
	
	static func createAllocations(blocks : [Block]) -> [Allocation] {
		var allocations : [Allocation] = []
		
		for (blockId, block) in blocks.enumerated() {
			let start = block.origin ?? allocations.last?.end ?? 0
			let allocation = Allocation(start: start, length: block.length, blockId: blockId)
			allocations.append(allocation)
		}
		
		return allocations
	}
	
	func calculateBinarySize() -> Int { return allocations.map(\.end).max() ?? 0 }
	
	func blockForAllocation(_ allocation : Allocation) -> Block { return blocks[allocation.blockId] }
	
	func findAllocation(name : String) -> Allocation? {
        if let period = name.firstIndex(of: ".") {
            let parent = name[name.startIndex ..< period]
            let localName = name[name.index(after: period) ..< name.endIndex]
            
            return allocations.first { allocation in
                let block = blockForAllocation(allocation)
                return block.name == localName && block.parent != nil && block.parent! == parent
            }
        } else {
            return allocations.first { blockForAllocation($0).nameAndParent == (name, nil) }
        }
	}
}
