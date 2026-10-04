import Foundation

// The Money comparison chart, computed only from real transactions: each bar is the sum of expense amounts whose own date falls in that slice of
// the month, for this month and for the month before. Nothing here is a placeholder.
enum HBChartMath {
    /// expense amounts summed by day of month (1...31), from the entries' own "yyyy-MM-dd" dates
    static func dailyExpenses(_ entries: [HBEntry]) -> [Int: Double] {
        var by: [Int: Double] = [:]
        for e in entries where !e.isIncome {
            if let d = Int(e.date.suffix(2)), d >= 1, d <= 31 { by[d, default: 0] += e.amount }
        }
        return by
    }

    /// slices of `size` days: slice i covers days (i*size+1)...(i*size+size)
    static func slices(daily: [Int: Double], daysInMonth: Int, size: Int = 2) -> [Double] {
        let count = Int((Double(daysInMonth) / Double(size)).rounded(.up))
        var out = [Double](repeating: 0, count: count)
        for (day, amt) in daily where day >= 1 { out[min(count - 1, (day - 1) / size)] += amt }
        return out
    }
}
