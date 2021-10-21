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
        var state = ParserState(source: "a")
        XCTAssertEqual(state.getChar(), "a")
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetCharFail() {
        var state = ParserState(source: "")
		XCTAssertNil(state.getChar())
	}
	
	func testGetNumericChar() {
        var state = ParserState(source: "1")
		XCTAssertEqual(state.getNumericChar(), "1")
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetNumericCharFail() {
        var state = ParserState(source: "a")
		XCTAssertNil(state.getNumericChar())
	}
	
	func testGetAlphaChar() {
        var state = ParserState(source: "_")
        XCTAssertEqual(state.getAlphaChar(), "_")
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetAlphaCharFail() {
        var state = ParserState(source: "-")
		XCTAssertNil(state.getAlphaChar())
	}
	
	func testGetIdentifier() {
        var state = ParserState(source: "abc_123")
        XCTAssertEqual(state.getIdentifier(), "abc_123")
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetStringFail() {
        var state = ParserState(source: "123_abc")
		XCTAssertNil(state.getIdentifier())
	}
	
	func testGetNumber() {
        var state = ParserState(source: "123")
        XCTAssertEqual(state.getNumber(), 123)
		XCTAssertTrue(state.atEnd)
	}
	
	// Regression test: would fail to read 0
	func testGetNumberZero() {
        var state = ParserState(source: "0")
        XCTAssertEqual(state.getNumber(), 0)
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetNumberDecimal() {
        var state = ParserState(source: "0d123")
        XCTAssertEqual(state.getNumber(), 123)
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetNumberHex() {
        var state = ParserState(source: "0x100")
        XCTAssertEqual(state.getNumber(), 0x100)
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetNumberBinary() {
        var state = ParserState(source: "0b00011011")
        XCTAssertEqual(state.getNumber(), 0b00011011)
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetNumberBinarySeparators() {
        var state = ParserState(source: "0b0001_1011")
        XCTAssertEqual(state.getNumber(), 0b0001_1011)
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetNumberFail() {
        var state = ParserState(source: "abc")
		XCTAssertNil(state.getNumber())
	}
	
	func testGetStringLiteral() throws {
        var state = ParserState(source: "\"abc\"")
        XCTAssertEqual(try state.getStringLiteral(), "abc")
		XCTAssertTrue(state.atEnd)
	}
	
	func testGetStringLiteralNoEnd() {
        var state = ParserState(source: "\"abc")
        
		do {
			let _ = try state.getStringLiteral()
			XCTFail()
		} catch let error as ParserState.ParseError {
			switch error.reason {
			case .expectedMatch(match: "\""): break
			case _: XCTFail()
			}
		} catch {
			XCTFail()
		}
	}
	
	func testGetStringLiteralFail() {
        var state = ParserState(source: "abc")
		try! XCTAssertNil(state.getStringLiteral())
	}
    
    func testGetEscapedQuoteStringLiteral() throws {
        var state = ParserState(source: "\"a\\\"b\"")
        XCTAssertEqual(try state.getStringLiteral(), "a\"b")
        XCTAssert(state.atEnd)
    }
    
    func testGetEscapedSlashStringLiteral() throws {
        var state = ParserState(source: "\"a\\\\b\"")
        XCTAssertEqual(try state.getStringLiteral(), "a\\b")
        XCTAssert(state.atEnd)
    }
    
    func testGetEscapedUnicodeStringLiteral() throws {
        var state = ParserState(source: "\"1\\u202\"")
        XCTAssertEqual(try state.getStringLiteral(), "1 2")
        XCTAssert(state.atEnd)
    }
    
    func testGetInvalidEscapedUnicodeStringLiteral() throws {
        var state = ParserState(source: "\"1\\u2\"")
        
        do {
            let _ = try state.getStringLiteral()
            XCTFail()
        } catch let error as ParserState.ParseError {
            switch error.reason {
            case .invalidUnicodeEscape: break
            case _: XCTFail()
            }
        } catch {
            XCTFail()
        }
    }
    
    func testGetInvalidEscapedStringLiteral() throws {
        var state = ParserState(source: "\"a\\xb\"")
        
        do {
            let _ = try state.getStringLiteral()
            XCTFail()
        } catch let error as ParserState.ParseError {
            switch error.reason {
            case .invalidEscape(value: "x"): break
            case _: XCTFail()
            }
        } catch {
            XCTFail()
        }
    }
    
    func testSkipWhitespace() {
        var state = ParserState(source: " \t \n ")
        state.skipWhitespace(includingLineBreaks: true)
        XCTAssert(state.atEnd)
    }
    
    func testSkipComment() {
        var state = ParserState(source: "#some comment whatever\n")
        state.skipComments()
        XCTAssert(state.match("\n"))
        XCTAssert(state.atEnd)
    }
    
    func testSkipWhitespaceAndComment() {
        var state = ParserState(source: "#some comment whatever\n#Another comment\n")
        state.skipCommentsAndWhitespace()
        XCTAssert(state.atEnd)
    }
    
    func testSkipWhitespaceAndCommentNoLineBreaks() {
        var state = ParserState(source: "#some comment whatever\n#Another comment\n")
        state.skipCommentsAndWhitespace(includingLineBreaks: false)
        XCTAssert(state.match("\n#Another"))
    }
}
