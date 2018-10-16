//
//  IntegrationTests.swift
//  Assembler
//
//  Created by Ulrik Damm on 16/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

import XCTest
@testable import Assembler

class IntegrationTests : XCTestCase {
	func test_linktimeExpressionEvaluation() {
		let source = [
			"label1: ld hl, label2",
			"[org(0x05)] label2: xor a"
		]
		
		let result = try! assembleProgram(source: source, instructionSet: GameboyInstructionSet())
		XCTAssertEqual(result, [0x21, 0x05, 0x00, 0x00, 0x00, 0xaf])
	}
	
	func test_relativeJumps() {
		let source = [
			"label1: db 1, 2, 3",
			"label2: db 4, 5, 6",
			"label3: db 7, 8, 9; jr label2"
		]
		
		let result = try! assembleProgram(source: source, instructionSet: GameboyInstructionSet())
		XCTAssertEqual(result, [1, 2, 3, 4, 5, 6, 7, 8, 9, 0x18, 0xf8])
	}
	
//	func test_smileyExample() {
//		let sourceURL = Bundle(for: IntegrationTests.self).url(forResource: "smiley", withExtension: "asm")!
//		let source = try! String(contentsOf: sourceURL)
//		let result = try! assembleProgram(source: [source], instructionSet: GameboyInstructionSet())
//		XCTAssertEqual(result.count, 0x8000)
//		XCTAssertEqual(Set(result).hashValue, 4619504349562551178)
//	}
//	
//	func test_helloWorldExample() {
//		let sourceURL = Bundle(for: IntegrationTests.self).url(forResource: "helloworld", withExtension: "asm")!
//		let source = try! String(contentsOf: sourceURL)
//		let result = try! assembleProgram(source: [source], instructionSet: GameboyInstructionSet())
//		XCTAssertEqual(result.count, 0x8000)
//		XCTAssertEqual(Set(result).hashValue, -1368561330137217411)
//	}
//	
//	func test_movementExample() {
//		let sourceURL = Bundle(for: IntegrationTests.self).url(forResource: "movement", withExtension: "asm")!
//		let source = try! String(contentsOf: sourceURL)
//		let result = try! assembleProgram(source: [source], instructionSet: GameboyInstructionSet())
//		XCTAssertEqual(result.count, 0x8000)
//		XCTAssertEqual(Set(result).hashValue, -1986615222034599920)
//	}
	
	//func test_performance() {
	//	let sourceURL = Bundle(for: IntegrationTests.self).url(forResource: "movement", withExtension: "asm")!
	//	let source = try! String(contentsOf: sourceURL)
	//	
	//	measure {
	//		for _ in 0..<10 {
	//			let _ = try! assembleProgram(source: [source], instructionSet: GameboyInstructionSet())
	//		}
	//	}
	//}
}
