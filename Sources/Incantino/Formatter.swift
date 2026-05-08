// Formatter.swift
// Pipe-based value transformation system for interpolation.
// Parses and applies formatter chains: {{path | formatter1 | formatter2:arg}}.

import Foundation

// MARK: - Parsed formatter

/// A single formatter stage parsed from a pipe expression.
struct ParsedFormatter {
    let name: String
    let argument: FormatterArgument?
}

/// A formatter argument (the part after `:` in `name:arg`).
enum FormatterArgument {
    case string(String)
    case number(Double)
    case bool(Bool)
}

// MARK: - Pipe parsing

/// Parses the inner content of a `{{...}}` token into a path and formatter chain.
/// Returns the path and an array of parsed formatters (empty if no pipes).
func parsePipeExpression(_ content: String) -> (path: String, formatters: [ParsedFormatter]) {
    let segments = splitOnPipesQuoteAware(content)
    guard segments.count > 1 else {
        return (content.trimmingCharacters(in: .whitespaces), [])
    }

    let path = segments[0].trimmingCharacters(in: .whitespaces)
    var formatters: [ParsedFormatter] = []

    for i in 1..<segments.count {
        let segment = segments[i].trimmingCharacters(in: .whitespaces)
        if segment.isEmpty { continue }

        // Split on first `:` to get name and optional argument.
        if let colonIdx = segment.firstIndex(of: ":") {
            let name = segment[segment.startIndex..<colonIdx]
                .trimmingCharacters(in: .whitespaces)
            let argRaw = segment[segment.index(after: colonIdx)...]
                .trimmingCharacters(in: .whitespaces)
            let argument = parseArgument(argRaw)
            formatters.append(ParsedFormatter(name: name, argument: argument))
        } else {
            formatters.append(ParsedFormatter(name: segment, argument: nil))
        }
    }

    return (path, formatters)
}

/// Split a string on `|` characters, but skip any `|` inside single-quoted strings.
private func splitOnPipesQuoteAware(_ input: String) -> [String] {
    var segments: [String] = []
    var current = ""
    var inQuote = false

    for ch in input {
        if ch == "'" {
            inQuote.toggle()
            current.append(ch)
        } else if ch == "|" && !inQuote {
            segments.append(current)
            current = ""
        } else {
            current.append(ch)
        }
    }
    segments.append(current)
    return segments
}

/// Parse a formatter argument string into a typed FormatterArgument.
private func parseArgument(_ raw: String) -> FormatterArgument? {
    if raw.isEmpty { return nil }

    // Single-quoted string literal.
    if raw.hasPrefix("'") && raw.hasSuffix("'") && raw.count >= 2 {
        let inner = String(raw.dropFirst().dropLast())
        return .string(inner)
    }

    // Boolean literal.
    if raw == "true" { return .bool(true) }
    if raw == "false" { return .bool(false) }

    // Number literal.
    if let n = Double(raw) {
        return .number(n)
    }

    return nil
}

// MARK: - Formatter application

/// Apply a chain of formatters to a scope value.
func applyFormatters(_ formatters: [ParsedFormatter], to value: ScopeValue) -> ScopeValue {
    var current = value
    for formatter in formatters {
        current = applyFormatter(formatter, to: current)
    }
    return current
}

/// Apply a single formatter to a scope value.
/// Returns the transformed value, or the original value if the formatter
/// is unknown, has a type mismatch, or is missing a required argument.
private func applyFormatter(_ formatter: ParsedFormatter, to value: ScopeValue) -> ScopeValue {
    switch formatter.name {
    // Number formatters
    case "ceil":    return applyCeil(value)
    case "floor":   return applyFloor(value)
    case "round":   return applyRound(value, arg: formatter.argument)
    case "abs":     return applyAbs(value)
    case "currency": return applyCurrency(value, arg: formatter.argument)
    case "percent": return applyPercent(value, arg: formatter.argument)
    case "compact": return applyCompact(value)

    // String formatters
    case "uppercase":  return applyUppercase(value)
    case "lowercase":  return applyLowercase(value)
    case "capitalize": return applyCapitalize(value)
    case "truncate":   return applyTruncate(value, arg: formatter.argument)
    case "initials":   return applyInitials(value)
    case "trim":       return applyTrim(value)

    // Date formatters
    case "date":         return applyDate(value)
    case "time":         return applyTime(value)
    case "datetime":     return applyDateTime(value)
    case "relativeTime": return applyRelativeTime(value)
    case "year":         return applyYear(value)

    // Collection formatters
    case "count":    return applyCount(value)
    case "join":     return applyJoin(value, arg: formatter.argument)
    case "first":    return applyFirst(value)
    case "last":     return applyLast(value)
    case "reverse":  return applyReverse(value)

    // Logic formatters
    case "default":  return applyDefault(value, arg: formatter.argument)

    // Conditional formatters
    case "pluralize": return applyPluralize(value, arg: formatter.argument)

    // Unknown: pass through unchanged (forward-compatible).
    default: return value
    }
}

// MARK: - Helpers: type coercion

/// Extract a Double from a ScopeValue using the spec's number coercion rules.
private func coerceToNumber(_ value: ScopeValue) -> Double? {
    switch value {
    case .number(let n): return n
    case .json(let j):
        switch j {
        case .int(let i): return Double(i)
        case .double(let d): return d
        default: return nil
        }
    case .text(let s): return Double(s)
    default: return nil
    }
}

/// Extract a String from a ScopeValue using the spec's text coercion rules.
private func coerceToText(_ value: ScopeValue) -> String? {
    switch value {
    case .text(let s): return s
    case .json(.string(let s)): return s
    default: return nil
    }
}

/// Extract an array from a ScopeValue.
private func coerceToArray(_ value: ScopeValue) -> [JSONValue]? {
    switch value {
    case .json(.array(let a)): return a
    case .selection(let s): return s.sorted().map { JSONValue.string($0) }
    default: return nil
    }
}

/// Check if a value is "empty" for the `default` formatter:
/// .empty, .text(""), or .json(.null).
private func isEmptyForDefault(_ value: ScopeValue) -> Bool {
    switch value {
    case .empty: return true
    case .text(let s): return s.isEmpty
    case .json(.null): return true
    default: return false
    }
}

/// Parse a Date from a ScopeValue (ISO 8601 string or Unix timestamp).
private func coerceToDate(_ value: ScopeValue) -> Date? {
    switch value {
    case .text(let s):
        return parseISO8601(s)
    case .json(.string(let s)):
        return parseISO8601(s)
    case .number(let n):
        return Date(timeIntervalSince1970: n)
    case .json(.int(let i)):
        return Date(timeIntervalSince1970: Double(i))
    case .json(.double(let d)):
        return Date(timeIntervalSince1970: d)
    default:
        return nil
    }
}

// Cached ISO 8601 formatters (configured once, thread-safe for parsing).
private let iso8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private let iso8601FractionalFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

/// Parse an ISO 8601 date string. Returns nil if unparseable.
private func parseISO8601(_ string: String) -> Date? {
    if let date = iso8601Formatter.date(from: string) {
        return date
    }
    // Try with fractional seconds.
    return iso8601FractionalFormatter.date(from: string)
}

/// Convert a JSONValue element to a string for join/display.
private func jsonElementToString(_ element: JSONValue) -> String {
    switch element {
    case .string(let s): return s
    case .int(let i): return String(i)
    case .double(let d): return formatNumber(d)
    case .bool(let b): return b ? "true" : "false"
    case .null: return ""
    case .array, .object: return ""
    }
}

/// Convert a JSONValue element to a ScopeValue.
private func jsonElementToScopeValue(_ element: JSONValue) -> ScopeValue {
    switch element {
    case .string(let s): return .text(s)
    case .int(let i): return .number(Double(i))
    case .double(let d): return .number(d)
    case .bool(let b): return .bool(b)
    case .null: return .json(.null)
    case .array, .object: return .json(element)
    }
}

// MARK: - Number formatters

private func applyCeil(_ value: ScopeValue) -> ScopeValue {
    guard let n = coerceToNumber(value) else { return value }
    return .number(Foundation.ceil(n))
}

private func applyFloor(_ value: ScopeValue) -> ScopeValue {
    guard let n = coerceToNumber(value) else { return value }
    return .number(Foundation.floor(n))
}

private func applyRound(_ value: ScopeValue, arg: FormatterArgument?) -> ScopeValue {
    guard let n = coerceToNumber(value) else { return value }
    if let arg = arg {
        guard case .number(let places) = arg else { return value }
        let p = Int(places)
        let multiplier = pow(10.0, Double(p))
        return .number((n * multiplier).rounded() / multiplier)
    }
    return .number(n.rounded())
}

private func applyAbs(_ value: ScopeValue) -> ScopeValue {
    guard let n = coerceToNumber(value) else { return value }
    return .number(Swift.abs(n))
}

// Cached currency formatter keyed by currency code.
// Using NSCache for thread-safe lazy caching per currency code.
private let currencyFormatterCache: NSCache<NSString, NumberFormatter> = {
    let cache = NSCache<NSString, NumberFormatter>()
    cache.countLimit = 20
    return cache
}()

private func currencyFormatter(code: String) -> NumberFormatter {
    let key = code as NSString
    if let cached = currencyFormatterCache.object(forKey: key) {
        return cached
    }
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = code
    f.locale = Locale(identifier: "en_US")
    currencyFormatterCache.setObject(f, forKey: key)
    return f
}

private func applyCurrency(_ value: ScopeValue, arg: FormatterArgument?) -> ScopeValue {
    guard let arg = arg, case .string(let code) = arg else { return value }
    guard let n = coerceToNumber(value) else { return value }

    if let result = currencyFormatter(code: code).string(from: NSNumber(value: n)) {
        return .text(result)
    }
    return value
}

private func applyPercent(_ value: ScopeValue, arg: FormatterArgument?) -> ScopeValue {
    guard let n = coerceToNumber(value) else { return value }
    let percentage = n * 100
    if let arg = arg {
        guard case .number(let places) = arg else { return value }
        let p = Int(places)
        let formatted = String(format: "%.\(p)f%%", percentage)
        return .text(formatted)
    }
    // Default: 0 decimal places.
    let intVal = Int(percentage.rounded())
    return .text("\(intVal)%")
}

private func applyCompact(_ value: ScopeValue) -> ScopeValue {
    guard let n = coerceToNumber(value) else { return value }

    let absN = Swift.abs(n)
    let sign = n < 0 ? "-" : ""

    if absN < 1000 {
        return .text(sign + formatNumber(absN))
    }

    // Thresholds with their suffix and divisor, checked top-down.
    // Each tier checks whether the value rounds into the next tier.
    let tiers: [(threshold: Double, suffix: String, divisor: Double)] = [
        (1_000_000_000, "B", 1_000_000_000),
        (1_000_000, "M", 1_000_000),
        (1000, "K", 1000),
    ]

    for (i, tier) in tiers.enumerated() {
        if absN >= tier.threshold || i == tiers.count - 1 {
            let scaled = absN / tier.divisor
            let rounded = (scaled * 10).rounded() / 10

            // If rounding pushes us into the next tier up, use that tier instead.
            // e.g. 999999 / 1000 = 999.999 -> rounds to 1000.0K -> should be 1M.
            if i > 0 {
                let higherTier = tiers[i - 1]
                if rounded * tier.divisor >= higherTier.threshold {
                    let higherScaled = absN / higherTier.divisor
                    let higherRounded = (higherScaled * 10).rounded() / 10
                    return formatCompactResult(sign: sign, rounded: higherRounded, suffix: higherTier.suffix)
                }
            }

            return formatCompactResult(sign: sign, rounded: rounded, suffix: tier.suffix)
        }
    }

    // Unreachable, but satisfy the compiler.
    return .text(formatNumber(n))
}

private func formatCompactResult(sign: String, rounded: Double, suffix: String) -> ScopeValue {
    if rounded.truncatingRemainder(dividingBy: 1) == 0 {
        return .text("\(sign)\(Int(rounded))\(suffix)")
    }
    return .text(String(format: "%@%.1f%@", sign, rounded, suffix))
}

// MARK: - String formatters

private func applyUppercase(_ value: ScopeValue) -> ScopeValue {
    guard let s = coerceToText(value) else { return value }
    return .text(s.uppercased())
}

private func applyLowercase(_ value: ScopeValue) -> ScopeValue {
    guard let s = coerceToText(value) else { return value }
    return .text(s.lowercased())
}

private func applyCapitalize(_ value: ScopeValue) -> ScopeValue {
    guard let s = coerceToText(value) else { return value }
    if s.isEmpty { return .text("") }
    return .text(s.prefix(1).uppercased() + s.dropFirst())
}

private func applyTruncate(_ value: ScopeValue, arg: FormatterArgument?) -> ScopeValue {
    guard let arg = arg, case .number(let limit) = arg else { return value }
    guard let s = coerceToText(value) else { return value }
    let n = Int(limit)
    if s.count <= n { return .text(s) }
    let truncated = String(s.prefix(n))
    return .text(truncated + "...")
}

private func applyInitials(_ value: ScopeValue) -> ScopeValue {
    guard let s = coerceToText(value) else { return value }
    if s.isEmpty { return .text("") }
    let words = s.split(separator: " ", omittingEmptySubsequences: true)
    let initials = words.compactMap { $0.first.map { String($0).uppercased() } }.joined()
    return .text(initials)
}

private func applyTrim(_ value: ScopeValue) -> ScopeValue {
    guard let s = coerceToText(value) else { return value }
    return .text(s.trimmingCharacters(in: .whitespaces))
}

// MARK: - Date formatters

/// Shared locale for date formatting. Uses en_US for conformance,
/// but in production this would use the device locale.
private let dateFormattingLocale = Locale(identifier: "en_US")
private let dateFormattingTimeZone = TimeZone(identifier: "UTC")!

// Cached DateFormatters (configured once, thread-safe for formatting).
private let dateMediumFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    f.locale = dateFormattingLocale
    f.timeZone = dateFormattingTimeZone
    return f
}()

private let timeShortFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .none
    f.timeStyle = .short
    f.locale = dateFormattingLocale
    f.timeZone = dateFormattingTimeZone
    return f
}()

private let dateTimeMediumShortFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    f.locale = dateFormattingLocale
    f.timeZone = dateFormattingTimeZone
    return f
}()

private func applyDate(_ value: ScopeValue) -> ScopeValue {
    guard let date = coerceToDate(value) else { return value }
    return .text(dateMediumFormatter.string(from: date))
}

private func applyTime(_ value: ScopeValue) -> ScopeValue {
    guard let date = coerceToDate(value) else { return value }
    return .text(timeShortFormatter.string(from: date))
}

private func applyDateTime(_ value: ScopeValue) -> ScopeValue {
    guard let date = coerceToDate(value) else { return value }
    return .text(dateTimeMediumShortFormatter.string(from: date))
}

private func applyRelativeTime(_ value: ScopeValue) -> ScopeValue {
    guard let date = coerceToDate(value) else { return value }
    #if canImport(UIKit) || canImport(AppKit)
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = dateFormattingLocale
    return .text(formatter.localizedString(for: date, relativeTo: Date()))
    #else
    // RelativeDateTimeFormatter is unavailable on some platforms.
    // Fall back to a basic representation.
    let interval = date.timeIntervalSince(Date())
    let absInterval = Swift.abs(interval)
    let unit: String
    let count: Int
    if absInterval < 60 {
        return .text(interval < 0 ? "just now" : "in a moment")
    } else if absInterval < 3600 {
        count = Int(absInterval / 60)
        unit = count == 1 ? "minute" : "minutes"
    } else if absInterval < 86400 {
        count = Int(absInterval / 3600)
        unit = count == 1 ? "hour" : "hours"
    } else {
        count = Int(absInterval / 86400)
        unit = count == 1 ? "day" : "days"
    }
    if interval < 0 {
        return .text("\(count) \(unit) ago")
    } else {
        return .text("in \(count) \(unit)")
    }
    #endif
}

private let yearFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy"
    f.locale = dateFormattingLocale
    f.timeZone = dateFormattingTimeZone
    return f
}()

private func applyYear(_ value: ScopeValue) -> ScopeValue {
    guard let date = coerceToDate(value) else { return value }
    return .text(yearFormatter.string(from: date))
}

// MARK: - Collection formatters

private func applyCount(_ value: ScopeValue) -> ScopeValue {
    // count works on arrays, objects, strings, selections, files.
    // For all others, returns 0.
    switch value {
    case .empty: return value
    default:
        return .number(Double(value.elementCount))
    }
}

private func applyJoin(_ value: ScopeValue, arg: FormatterArgument?) -> ScopeValue {
    guard let arg = arg, case .string(let separator) = arg else { return value }
    guard let array = coerceToArray(value) else { return value }
    let joined = array.map { jsonElementToString($0) }.joined(separator: separator)
    return .text(joined)
}

private func applyFirst(_ value: ScopeValue) -> ScopeValue {
    guard let array = coerceToArray(value) else { return value }
    guard let element = array.first else { return .empty }
    return jsonElementToScopeValue(element)
}

private func applyLast(_ value: ScopeValue) -> ScopeValue {
    guard let array = coerceToArray(value) else { return value }
    guard let element = array.last else { return .empty }
    return jsonElementToScopeValue(element)
}

private func applyReverse(_ value: ScopeValue) -> ScopeValue {
    guard let array = coerceToArray(value) else { return value }
    return .json(.array(array.reversed()))
}

// MARK: - Logic formatters

private func applyDefault(_ value: ScopeValue, arg: FormatterArgument?) -> ScopeValue {
    guard let arg = arg else { return value }
    guard isEmptyForDefault(value) else { return value }
    switch arg {
    case .string(let s): return .text(s)
    case .number(let n): return .number(n)
    case .bool(let b): return .bool(b)
    }
}

// MARK: - Conditional formatters

private func applyPluralize(_ value: ScopeValue, arg: FormatterArgument?) -> ScopeValue {
    guard let arg = arg, case .string(let forms) = arg else { return value }
    guard let n = coerceToNumber(value) else { return value }

    // Expect singular:plural in the argument, split on `:`.
    let parts = forms.split(separator: ":", maxSplits: 1)
    if parts.count == 2 {
        return .text(n == 1 ? String(parts[0]) : String(parts[1]))
    }
    return value
}
