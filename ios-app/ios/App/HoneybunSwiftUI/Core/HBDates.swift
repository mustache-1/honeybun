import Foundation

// Dates travel as plain "yyyy-MM-dd" strings in the backend. They are read and written in the phone's own calendar and time zone.
enum HBDay {
    static let cal = Calendar.current
    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func parse(_ s: String) -> Date? { fmt.date(from: s) }
    static func string(_ d: Date) -> String { fmt.string(from: d) }
    static var todayString: String { string(Date()) }
    static func monthKey(_ d: Date = Date()) -> String { String(string(d).prefix(7)) }
    static func shiftMonth(_ key: String, by n: Int) -> String {
        guard let d = parse(key + "-01"), let s = cal.date(byAdding: .month, value: n, to: d) else { return key }
        return monthKey(s)
    }
    static func monthName(_ key: String) -> String {
        guard let d = parse(key + "-01") else { return key }
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f.string(from: d)
    }
    static func short(_ s: String) -> String {
        guard let d = parse(s) else { return s }
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }
    static func dayName(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: d) }
    static func addDays(_ d: Date, _ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: d) ?? d }
    static func startOfToday() -> Date { cal.startOfDay(for: Date()) }
}

struct HBUpcoming: Identifiable {
    let recurring: HBRecurring
    let date: Date
    let late: Bool
    var id: String { recurring.id + "|" + HBDay.string(date) }
    var dateString: String { HBDay.string(date) }
}

// Same rule the website uses (occurrences() / hhUpcomingAll() in app.js): for every bill or payday, its next occurrence that hasn't been
// logged yet, looking from a month back (so a missed one shows as late) to just over a year ahead.
enum HBRecur {
    static func occurrences(_ r: HBRecurring, from: Date, to: Date) -> [Date] {
        guard let anchor = HBDay.parse(r.anchor_date) else { return [] }
        let cal = HBDay.cal
        var out: [Date] = []
        if r.freq == "monthly" {
            let day = cal.component(.day, from: anchor)
            var y = cal.component(.year, from: from), m = cal.component(.month, from: from)
            for _ in 0..<26 {
                guard let first = cal.date(from: DateComponents(year: y, month: m, day: 1)),
                      let span = cal.range(of: .day, in: .month, for: first) else { break }
                guard let d = cal.date(from: DateComponents(year: y, month: m, day: min(day, span.count))) else { break }
                if d > to { break }
                if d >= from && d >= anchor { out.append(d) }
                m += 1
                if m > 12 { m = 1; y += 1 }
            }
        } else {
            let step = r.freq == "weekly" ? 7 : 14
            var d = anchor
            if d < from {
                let gap = cal.dateComponents([.day], from: anchor, to: from).day ?? 0
                let k = Int((Double(gap) / Double(step)).rounded(.up))
                d = HBDay.addDays(anchor, k * step)
            }
            var i = 0
            while d <= to && i < 60 { out.append(d); d = HBDay.addDays(d, step); i += 1 }
        }
        return out
    }

    static func upcoming(_ s: HBNestSnapshot) -> [HBUpcoming] {
        let today = HBDay.startOfToday()
        let logged = Set(s.logged.map { $0.recurring_id + "|" + $0.occ_date })
        var items: [HBUpcoming] = []
        for r in s.recurring {
            for d in occurrences(r, from: HBDay.addDays(today, -31), to: HBDay.addDays(today, 400)) where !logged.contains(r.id + "|" + HBDay.string(d)) {
                items.append(HBUpcoming(recurring: r, date: d, late: d < today))
                break
            }
        }
        return items.sorted { $0.date < $1.date }
    }
}
