//
//  SpriteReader.swift
//  Assembler
//
//  Created by Ulrik Damm on 25/05/2018.
//  Copyright © 2018 Ufd.dk. All rights reserved.
//

import Foundation
import AppKit

extension Array where Element == Int {
	func byteFromBits() -> UInt8 {
		var byte = UInt8()
		
		for i in 0 ..< 8 where self[i] > 0 {
			byte |= (1 << (7 - i))
		}
		
		return byte
	}
}

class SpriteReader {
	struct Error : Swift.Error { let message : String }
	
//	func readImage(from location : URL) throws -> NSImage {
//		guard let image = NSImage(contentsOf: location) else {
//			throw Error(message: "Image not found at location \(location.path)")
//		} 
//		
//		return image 
//	}
	
	struct Sprite {
		let pixels : [Int]
		
		func getAssemblyDataInstructions(line : Int = 0) -> Instruction {
			guard pixels.count == 8 * 8 else { fatalError("Invalid pixel count") }
			
			var bytes : [UInt8] = []
			
			for i in 0 ..< 8 {
				let line = pixels[(0 ..< 8).stride(by: i * 8)]
				
				let mostSignificantBits = line.map { ($0 >> 1) & 1 }.byteFromBits()
				let leastSignificantBits = line.map { $0 & 1 }.byteFromBits()
				
				bytes.append(mostSignificantBits)
				bytes.append(leastSignificantBits)
			}
			
			return Instruction(mnemonic: "db", operands: bytes.map { Expression.value(Int($0)) }, line: line)
		}
	}
	
	static func splitImageIntoSprites(_ image : NSImage) -> [Sprite] {
		let horizontalSprites = Int(image.size.width / 8)
		let verticalSprites = Int(image.size.height / 8)
		
		var sprites : [Sprite] = []
		
		for y in 0 ..< verticalSprites {
			for x in 0 ..< horizontalSprites {
				sprites.append(spriteFromImage(image, x: x * 8, y: y * 8))
			}
		}
		
		return sprites
	}
	
	static func pixelValueForColor(_ color : NSColor) -> Int {
		return Int((color.brightnessComponent * 3).rounded(.toNearestOrEven))
	}
	
	static func spriteFromImage(_ image : NSImage, x : Int, y : Int) -> Sprite {
		var pixels : [Int] = []
		
		let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
		
		for offsetY in 0 ..< 8 {
			for offsetX in 0 ..< 8 {
				let pixel = bitmap.colorAt(x: x + offsetX, y: y + offsetY)!
				pixels.append(3 - pixelValueForColor(pixel.usingColorSpace(.deviceRGB)!))
			}
		}
		
		return Sprite(pixels: pixels)
	}
}

extension NSImage {
	func getPixel(x: Int, y : Int) -> NSColor {
		self.lockFocus()
		defer { self.unlockFocus() }
		
		guard let color = NSReadPixel(NSPoint(x: CGFloat(x) + 0.5, y: (self.size.height - 1) - CGFloat(y) + 0.5)) else { fatalError("Pixel out of bounds") } 
		return color
	}
}
