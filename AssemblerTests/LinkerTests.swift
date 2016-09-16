//
//  LinkerTests.swift
//  Assembler
//
//  Created by Ulrik Damm on 16/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

import XCTest
@testable import Assembler

class LinkerTests : XCTestCase {
	let block1 = Linker.Block(name: "block1", origin: nil, data: [.byte(0x01), .byte(0x02), .byte(0x03)])
	let block2 = Linker.Block(name: "block2", origin: nil, data: [.byte(0x04), .byte(0x05)])
	let block3 = Linker.Block(name: "block3", origin: 0x06, data: [.byte(0x06), .byte(0x07)])
	let block4 = Linker.Block(name: "block4", origin: nil, data: [.byte(0x08), .label("block2")])
	
	static let simpleExpression = Expression.binaryExp(.value(2), "+", .value(3))
	static let labelExpression = Expression.binaryExp(.constant("block2"), "+", .value(2))
	
	let block5 = Linker.Block(name: "block5", origin: nil, data: [.byte(0x09), .expression(expression: LinkerTests.simpleExpression, byteLength: 1)])
	let block6 = Linker.Block(name: "block6", origin: nil, data: [.byte(0x0a), .expression(expression: LinkerTests.labelExpression, byteLength: 2)])
	
	func testCreateBasicAllocations() {
		let linker = Linker(blocks: [block1, block2])
		XCTAssertEqual(linker.allocations.count, 2)
		
		XCTAssertEqual(linker.allocations[0].blockId, 0)
		XCTAssertEqual(linker.allocations[0].start, 0)
		XCTAssertEqual(linker.allocations[0].length, 3)
		
		XCTAssertEqual(linker.allocations[1].blockId, 1)
		XCTAssertEqual(linker.allocations[1].start, 3)
		XCTAssertEqual(linker.allocations[1].length, 2)
	}
	
	func testCreateOffsetAllocations() {
		let linker = Linker(blocks: [block1, block3])
		XCTAssertEqual(linker.allocations.count, 2)
		
		XCTAssertEqual(linker.allocations[0].blockId, 0)
		XCTAssertEqual(linker.allocations[0].start, 0)
		XCTAssertEqual(linker.allocations[0].length, 3)
		
		XCTAssertEqual(linker.allocations[1].blockId, 1)
		XCTAssertEqual(linker.allocations[1].start, 6)
		XCTAssertEqual(linker.allocations[1].length, 2)
	}
	
	func testBlockLength() {
		XCTAssertEqual(Linker.blockLength(block: block1), 3)
		XCTAssertEqual(Linker.blockLength(block: block2), 2)
		XCTAssertEqual(Linker.blockLength(block: block3), 2)
		XCTAssertEqual(Linker.blockLength(block: block4), 3)
	}
	
	func testCalculateBinarySize() {
		let linker = Linker(blocks: [block1, block2, block3, block4])
		XCTAssertEqual(linker.calculateBinarySize(), 11)
	}
	
	func testLinkBasicBlocks() {
		let linker = Linker(blocks: [block1, block2])
		let data = try! linker.link()
		XCTAssertEqual(data, [1, 2, 3, 4, 5])
	}
	
	func testLinkOriginBlocks() {
		let linker = Linker(blocks: [block1, block3])
		let data = try! linker.link()
		XCTAssertEqual(data, [1, 2, 3, 0, 0, 0, 6, 7])
	}
	
	func testLinkLabelBlocks() {
		let linker = Linker(blocks: [block1, block2, block4])
		let data = try! linker.link()
		XCTAssertEqual(data, [1, 2, 3, 4, 5, 8, 3, 0])
	}
	
	func testLinkUnkonwnLabel() {
		let linker = Linker(blocks: [block1, block4])
		do {
			let _ = try linker.link()
			XCTFail()
		} catch is ErrorMessage {
			// TODO: error message enum
		} catch {
			XCTFail()
		}
	}
	
	func testLinkSimpleExpression() {
		let linker = Linker(blocks: [block1, block5])
		let data = try! linker.link()
		XCTAssertEqual(data, [1, 2, 3, 9, 5])
	}
	
	func testLinkLabelExpression() {
		let linker = Linker(blocks: [block1, block2, block6])
		let data = try! linker.link()
		XCTAssertEqual(data, [1, 2, 3, 4, 5, 10, 5, 0])
	}
}
