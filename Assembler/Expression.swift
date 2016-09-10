//
//  Expression.swift
//  Assembler
//
//  Created by Ulrik Damm on 08/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

indirect enum Expression {
	case value(Int)
	case string(String)
	case constant(String)
	case prefix(String, Expression)
	case suffix(Expression, String)
	case parens(Expression)
	case binaryExp(Expression, String, Expression)
}

extension Expression {
	func reduce() -> Expression {
		switch self {
		case .value(let v): return .value(v)
		case .string(let str): return .string(str)
		case .constant(let str): return .constant(str)
		case .prefix(let str, let expr): return .prefix(str, expr.reduce())
		case .suffix(let expr, let str): return .suffix(expr.reduce(), str)
		case .parens(let expr):
			let inner = expr.reduce()
			if case .value(let v) = inner { return .value(v) }
			return .parens(inner)
		case .binaryExp(let left, let op, let right):
			let leftReduced = left.reduce()
			let rightReduced = right.reduce()
			if case (.value(let leftValue), .value(let rightValue)) = (leftReduced,  rightReduced) {
				switch op {
				case "+": return .value(leftValue + rightValue)
				case "-": return .value(leftValue - rightValue)
				case "*": return .value(leftValue * rightValue)
				case "/": return .value(leftValue / rightValue)
				case "&": return .value(leftValue & rightValue)
				case "|": return .value(leftValue | rightValue)
				case ">>": return .value(leftValue >> rightValue)
				case "<<": return .value(leftValue << rightValue)
				default: return .binaryExp(leftReduced, op, rightReduced)
				}
			} else {
				return .binaryExp(leftReduced, op, rightReduced)
			}
			/*case .binaryExp(.value(let l), "+", .value(let r)): return .value(l + r)
			case .binaryExp(.value(let l), "-", .value(let r)): return .value(l - r)
			case .binaryExp(.value(let l), "*", .value(let r)): return .value(l * r)
			case .binaryExp(.value(let l), "/", .value(let r)): return .value(l / r)
			case .binaryExp(.value(let l), "%", .value(let r)): return .value(l % r)
			case .binaryExp(.value(let l), "<<", .value(let r)): return .value(l << r)
			case .binaryExp(.value(let l), ">>", .value(let r)): return .value(l >> r)
			case .binaryExp(.value(let l), "|", .value(let r)): return .value(l | r)
			case .binaryExp(.value(let l), "&", .value(let r)): return .value(l & r)
			case .binaryExp(let left, let str, let right): return .binaryExp(left.reduce(), str, right.reduce())*/
		}
	}
	
	func mapSubExpressions(map : (Expression) throws -> Expression) rethrows -> Expression {
		switch self {
		case .prefix(let str, let expr):
			return .prefix(str, try expr.mapSubExpressions(map: map))
		case .suffix(let expr, let str): return .suffix(try expr.mapSubExpressions(map: map), str)
		case .parens(let expr): return .parens(try expr.mapSubExpressions(map: map))
		case .binaryExp(let left, let str, let right): return .binaryExp(try left.mapSubExpressions(map: map), str, try right.mapSubExpressions(map: map))
		case _: return try map(self)
		}
	}
}

extension Expression : CustomStringConvertible, CustomDebugStringConvertible {
	var description : String {
		switch self {
		case .value(let v): return "\(v)"
		case .string(let str): return "\"\(str)\""
		case .constant(let str): return "\(str)"
		case .prefix(let str, let expr): return "\(str)\(expr)"
		case .suffix(let expr, let str): return "\(expr)\(str)"
		case .parens(let expr): return "(\(expr))"
		case .binaryExp(let left, let str, let right): return "\(left) \(str) \(right)"
		}
	}
	
	var debugDescription : String {
		switch self {
		case .value(let v): return "<v: \(v)>"
		case .string(let str): return "<s: \"\(str)\">"
		case .constant(let str): return "<c: \(str)>"
		case .prefix(let str, let expr): return "<pre: <\(str)>\(expr)>"
		case .suffix(let expr, let str): return "<suf: \(expr)<\(str)>>"
		case .parens(let expr): return "<p: \(expr)>"
		case .binaryExp(let left, let str, let right): return "<be: \(left)<\(str)>\(right)>"
		}
	}
}
