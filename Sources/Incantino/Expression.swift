// Expression.swift
// Boolean expression tokenizer, parser, evaluator, and cache.
// Implements the expression language spec for visibility conditions,
// action guards, validation rules, and flow skip conditions.

import Foundation

// MARK: - Token

/// Token types produced by the expression tokenizer.
enum Token: Sendable, Equatable {
    case and
    case or
    case not
    case lparen
    case rparen
    case op(ComparisonOp)
    case stringLit(String)
    case numberLit(Double)
    case boolLit(Bool)
    case path(String)
    case eof
}

/// Comparison operators.
public enum ComparisonOp: String, Sendable {
    case eq, neq, gt, lt, gte, lte, regexMatch
}

// MARK: - Parse Error

/// Errors that can occur during expression parsing.
public enum ExpressionParseError: Error, Sendable {
    case unterminatedString
    case invalidNumber(String)
    case unexpectedCharacter(Character)
    case unexpectedToken(String)
    case expectedToken(String)
    case trailingInput(String)
}

// MARK: - Tokenizer

/// Tokenizes an expression string into a sequence of tokens.
struct Tokenizer {
    /// Tokenize the input string. Throws ExpressionParseError on invalid input.
    static func tokenize(_ input: String) throws -> [Token] {
        var tokens: [Token] = []
        let chars = Array(input.unicodeScalars)
        var i = 0
        let n = chars.count

        while i < n {
            let c = chars[i]

            // Skip whitespace.
            if c.properties.isWhitespace {
                i += 1
                continue
            }

            // Two-character operators (checked first).
            if i + 1 < n {
                let c2 = chars[i + 1]
                let two = (c, c2)
                switch two {
                case ("=", "="):
                    tokens.append(.op(.eq)); i += 2; continue
                case ("!", "="):
                    tokens.append(.op(.neq)); i += 2; continue
                case (">", "="):
                    tokens.append(.op(.gte)); i += 2; continue
                case ("<", "="):
                    tokens.append(.op(.lte)); i += 2; continue
                case ("~", "="):
                    tokens.append(.op(.regexMatch)); i += 2; continue
                case ("&", "&"):
                    tokens.append(.and); i += 2; continue
                case ("|", "|"):
                    tokens.append(.or); i += 2; continue
                default:
                    break
                }
            }

            // Single-character operators and parens.
            if c == ">" {
                tokens.append(.op(.gt)); i += 1; continue
            }
            if c == "<" {
                tokens.append(.op(.lt)); i += 1; continue
            }
            if c == "(" {
                tokens.append(.lparen); i += 1; continue
            }
            if c == ")" {
                tokens.append(.rparen); i += 1; continue
            }
            if c == "!" {
                tokens.append(.not); i += 1; continue
            }

            // String literal (single quotes).
            if c == "'" {
                var j = i + 1
                while j < n && chars[j] != "'" {
                    j += 1
                }
                if j >= n {
                    throw ExpressionParseError.unterminatedString
                }
                let content = String(String.UnicodeScalarView(chars[(i + 1)..<j]))
                tokens.append(.stringLit(content))
                i = j + 1
                continue
            }

            // Number literal.
            // A minus sign starts a negative number only when the previous token
            // is NOT a value token (path, stringLit, numberLit, boolLit, rparen).
            let isDigit = c >= "0" && c <= "9"
            let isMinusPrefix = c == "-" && !_isValueToken(tokens.last)

            if isDigit || isMinusPrefix {
                var j = i
                if c == "-" { j += 1 }
                var hasDot = false
                while j < n {
                    let ch = chars[j]
                    if ch >= "0" && ch <= "9" {
                        j += 1
                    } else if ch == "." && !hasDot {
                        hasDot = true
                        j += 1
                    } else {
                        break
                    }
                }
                let numStr = String(String.UnicodeScalarView(chars[i..<j]))
                guard let val = Double(numStr) else {
                    throw ExpressionParseError.invalidNumber(numStr)
                }
                tokens.append(.numberLit(val))
                i = j
                continue
            }

            // Identifier (path or boolean keyword).
            if c.properties.isAlphabetic || c == "_" {
                var j = i + 1
                while j < n {
                    let ch = chars[j]
                    if ch.properties.isAlphabetic || (ch >= "0" && ch <= "9") || ch == "_" || ch == "." {
                        j += 1
                    } else {
                        break
                    }
                }
                let ident = String(String.UnicodeScalarView(chars[i..<j]))
                if ident == "true" {
                    tokens.append(.boolLit(true))
                } else if ident == "false" {
                    tokens.append(.boolLit(false))
                } else {
                    tokens.append(.path(ident))
                }
                i = j
                continue
            }

            // Unexpected character.
            throw ExpressionParseError.unexpectedCharacter(Character(c))
        }

        tokens.append(.eof)
        return tokens
    }

    /// Check if a token is a "value" token for negative-number prefix disambiguation.
    private static func _isValueToken(_ token: Token?) -> Bool {
        guard let token = token else { return false }
        switch token {
        case .path, .stringLit, .numberLit, .boolLit, .rparen:
            return true
        default:
            return false
        }
    }
}

// MARK: - Expression AST

/// The expression AST. Uses indirect enum for recursive nodes.
public indirect enum Expression: Sendable {
    case path(String)
    case stringLiteral(String)
    case numberLiteral(Double)
    case boolLiteral(Bool)
    case comparison(Expression, ComparisonOp, Expression)
    case not(Expression)
    case and(Expression, Expression)
    case or(Expression, Expression)
}

// MARK: - Parser

/// Recursive descent parser for boolean expressions.
/// Precedence (lowest to highest): or < and < not < comparison/primary.
struct ExpressionParser {
    private let tokens: [Token]
    private var pos: Int = 0

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    private func peek() -> Token {
        tokens[pos]
    }

    private mutating func advance() -> Token {
        let t = tokens[pos]
        pos += 1
        return t
    }

    /// Parse the full expression. Throws on malformed input.
    mutating func parse() throws -> Expression {
        let node = try parseOr()
        if peek() != .eof {
            throw ExpressionParseError.trailingInput("\(peek())")
        }
        return node
    }

    private mutating func parseOr() throws -> Expression {
        var left = try parseAnd()
        while peek() == .and || peek() == .or {
            if peek() == .or {
                _ = advance()
                let right = try parseAnd()
                left = .or(left, right)
            } else {
                break
            }
        }
        return left
    }

    private mutating func parseAnd() throws -> Expression {
        var left = try parseUnary()
        while peek() == .and {
            _ = advance()
            let right = try parseUnary()
            left = .and(left, right)
        }
        return left
    }

    private mutating func parseUnary() throws -> Expression {
        if peek() == .not {
            _ = advance()
            let inner = try parseUnary()
            return .not(inner)
        }
        return try parsePrimary()
    }

    private mutating func parsePrimary() throws -> Expression {
        // Parenthesized sub-expression.
        if peek() == .lparen {
            _ = advance()
            let node = try parseOr()
            guard peek() == .rparen else {
                throw ExpressionParseError.expectedToken(")")
            }
            _ = advance()
            return node
        }

        let left = try parseValue()

        // Check for comparison operator.
        if case .op(let op) = peek() {
            _ = advance()
            let right = try parseValue()
            return .comparison(left, op, right)
        }

        return left
    }

    private mutating func parseValue() throws -> Expression {
        let t = peek()
        switch t {
        case .boolLit(let b):
            _ = advance()
            return .boolLiteral(b)
        case .stringLit(let s):
            _ = advance()
            return .stringLiteral(s)
        case .numberLit(let n):
            _ = advance()
            return .numberLiteral(n)
        case .path(let p):
            _ = advance()
            return .path(p)
        default:
            throw ExpressionParseError.unexpectedToken("\(t)")
        }
    }
}

// MARK: - ExpressionEvaluator

/// Evaluates expression ASTs against a scope.
public enum ExpressionEvaluator {
    /// Evaluate an expression AST to a boolean result.
    public static func evaluate(_ expr: Expression, scope: any ScopeReading) -> Bool {
        switch expr {
        case .boolLiteral(let b):
            return b
        case .path(let p):
            return scope.resolve(p).isTruthy
        case .stringLiteral(let s):
            return !s.isEmpty
        case .numberLiteral(let n):
            return n != 0
        case .not(let inner):
            return !evaluate(inner, scope: scope)
        case .and(let left, let right):
            // Short-circuit: if left is false, don't evaluate right.
            if !evaluate(left, scope: scope) { return false }
            return evaluate(right, scope: scope)
        case .or(let left, let right):
            // Short-circuit: if left is true, don't evaluate right.
            if evaluate(left, scope: scope) { return true }
            return evaluate(right, scope: scope)
        case .comparison(let left, let op, let right):
            return evaluateComparison(left, op, right, scope: scope)
        }
    }

    // MARK: Comparison evaluation

    private static func evaluateComparison(
        _ left: Expression, _ op: ComparisonOp, _ right: Expression,
        scope: any ScopeReading
    ) -> Bool {
        let lv = resolveToScopeValue(left, scope: scope)
        let rv = resolveToScopeValue(right, scope: scope)

        switch op {
        case .eq: return compareEq(lv, rv)
        case .neq: return !compareEq(lv, rv)
        case .gt, .lt, .gte, .lte: return compareOrdered(lv, rv, op: op)
        case .regexMatch: return compareRegex(lv, rv)
        }
    }

    /// Resolve an AST node to a ScopeValue for use in comparisons.
    private static func resolveToScopeValue(
        _ node: Expression, scope: any ScopeReading
    ) -> ScopeValue {
        switch node {
        case .path(let p): return scope.resolve(p)
        case .stringLiteral(let s): return .text(s)
        case .numberLiteral(let n): return .number(n)
        case .boolLiteral(let b): return .bool(b)
        default:
            // Compound expression: evaluate to bool, wrap in .bool.
            return .bool(evaluate(node, scope: scope))
        }
    }

    // MARK: Equality

    /// Equality with type coercion cascade.
    private static func compareEq(_ left: ScopeValue, _ right: ScopeValue) -> Bool {
        // 1. Numeric.
        if let ld = left.doubleValue, let rd = right.doubleValue {
            return ld == rd
        }
        // 2. Boolean.
        if let lb = left.boolValue, let rb = right.boolValue {
            return lb == rb
        }
        // 3. String.
        if let ls = left.stringValue, let rs = right.stringValue {
            return ls == rs
        }
        // 4. Both empty.
        if case .empty = left, case .empty = right {
            return true
        }
        // 5. Truthiness fallback.
        return left.isTruthy == right.isTruthy
    }

    // MARK: Ordered comparison

    private static func compareOrdered(
        _ left: ScopeValue, _ right: ScopeValue, op: ComparisonOp
    ) -> Bool {
        // 1. Numeric.
        if let ld = left.doubleValue, let rd = right.doubleValue {
            switch op {
            case .gt: return ld > rd
            case .lt: return ld < rd
            case .gte: return ld >= rd
            case .lte: return ld <= rd
            default: return false
            }
        }
        // 2. String fallback.
        if let ls = left.stringValue, let rs = right.stringValue {
            switch op {
            case .gt: return ls > rs
            case .lt: return ls < rs
            case .gte: return ls >= rs
            case .lte: return ls <= rs
            default: return false
            }
        }
        // 3. Neither: "ordered same" -- >= and <= return true, > and < return false.
        return op == .gte || op == .lte
    }

    // MARK: Regex match

    private static func compareRegex(_ left: ScopeValue, _ right: ScopeValue) -> Bool {
        guard let text = left.stringValue, let pattern = right.stringValue else {
            return false
        }
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}

// MARK: - ExpressionCache

/// Thread-safe cache for parsed expression ASTs.
/// Keyed by the original expression string. Only successful parses are cached.
public final class ExpressionCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [String: Expression] = [:]

    public init() {}

    /// Get a cached expression or parse and cache it. Returns nil on parse failure.
    public func get(_ input: String) -> Expression? {
        lock.lock()
        if let cached = cache[input] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // Parse outside the lock.
        guard let tokens = try? Tokenizer.tokenize(input) else { return nil }
        var parser = ExpressionParser(tokens: tokens)
        guard let expr = try? parser.parse() else { return nil }

        lock.lock()
        cache[input] = expr
        lock.unlock()
        return expr
    }
}

// MARK: - Convenience top-level evaluator

/// Global shared expression cache.
private let sharedCache = ExpressionCache()

/// Evaluate an expression string against a scope.
///
/// Returns true for nil/empty/unparseable expressions (forward-compatible).
/// Uses a shared thread-safe cache for parsed ASTs.
public func evaluate(expression: String?, scope: any ScopeReading) -> Bool {
    guard let expr = expression, !expr.trimmingCharacters(in: .whitespaces).isEmpty else {
        return true
    }
    guard let ast = sharedCache.get(expr) else {
        // Forward-compatible: unparseable expressions return true.
        return true
    }
    return ExpressionEvaluator.evaluate(ast, scope: scope)
}
