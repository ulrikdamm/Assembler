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
    func test_labels() throws {
        let source = [
            "label1: ld hl, label2",
            "label2: xor a"
        ]
        
        let initialState = State(source: source)
        guard let program = try AssemblyParser.getProgram(initialState)?.value else { throw ErrorMessage("Couldn't parse source") }
        
        XCTAssertEqual(program.blocks.count, 2)
        XCTAssertEqual(program.blocks[0].identifier, "label1")
        XCTAssertEqual(program.blocks[0].instructions.map(\.mnemonic), ["ld"])
        XCTAssertEqual(program.blocks[1].identifier, "label2")
        XCTAssertEqual(program.blocks[1].instructions.map(\.mnemonic), ["xor"])
    }
    
    func test_emptyLabels() throws {
        let source = [
            "label1: ld hl, label2",
            "label2:",
            "label3: xor a"
        ]
        
        let initialState = State(source: source)
        guard let program = try AssemblyParser.getProgram(initialState)?.value else { throw ErrorMessage("Couldn't parse source") }
        
        XCTAssertEqual(program.blocks.count, 3)
        XCTAssertEqual(program.blocks[0].identifier, "label1")
        XCTAssertEqual(program.blocks[0].instructions.map(\.mnemonic), ["ld"])
        XCTAssertEqual(program.blocks[1].identifier, "label2")
        XCTAssertEqual(program.blocks[1].instructions.map(\.mnemonic), [])
        XCTAssertEqual(program.blocks[2].identifier, "label3")
        XCTAssertEqual(program.blocks[2].instructions.map(\.mnemonic), ["xor"])
    }
    
    func test_parseLocalLabel() throws {
        let source = [
            "label1: ld hl, .label2",
            ".label2: ld bc, label2",
            "label2: ld de, label1.label2"
        ]
        
        let initialState = State(source: source)
        guard let program = try AssemblyParser.getProgram(initialState)?.value else { throw ErrorMessage("Couldn't parse source") }
        
        XCTAssertEqual(program.blocks.count, 3)
        
        XCTAssertEqual(program.blocks[0].identifier, "label1")
        XCTAssertEqual(program.blocks[0].parent, nil)
        XCTAssertEqual(program.blocks[0].instructions.map(\.description), ["ld hl, .label2"])
        
        XCTAssertEqual(program.blocks[1].identifier, "label2")
        XCTAssertEqual(program.blocks[1].parent, "label1")
        XCTAssertEqual(program.blocks[1].instructions.map(\.description), ["ld bc, label2"])
        
        XCTAssertEqual(program.blocks[2].identifier, "label2")
        XCTAssertEqual(program.blocks[2].instructions.map(\.description), ["ld de, label1.label2"])
        XCTAssertEqual(program.blocks[2].parent, nil)
    }
    
    func test_linkLocalLabel() throws {
        let source = [
            "label1: ld hl, .label2",
            ".label2: ld bc, label2",
            "label2: ld de, label1.label2",
            ".label2: ld sp, .label2"
        ]
        
        let initialState = State(source: source)
        guard let program = try AssemblyParser.getProgram(initialState)?.value else { throw ErrorMessage("Couldn't parse source") }
        
        let assembler = Assembler(instructionSet: GameboyInstructionSet(), constants: program.constants)
        let blocks = try program.blocks.map { block in try assembler.assembleBlock(label: block) }
        let bytes = try Linker(blocks: blocks).link()
        
        XCTAssertEqual(bytes, [
            0x21, 0x03, 0x00, // ld hl, .label2 (at 0x3)
            0x01, 0x06, 0x00, // ld bc, label2 (at 0x6)
            0x11, 0x03, 0x00, // ld de, label1.label2 (at 0x3)
            0x31, 0x09, 0x00, // ld sp, label2.label2 (at 0x9)
        ])
    }
    
    func test_failLinkUnknownLocalLabel() throws {
        let source = [
            "label1: ld hl, .label2",
            ".label2: ld bc, .label1"
        ]
        
        let initialState = State(source: source)
        guard let program = try AssemblyParser.getProgram(initialState)?.value else { throw ErrorMessage("Couldn't parse source") }
        
        let assembler = Assembler(instructionSet: GameboyInstructionSet(), constants: program.constants)
        let blocks = try program.blocks.map { block in try assembler.assembleBlock(label: block) }
        
        var didFail = false
        
        do {
            _ = try Linker(blocks: blocks).link()
        } catch let e as ErrorMessage where e.message.contains("Unknown label") {
            didFail = true
        }
        
        XCTAssert(didFail)
    }
    
	func test_linktimeExpressionEvaluation() {
		let source = [
			"label1: ld hl, label2",
			"[org(0x05)] label2: xor a"
		]
		
		let result = try! assembleProgram(source: source, instructionSet: GameboyInstructionSet())
		XCTAssertEqual(result, [0x21, 0x05, 0x00, 0x00, 0x00, 0xaf])
	}
    
    func test_linktimeEmptyLabels() {
        let source = [
            "label1: ld hl, label2",
            "label2:",
            "[org(0x05)] label3: xor a"
        ]
        
        let result = try! assembleProgram(source: source, instructionSet: GameboyInstructionSet())
        XCTAssertEqual(result, [0x21, 0x03, 0x00, 0x00, 0x00, 0xaf])
    }
    
    func test_linktimeEmptyLabelsAtEnd() {
        let source = [
            "label1: ld hl, label2",
            "label2:"
        ]
        
        let result = try! assembleProgram(source: source, instructionSet: GameboyInstructionSet())
        XCTAssertEqual(result, [0x21, 0x03, 0x00])
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
