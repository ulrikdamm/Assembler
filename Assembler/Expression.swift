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
			switch (left.reduce(), op, right.reduce()) {
			case (.value(let leftValue), _, .value(let rightValue)):
				switch op {
				case "+": return .value(leftValue + rightValue)
				case "-": return .value(leftValue - rightValue)
				case "*": return .value(leftValue * rightValue)
				case "/": return .value(leftValue / rightValue)
				case "&": return .value(leftValue & rightValue)
				case "|": return .value(leftValue | rightValue)
				case ">>": return .value(leftValue >> rightValue)
				case "<<": return .value(leftValue << rightValue)
				default: return .binaryExp(.value(leftValue), op, .value(rightValue))
				}
			case (.string(let leftString), "+", .string(let rightString)):
				return .string(leftString + rightString)
			case (let leftReduced, _, let rightReduced):
				return .binaryExp(leftReduced, op, rightReduced)
			}
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

extension Expression : Equatable {
	static func ==(lhs : Expression, rhs : Expression) -> Bool {
		switch (lhs, rhs) {
		case (.value(let v1), .value(let v2)) where v1 == v2: return true
		case (.string(let str1), .string(let str2)) where str1 == str2: return true
		case (.constant(let str1), .constant(let str2)) where str1 == str2: return true
		case (.prefix(let str1, let expr1), .prefix(let str2, let expr2)) where str1 == str2 && expr1 == expr2: return true
		case (.suffix(let expr1, let str1), .suffix(let expr2, let str2)) where str1 == str2 && expr1 == expr2: return true
		case (.parens(let expr1), .parens(let expr2)) where expr1 == expr2: return true
		case (.binaryExp(let left1, let str1, let right1), .binaryExp(let left2, let str2, let right2)) where left1 == left2 && str1 == str2 && right1 == right2: return true
		case _: return false
		}
	}
}
