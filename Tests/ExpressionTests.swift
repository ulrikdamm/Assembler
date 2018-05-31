//
//  ExpressionTests.swift
//  Assembler
//
//  Created by Ulrik Damm on 11/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

import XCTest
@testable import Assembler

class ExpressionTests : XCTestCase {
	func assert(_ code : String, parsesAs output : Expression) {
		let result : Expression
		
		do {
			let state = State(source: code)
			guard let r = try AssemblyParser.getExpression(state)?.value else {
				XCTFail("Couldn't parse expression: `\(code)`"); return
			}
			result = r
		} catch let error as State.ParseError {
			XCTFail("Couldn't parse expression: `\(error.localizedDescription)`"); return
		} catch let error {
			XCTFail("Couldn't parse expression: `\(error)`"); return
		}
		
		XCTAssertEqual(output, result, "Wrong result: `\(result.debugDescription)`, expected `\(output.debugDescription)`")
	}
	
	func assert(_ expression1 : Expression, reducesTo expression2 : Expression) {
		XCTAssertEqual(expression1.reduced(), expression2.reduced(), "Wrong reduced result: `\(expression1.debugDescription)`, expected `\(expression1.debugDescription)`")
	}
	
	func assert(_ expression1 : Expression, expandsTo expression2 : Expression, constants: [String: Expression]) {
		let expander = ExpressionConstantExpansion(constants: constants)
		XCTAssertNoThrow(try expander.expand(expression1))
		XCTAssertEqual(try! expander.expand(expression1), expression2)
	}
}

class ExpressionParsingTests : ExpressionTests {
	func testInteger()	{ assert("123", parsesAs: .value(123)) }
	func testString()	{ assert("\"abc\"", parsesAs: .string("abc")) }
	func testConstant()	{ assert("abc", parsesAs: .constant("abc")) }
	func testPrefix()	{ assert("+abc", parsesAs: .prefix("+", .constant("abc"))) }
	func testSuffix()	{ assert("abc+", parsesAs: .suffix(.constant("abc"), "+")) }
	func testOperator()	{ assert("abc + 123", parsesAs: .binaryExpr(.constant("abc"), "+", .value(123))) }
	func testParens()	{ assert("(123)", parsesAs: .parens(.value(123))) }
}

class ExpressionReduceTests : ExpressionTests {
	func testAddIntegers()			{ assert(.binaryExpr(.value(5), "+", .value(10)), reducesTo: .value(15)) }
	func testSubtractIntegers()		{ assert(.binaryExpr(.value(10), "-", .value(2)), reducesTo: .value(8)) }
	func testMultiplyIntegers()		{ assert(.binaryExpr(.value(10), "*", .value(2)), reducesTo: .value(20)) }
	func testDivideIntegers()		{ assert(.binaryExpr(.value(10), "/", .value(2)), reducesTo: .value(5)) }
	func testShiftLeftIntegers()	{ assert(.binaryExpr(.value(0x08), "<<", .value(2)), reducesTo: .value(0x20)) }
	func testShiftRightIntegers()	{ assert(.binaryExpr(.value(0x08), ">>", .value(2)), reducesTo: .value(0x02)) }
	func testLogicAndIntegers()		{ assert(.binaryExpr(.value(0xe), "&", .value(0x7)), reducesTo: .value(0x6)) }
	func testLogicOrIntegers()		{ assert(.binaryExpr(.value(0x8), "|", .value(0x7)), reducesTo: .value(0xf)) }
	func testIntegerParens()		{ assert(.parens(.value(123)), reducesTo: .value(123)) }
	func testConstantParens()		{ assert(.parens(.constant("abc")), reducesTo: .parens(.constant("abc"))) }
	func testAddStrings()			{ assert(.binaryExpr(.string("abc"), "+", .string("def")), reducesTo: .string("abcdef")) }
	func testRecursivereduced()		{ assert(.parens(.parens(.parens(.parens(.binaryExpr(.value(1), "+", .value(2)))))), reducesTo: .value(3)) }
	func testPositiveValuePrefix()	{ assert(.prefix("+", .value(123)), reducesTo: .value(123)) }
	func testNegativeValuePrefix()	{ assert(.prefix("-", .value(123)), reducesTo: .value(-123)) }
	func testNegativeExprPrefix()	{ assert(.prefix("-", .parens(.binaryExpr(.value(5), "+", .value(10)))), reducesTo: .value(-15)) }
}

class ExpressionExpandTest : ExpressionTests {
	func testExpandNothing()           { assert(.value(0), expandsTo: .value(0), constants: [:]) }
	func testExpandConstant()          { assert(.constant("a"), expandsTo: .value(123), constants: ["a": .value(123)]) }
	func testExpandConstantRecursive() { assert(.constant("a"), expandsTo: .value(123), constants: ["a": .constant("b"), "b": .value(123)]) }
	func testExpandUnknownConstant()   { assert(.constant("a"), expandsTo: .constant("a"), constants: [:]) }
	func testExpandNestedConstant()   { assert(.binaryExpr(.value(5), "+", .constant("a")), expandsTo: .binaryExpr(.value(5), "+", .value(123)), constants: ["a": .value(123)]) }
	func testExpandMultipleConstants()   { assert(.binaryExpr(.constant("a"), "+", .constant("b")), expandsTo: .binaryExpr(.value(123), "+", .value(456)), constants: ["a": .value(123), "b": .value(456)]) }
}
