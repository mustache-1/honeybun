import Foundation

// Everything the search sheet can filter by. The query string uses the backend's own /api/search parameters (q, type, cat, member, min, max,
// from, to); the server ignores a min/max that is not a positive number and a from/to that is not a real date, so the app only sends valid ones.
struct HBSearchFilter: Equatable {
    var q = ""
    var type = "all"          // all | expense | income
    var category = "all"
    var member = "all"
    var minAmount: Double? = nil
    var maxAmount: Double? = nil
    var from: String? = nil   // yyyy-MM-dd
    var to: String? = nil

    /// anything beyond the text box and the "who / type" chips: what "Clear filters" resets
    var isDefault: Bool { self == HBSearchFilter() }
    var activeCount: Int {
        var n = 0
        if !q.trimmingCharacters(in: .whitespaces).isEmpty { n += 1 }
        if type != "all" { n += 1 }
        if category != "all" { n += 1 }
        if member != "all" { n += 1 }
        if (minAmount ?? 0) > 0 { n += 1 }
        if (maxAmount ?? 0) > 0 { n += 1 }
        if from != nil { n += 1 }
        if to != nil { n += 1 }
        return n
    }
    /// something to look for at all (the website does not search with nothing set)
    var hasCriteria: Bool { activeCount > 0 }
    /// a range that ends before it starts matches nothing, so the sheet says so instead of asking
    var rangeBackwards: Bool {
        if let f = from, let t = to { return f > t }
        if let a = minAmount, let b = maxAmount, a > 0, b > 0 { return a > b }
        return false
    }

    var queryItems: [URLQueryItem] {
        var items = [URLQueryItem(name: "q", value: q.trimmingCharacters(in: .whitespaces))]
        if type != "all" { items.append(URLQueryItem(name: "type", value: type)) }
        if category != "all" { items.append(URLQueryItem(name: "cat", value: category)) }
        if member != "all" { items.append(URLQueryItem(name: "member", value: member)) }
        if let a = minAmount, a > 0 { items.append(URLQueryItem(name: "min", value: Self.number(a))) }
        if let b = maxAmount, b > 0 { items.append(URLQueryItem(name: "max", value: Self.number(b))) }
        if let f = from, HBDay.parse(f) != nil { items.append(URLQueryItem(name: "from", value: f)) }
        if let t = to, HBDay.parse(t) != nil { items.append(URLQueryItem(name: "to", value: t)) }
        return items
    }
    static func number(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(v) }
}
