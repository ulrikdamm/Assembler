//
//  ParserTests.swift
//  Assembler
//
//  Created by Ulrik Damm on 11/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

import XCTest
@testable import Assembler

class ParserTests : XCTestCase {
	func testGetChar() { 
		let (character, state) = State(source: "a").getChar()!
		XCTAssertEqual(character, "a")
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetCharFail() {
		XCTAssertNil(State(source: "").getChar())
	}
	
	func testGetNumericChar() { 
		let (number, state) = State(source: "1").getNumericChar()!
		XCTAssertEqual(number, "1")
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetNumericCharFail() { 
		XCTAssertNil(State(source: "a").getNumericChar())
	}
	
	func testGetAlphaChar() { 
		let (character, state) = State(source: "_").getAlphaChar()!
		XCTAssertEqual(character, "_")
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetAlphaCharFail() { 
		XCTAssertNil(State(source: "-").getAlphaChar())
	}
	
	func testGetIdentifier() { 
		let (name, state) = State(source: "abc_123").getIdentifier()!
		XCTAssertEqual(name, "abc_123")
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetStringFail() { 
		XCTAssertNil(State(source: "123_abc").getIdentifier())
	}
	
	func testGetNumber() { 
		let (number, state) = State(source: "123").getNumber()!
		XCTAssertEqual(number, 123)
		XCTAssertTrue(state.atEnd)
	}
	
	// Regression test: would fail to read 0
	func testGetNumberZero() { 
		let (number, state) = State(source: "0").getNumber()!
		XCTAssertEqual(number, 0)
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetNumberDecimal() { 
		let (number, state) = State(source: "0d123").getNumber()!
		XCTAssertEqual(number, 123)
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetNumberHex() { 
		let (number, state) = State(source: "0x100").getNumber()!
		XCTAssertEqual(number, 0x100)
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetNumberBinary() { 
		let (number, state) = State(source: "0b00011011").getNumber()!
		XCTAssertEqual(number, 0b00011011)
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetNumberBinarySeparators() { 
		let (number, state) = State(source: "0b0001_1011").getNumber()!
		XCTAssertEqual(number, 0b0001_1011)
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetNumberFail() { 
		XCTAssertNil(State(source: "abc").getNumber())
	}
	
	func testGetStringLiteral() {
		let (string, state) = try! State(source: "\"abc\"").getStringLiteral()!
		XCTAssertEqual(string, "abc")
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetStringLiteralNoEnd() {
		do {
			let _ = try State(source: "\"abc").getStringLiteral()
			XCTFail()
		} catch let error as State.ParseError {
			switch error.reason {
			case .expectedMatch(match: "\""): break
			case _: XCTFail()
			}
		} catch {
			XCTFail()
		}
	}
	
	func testGetStringLiteralFail() {
		try! XCTAssertNil(State(source: "abc").getStringLiteral())
	}
}
