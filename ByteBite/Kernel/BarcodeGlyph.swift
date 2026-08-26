import Foundation

/// BarcodeGlyph extracts and normalises digit runs from camera, typed and URL input.
enum BarcodeGlyph: Sendable {
    static func digitRuns(_ raw: String) -> [String] {
        var runs: [String] = []
        var current = ""
        for character in raw {
            if character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                runs.append(current)
                current = ""
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs
    }

    /// Candidate codes to try against the product endpoint, first is preferred.
    static func candidates(_ raw: String) -> [String] {
        var out: [String] = []
        func push(_ code: String) {
            if !code.isEmpty && !out.contains(code) {
                out.append(code)
            }
        }
        for run in digitRuns(raw) {
            guard (8...14).contains(run.count) else { continue }
            if run.count == 12 {
                push("0" + run)
            } else {
                push(run)
            }
            if let expanded = expandUPCE(run) {
                push(expanded)
            }
        }
        return out
    }

    static func normalize(_ raw: String) -> String? {
        candidates(raw).first
    }

    /// Expands UPC-E (6–8 digits) into a 12-digit UPC-A plus leading 0 → 13.
    static func expandUPCE(_ run: String) -> String? {
        let digits = run.filter(\.isNumber)
        let ns: Character
        let core: String
        switch digits.count {
        case 6:
            ns = "0"
            core = digits
        case 7:
            ns = digits[digits.startIndex]
            core = String(digits.dropFirst())
        case 8:
            ns = digits[digits.startIndex]
            core = String(digits.dropFirst().dropLast())
        default:
            return nil
        }
        guard core.count == 6, ns == "0" || ns == "1" else { return nil }
        let chars = Array(core)
        let d1 = chars[0], d2 = chars[1], d3 = chars[2]
        let d4 = chars[3], d5 = chars[4], d6 = chars[5]
        let body: String
        switch d6 {
        case "0", "1", "2":
            body = "\(ns)\(d1)\(d2)\(d3)\(d6)0000\(d4)\(d5)"
        case "3":
            body = "\(ns)\(d1)\(d2)\(d3)00000\(d4)\(d5)"
        case "4":
            body = "\(ns)\(d1)\(d2)\(d3)\(d4)00000\(d5)"
        default:
            body = "\(ns)\(d1)\(d2)\(d3)\(d4)\(d5)0000\(d6)"
        }
        guard body.count == 11 else { return nil }
        let check = checkDigit(body)
        return body + String(check)
    }

    static func checkDigit(_ eleven: String) -> Int {
        let nums = eleven.compactMap { $0.wholeNumberValue }
        var sum = 0
        for (index, value) in nums.enumerated() {
            sum += value * (index.isMultiple(of: 2) ? 3 : 1)
        }
        return (10 - (sum % 10)) % 10
    }
}
