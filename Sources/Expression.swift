//
//  Expression.swift
//  Assembler
//
//  Created by Ulrik Damm on 08/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

public indirect enum Expression : Equatable {
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

struct ExpressionConstantExpansion {
	let constants : [String: Expression]
	
	func expand(_ expression : Expression, constantStack : [String] = []) throws -> Expression {
		let lowercased = expression.mapSubExpressions { expr -> Expression in
			switch expr {
			case .constant(let str): return .constant(str.lowercased())
			case _: return expr
			}
		}
		
		let newExpression = try lowercased.mapSubExpressions { expr throws -> Expression in
			if case .constant(let str) = expr, let value = constants[str] {
				guard !constantStack.contains(str) else {
					throw ErrorMessage("Cannot recursively expand constants")
				}
				return try expand(value, constantStack: constantStack + [str])
			} else {
				return expr
			}
		}
		
		return newExpression
	}
}
