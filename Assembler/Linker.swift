//
//  Linker.swift
//  Assembler
//
//  Created by Ulrik Damm on 08/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

class Linker {
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
	
	class func link(blocks : [Block]) throws -> [UInt8] {
		let allocations = createAllocations(blocks: blocks)
		let size = calculateBinarySize(allocations: allocations)
		var data = Array<UInt8>(repeating: 0, count: size)
		
		for allocation in allocations {
			var offset = 0
			for byte in blocks[allocation.blockId].data {
				switch byte {
				case .byte(let n):
					data[allocation.start + offset] = n
					offset += 1
				case .label(let name):
					if let start = blockStart(allocations: allocations, blocks: blocks, name: name) {
						data[allocation.start + offset] = UInt8(start & 0xff)
						data[allocation.start + offset + 1] = UInt8((start >> 8) & 0xff)
						offset += 2
					} else {
						throw ErrorMessage("Unknown label ’\(name)‘")
					}
				}
			}
		}
		
		return data
	}
	
	class func createAllocations(blocks : [Block]) -> [Allocation] {
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
	
	class func calculateBinarySize(allocations : [Allocation]) -> Int {
		var furthestEnd = 0
		
		for allocation in allocations {
			let end = allocation.start + allocation.length
			
			if end > furthestEnd {
				furthestEnd = end
			}
		}
		
		return furthestEnd
	}
	
	class func blockLength(block : Block) -> Int {
		return block.data.map { $0.byteLength }.reduce(0, +)
	}
	
	class func blockStart(allocations : [Allocation], blocks : [Block], name : String) -> Int? {
		for allocation in allocations {
			let block = blocks[allocation.blockId]
			if block.name == name {
				return allocation.start
			}
		}
		
		return nil
	}
}
