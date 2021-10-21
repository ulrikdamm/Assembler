//
//  SpriteReader.swift
//  Assembler
//
//  Created by Ulrik Damm on 25/05/2018.
//  Copyright © 2018 Ufd.dk. All rights reserved.
//

import Foundation
import AppKit
import Dispatch

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
        sprites.reserveCapacity(verticalSprites * horizontalSprites)
        
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let data = bitmap.bitmapData!
        
        let colors = (0 ..< bitmap.pixelsWide * bitmap.pixelsHigh).map { i -> Float in
            let sum = Float(data[i * 3 + 0]) / 255 + Float(data[i * 3 + 1]) / 255 + Float(data[i * 3 + 2]) / 255
            return sum / 3
        }
        
		for y in 0 ..< verticalSprites {
			for x in 0 ..< horizontalSprites {
                sprites.append(spriteFromImage(colors, width: bitmap.pixelsWide, x: x * 8, y: y * 8))
			}
		}
		
        return sprites
	}
	
	static func pixelValueForColor(_ color : NSColor) -> Int {
		return Int((color.brightnessComponent * 3).rounded(.toNearestOrEven))
	}
	
	static func spriteFromImage(_ image : NSImage, x : Int, y : Int) -> Sprite {
		let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        return spriteFromImage(bitmap, x: x, y: y)
	}
    
    static func spriteFromImage(_ bitmap : NSBitmapImageRep, x : Int, y : Int) -> Sprite {
        var pixels : [Int] = []
        
        for offsetY in 0 ..< 8 {
            for offsetX in 0 ..< 8 {
                let pixel = bitmap.colorAt(x: x + offsetX, y: y + offsetY)!
                pixels.append(3 - pixelValueForColor(pixel.usingColorSpace(.deviceRGB)!))
            }
        }
        
        return Sprite(pixels: pixels)
    }
    
    static func spriteFromImage(_ colors : [NSColor], width : Int, x : Int, y : Int) -> Sprite {
        var pixels : [Int] = []
        
        for offsetY in 0 ..< 8 {
            for offsetX in 0 ..< 8 {
                let pixel = colors[(y + offsetY) * width + (x + offsetX)]
                pixels.append(3 - pixelValueForColor(pixel.usingColorSpace(.deviceRGB)!))
            }
        }
        
        return Sprite(pixels: pixels)
    }
    
    static func spriteFromImage(_ intensities : [Float], width : Int, x : Int, y : Int) -> Sprite {
        var pixels : [Int] = []
        pixels.reserveCapacity(8 * 8)
        
        for offsetY in 0 ..< 8 {
            for offsetX in 0 ..< 8 {
                let pixel = intensities[(y + offsetY) * width + (x + offsetX)]
                let value = Int((pixel * 3).rounded(.toNearestOrEven))
                pixels.append(3 - value)
            }
        }
        
        return Sprite(pixels: pixels)
    }
}
