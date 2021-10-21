//
//  AssemblyParserTests.swift
//  AssemblerTests
//
//  Created by Ulrik Damm on 20/10/2021.
//  Copyright © 2021 Ufd.dk. All rights reserved.
//

import XCTest
@testable import Assembler

class AssemblyParserTests : XCTestCase {
    func testConstantDefine() throws {
        var state = ParserState(source: [
            "constant1 = 1",
            "constant2 = 2"
        ])
        
        let program = try state.getProgram()
        
        XCTAssertEqual(program.constants.count, 2)
        XCTAssertEqual(program.constants["constant1"], Expression.value(1))
        XCTAssertEqual(program.constants["constant2"], Expression.value(2))
    }
    
    func testConstantAfterLabel() throws {
        var state = ParserState(source: [
            "label:",
            "constant = 1"
        ])
        
        let program = try state.getProgram()
        
        XCTAssertEqual(program.blocks.count, 1)
        XCTAssertEqual(program.blocks[0].identifier, "label")
        
        XCTAssertEqual(program.constants.count, 1)
        XCTAssertEqual(program.constants["constant"], Expression.value(1))
    }
    
    func testLabelAfterLabel() throws {
        var state = ParserState(source: [
            "label1:",
            "label2:"
        ])
        
        let program = try state.getProgram()
        
        XCTAssertEqual(program.blocks.count, 2)
        XCTAssertEqual(program.blocks[0].identifier, "label1")
        XCTAssertEqual(program.blocks[1].identifier, "label2")
    }
    
    func testErrorLineNumber() {
        var state = ParserState(source: [
            "line = 1",
            "#line 2",
            "line3:",
            "#line 4",
            "#line 5",
            "xor a; ei #line 6",
            "line7: xor a",
            "",
            "line9 = \"\\n\"",
            "1"
        ])
        
        do {
            let _ = try state.getProgram()
            XCTFail()
        } catch let error as ParserState.AssemblyParseError {
            XCTAssertEqual(error.state.line, 10)
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testParseInstruction() throws {
        var state = ParserState(source: "ld a, 2")
        
        guard let instruction = try state.getInstruction() else { XCTFail(); return }
        
        XCTAssert(state.atEnd)
        XCTAssertEqual(instruction.mnemonic, "ld")
        XCTAssertEqual(instruction.operands.count, 2)
        XCTAssertEqual(instruction.operands[0], .constant("a"))
        XCTAssertEqual(instruction.operands[1], .value(2))
        XCTAssertEqual(instruction.line, 1)
    }
    
    func testParseMultilineInstruction() throws {
        var state = ParserState(source: [
            "ld a, 2",
            ""
        ])
        
        guard let instruction = try state.getInstruction() else { XCTFail(); return }
        XCTAssertEqual(instruction.line, 1)
    }
}
