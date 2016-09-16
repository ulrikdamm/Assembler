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
		
		let result = try! assembleProgram(source: source)
		XCTAssertEqual(result, [0x21, 0x05, 0x00, 0x00, 0x00, 0xaf])
	}
}
