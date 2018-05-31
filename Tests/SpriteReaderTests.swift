//
//  SpriteReaderTests.swift
//  AssemblerTests
//
//  Created by Ulrik Damm on 29/05/2018.
//  Copyright © 2018 Ufd.dk. All rights reserved.
//

import XCTest
@testable import Assembler

class SpriteReaderTests : XCTestCase {
	var singleSpriteTestImage : NSImage {
		let url = Bundle(for: SpriteReaderTests.self).url(forResource: "singleSprite", withExtension: "png")!
		let image = NSImage(contentsOf: url)!
		return image
	}
	
	var tiledSpriteTestImage : NSImage {
		let url = Bundle(for: SpriteReaderTests.self).url(forResource: "tiledSprite", withExtension: "png")!
		let image = NSImage(contentsOf: url)!
		return image
	}
	
	func test_splitAndToInstructions() {
		let pixelBytes = [
			0b0101_0101, 0b0101_0101,
			0b1010_1010, 0b1010_1010,
			0b0101_0101, 0b0101_0101,
			0b1010_1010, 0b1010_1010,
			0b0101_0101, 0b0101_0101,
			0b1010_1010, 0b1010_1010,
			0b0101_0101, 0b0101_0101,
			0b1010_1010, 0b1010_1010,
		]
		
		let correctInstruction = Instruction(mnemonic: "db", operands: pixelBytes.map { Expression.value($0) }, line: 0)
		
		let sprites = SpriteReader.splitImageIntoSprites(tiledSpriteTestImage)
		let checkeredSprite = sprites[8]
		let instruction = checkeredSprite.getAssemblyDataInstructions(line: 0)
		
		XCTAssertEqual(instruction, correctInstruction)
	}
	
	func test_colorToPixelValue() {
		XCTAssertEqual(SpriteReader.pixelValueForColor(NSColor(calibratedWhite: 0, alpha: 1).usingColorSpace(.deviceRGB)!), 0)
		XCTAssertEqual(SpriteReader.pixelValueForColor(NSColor(calibratedWhite: 0.3, alpha: 1).usingColorSpace(.deviceRGB)!), 1)
		XCTAssertEqual(SpriteReader.pixelValueForColor(NSColor(calibratedWhite: 0.6, alpha: 1).usingColorSpace(.deviceRGB)!), 2)
		XCTAssertEqual(SpriteReader.pixelValueForColor(NSColor(calibratedWhite: 1, alpha: 1).usingColorSpace(.deviceRGB)!), 3)
	}
	
	func test_splitPng() {
		let blackPixelData = Array(repeating: 3, count: 8 * 8)
		let whitePixelData = Array(repeating: 0, count: 8 * 8)
		
		let sprites = SpriteReader.splitImageIntoSprites(tiledSpriteTestImage)
		XCTAssertEqual(sprites[0].pixels, blackPixelData)
		XCTAssertEqual(sprites[3].pixels, whitePixelData)
	}
	
	func test_pngToSprite() {
		let pixelData = [
			3, 3, 2, 2, 1, 1, 0, 0,
			3, 3, 2, 2, 1, 1, 0, 0,
			0, 0, 3, 3, 2, 2, 1, 1,
			0, 0, 3, 3, 2, 2, 1, 1,
			1, 1, 0, 0, 3, 3, 2, 2,
			1, 1, 0, 0, 3, 3, 2, 2,
			2, 2, 1, 1, 0, 0, 3, 3,
			2, 2, 1, 1, 0, 0, 3, 3,
		]
		
		let sprite = SpriteReader.spriteFromImage(singleSpriteTestImage, x: 0, y: 0)
		
		XCTAssertEqual(sprite.pixels, pixelData)
	}
	
	func test_spriteToInstruction() {
		let pixelData = [
			0, 0, 1, 0, 1, 1, 1, 0,
			0, 0, 1, 0, 1, 1, 0, 1,
			0, 0, 2, 0, 2, 2, 2, 0,
			0, 0, 2, 0, 2, 2, 0, 2,
			0, 0, 3, 0, 3, 3, 3, 0,
			0, 0, 3, 0, 3, 3, 0, 3,
			0, 0, 1, 0, 1, 1, 1, 0,
			0, 0, 1, 0, 1, 1, 0, 1
		]
		
		let pixelBytes = [
			0b0000_0000, 0b0010_1110,
			0b0000_0000, 0b0010_1101,
			0b0010_1110, 0b0000_0000,
			0b0010_1101, 0b0000_0000,
			0b0010_1110, 0b0010_1110,
			0b0010_1101, 0b0010_1101,
			0b0000_0000, 0b0010_1110,
			0b0000_0000, 0b0010_1101
		]
		
		let correctInstruction = Instruction(mnemonic: "db", operands: pixelBytes.map { Expression.value($0) }, line: 0)
		
		let sprite = SpriteReader.Sprite(pixels: pixelData)
		let instruction = sprite.getAssemblyDataInstructions(line: 0)
		
		XCTAssertEqual(instruction, correctInstruction)
	}
}
