import Foundation

// Splitting a shared expense: the website's three choices, with the backend's own meaning and checks (src/worker.js readSplit / computeShares).
//  equal   – everyone covers the same amount
//  percent – the value is the % the PAYER covers (0–100); the rest is split evenly between the others
//  owed    – the value is the dollars the others owe the payer in total (more than $0, no more than the total); split evenly between them
enum HBSplitMode: String, CaseIterable, Identifiable {
    case equal, percent, owed
    var id: String { rawValue }
    var title: String { self == .equal ? "Evenly" : self == .percent ? "By %" : "Amount owed" }
}

enum HBSplitRules {
    enum Outcome: Equatable {
        case ok(mode: String, value: Double?)
        case invalid(String)
    }

    static func parse(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "$", with: "").replacingOccurrences(of: "%", with: "")
        guard !t.isEmpty, let v = Double(t), v.isFinite else { return nil }
        return v
    }

    /// Checks what was typed against the total, with the website's messages. `equal` needs no number. The owed amount is rounded to whole cents.
    static func validate(mode: HBSplitMode, valueText: String, amount: Double) -> Outcome {
        switch mode {
        case .equal: return .ok(mode: "equal", value: nil)
        case .percent:
            guard let v = parse(valueText), v >= 0, v <= 100 else { return .invalid("Enter a percent from 0 to 100.") }
            return .ok(mode: "percent", value: v.rounded())
        case .owed:
            let cents = parse(valueText).map { ($0 * 100).rounded() }
            guard let c = cents, c > 0, c <= (amount * 100).rounded() else { return .invalid("The amount owed has to be more than $0 and no more than the total.") }
            return .ok(mode: "owed", value: c / 100)
        }
    }

    /// the typed value back from what is stored on an entry (percent as a whole number, owed in dollars)
    static func text(mode: HBSplitMode, stored: Double?) -> String {
        guard let v = stored else { return "" }
        return mode == .owed ? String(format: "%.2f", v) : String(Int(v.rounded()))
    }

    /// who covers what, in plain words (the website's split hint)
    static func hint(mode: HBSplitMode, valueText: String, payer: String, others: [String]) -> String {
        let oName = others.count == 1 ? others[0] : "Everyone else"
        switch mode {
        case .equal: return others.count == 1 ? "Each of you covers half." : "Everyone covers the same amount."
        case .percent:
            if let v = parse(valueText), v >= 0, v <= 100 { return "\(oName) \(others.count == 1 ? "covers" : "cover") \(Int((100 - v).rounded()))%" + (others.count > 1 ? ", split between them." : ".") }
            return ""
        case .owed: return "Use this when \(payer) paid and just needs part of it back."
        }
    }
    /// the sentence before the number box
    static func prefix(mode: HBSplitMode, payer: String, others: [String]) -> String {
        let oName = others.count == 1 ? others[0] : "Everyone else"
        return mode == .percent ? "\(payer) covers" : "\(oName) \(others.count == 1 ? "owes" : "owe")"
    }
    static func suffix(mode: HBSplitMode, others: [String]) -> String { mode == .percent ? "%" : (others.count > 1 ? "total" : "") }

    /// who owes whom, in cents, exactly as the backend computes it (so the app can show the same numbers it will get back)
    static func shares(amountCents: Int, mode: HBSplitMode, value: Double?, payer: String, members: [String]) -> [String: Int] {
        let others = members.filter { $0 != payer }
        guard !others.isEmpty else { return [payer: amountCents] }
        var payerShare: Int
        switch mode {
        case .percent: payerShare = Int((Double(amountCents) * min(100, max(0, value ?? 0)) / 100).rounded())
        case .owed: payerShare = amountCents - min(amountCents, max(0, Int(((value ?? 0) * 100).rounded())))
        case .equal: payerShare = amountCents - (amountCents / members.count) * others.count
        }
        let rest = amountCents - payerShare, each = rest / others.count
        var out = [payer: payerShare]
        for (i, id) in others.enumerated() { out[id] = each + (i < rest - each * others.count ? 1 : 0) }
        return out
    }
}
