//
//  Expression.swift
//  Assembler
//
//  Created by Ulrik Damm on 08/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

public indirect enum Expression {
	case value(Int)
	case string(String)
	case constant(String)
	case prefix(String, Expression)
	case suffix(Expression, String)
	case parens(Expression)
	case squareParens(Expression)
	case binaryExpr(Expression, String, Expression)
}

extension Expression {
	func reduced() -> Expression {
		switch self {
		case .value(let v): return .value(v)
		case .string(let str): return .string(str)
		case .constant(let str): return .constant(str)
		case .prefix("+", let expr):
			switch expr.reduced() {
			case .value(let n): return .value(n)
			case let reduced: return .prefix("+", reduced)
			}
		case .prefix("-", let expr):
			switch expr.reduced() {
			case .value(let n): return .value(-n)
			case let reduced: return .prefix("-", reduced)
			}
		case .prefix(let str, let expr): return .prefix(str, expr.reduced())
		case .suffix(let expr, let str): return .suffix(expr.reduced(), str)
		case .parens(let expr): return expr.reduced()
		case .squareParens(let expr):
			return .squareParens(expr.reduced())
		case .binaryExpr(let left, let op, let right):
			switch (left.reduced(), op, right.reduced()) {
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
				default: return .binaryExpr(.value(leftValue), op, .value(rightValue))
				}
			case (.string(let leftString), "+", .string(let rightString)):
				return .string(leftString + rightString)
			case (let leftReduced, _, let rightReduced):
				return .binaryExpr(leftReduced, op, rightReduced)
			}
		}
	}
	
	func mapSubExpressions(map : (Expression) throws -> Expression) rethrows -> Expression {
		switch self {
		case .prefix(let str, let expr):
			return .prefix(str, try expr.mapSubExpressions(map: map))
		case .suffix(let expr, let str): return .suffix(try expr.mapSubExpressions(map: map), str)
		case .parens(let expr): return .parens(try expr.mapSubExpressions(map: map))
		case .squareParens(let expr): return .squareParens(try expr.mapSubExpressions(map: map))
		case .binaryExpr(let left, let str, let right): return .binaryExpr(try left.mapSubExpressions(map: map), str, try right.mapSubExpressions(map: map))
		case _: return try map(self)
		}
	}
}

extension Expression : CustomStringConvertible, CustomDebugStringConvertible {
	public var description : String {
		switch self {
		case .value(let v): return "\(v)"
		case .string(let str): return "\"\(str)\""
		case .constant(let str): return "\(str)"
		case .prefix(let str, let expr): return "\(str)\(expr)"
		case .suffix(let expr, let str): return "\(expr)\(str)"
		case .parens(let expr): return "(\(expr))"
		case .squareParens(let expr): return "[\(expr)]"
		case .binaryExpr(let left, let str, let right): return "\(left) \(str) \(right)"
		}
	}
	
	public var debugDescription : String {
		switch self {
		case .value(let v): return "<v: \(v)>"
		case .string(let str): return "<s: \"\(str)\">"
		case .constant(let str): return "<c: \(str)>"
		case .prefix(let str, let expr): return "<pre: <\(str)>\(expr.debugDescription)>"
		case .suffix(let expr, let str): return "<suf: \(expr.debugDescription)<\(str)>>"
		case .parens(let expr): return "<p: \(expr.debugDescription)>"
		case .squareParens(let expr): return "<sp: \(expr.debugDescription)>"
		case .binaryExpr(let left, let str, let right): return "<be: \(left.debugDescription)<\(str)>\(right.debugDescription)>"
		}
	}
}

extension Expression : Equatable {
	public static func ==(lhs : Expression, rhs : Expression) -> Bool {
		switch (lhs, rhs) {
		case (.value(let v1), .value(let v2)) where v1 == v2: return true
		case (.string(let str1), .string(let str2)) where str1 == str2: return true
		case (.constant(let str1), .constant(let str2)) where str1 == str2: return true
		case (.prefix(let str1, let expr1), .prefix(let str2, let expr2)) where str1 == str2 && expr1 == expr2: return true
		case (.suffix(let expr1, let str1), .suffix(let expr2, let str2)) where str1 == str2 && expr1 == expr2: return true
		case (.parens(let expr1), .parens(let expr2)) where expr1 == expr2: return true
		case (.binaryExpr(let left1, let str1, let right1), .binaryExpr(let left2, let str2, let right2)) where left1 == left2 && str1 == str2 && right1 == right2: return true
		case _: return false
		}
	}
}
