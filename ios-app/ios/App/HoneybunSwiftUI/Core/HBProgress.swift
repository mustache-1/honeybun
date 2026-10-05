import Foundation

// Bunny levels, streaks and badges: the same rules the website uses (TITLES / levelFor / levelInfo / BADGES / streakOf in app.js).
enum HBProgress {
    static let titles = ["Tiny Sprout", "Curious Kit", "Hoppy Saver", "Carrot Collector", "Burrow Builder", "Budget Bunny", "Clover Keeper", "Garden Guardian", "Moon Hopper", "Honeybun Legend"]
    static func levelFor(_ xp: Int) -> Int { var l = 1; while xp >= 25 * (l + 1) * l { l += 1 }; return l }

    struct LevelInfo: Equatable { let level: Int; let title: String; let lo: Int; let hi: Int; let pct: Double }
    static func levelInfo(_ xp: Int) -> LevelInfo {
        let l = levelFor(xp), lo = 25 * l * (l - 1), hi = 25 * (l + 1) * l
        return LevelInfo(level: l, title: titles[min(l, titles.count) - 1], lo: lo, hi: hi, pct: max(0, min(1, Double(xp - lo) / Double(hi - lo))))
    }

    /// the streak counts only if you logged today or yesterday
    static func streak(_ m: HBMember, today: Date = HBDay.startOfToday()) -> Int {
        let t = HBDay.string(today), y = HBDay.string(HBDay.addDays(today, -1))
        guard let last = m.last_day, last == t || last == y else { return 0 }
        return m.streak ?? 0
    }
    /// this week's carrots (weeks start on Monday); 0 if the member hasn't earned any yet this week
    static func weekXP(_ m: HBMember, today: Date = HBDay.startOfToday()) -> Int {
        let wd = (HBDay.cal.component(.weekday, from: today) + 5) % 7      // Monday = 0
        let monday = HBDay.string(HBDay.addDays(today, -wd))
        return m.week_key == monday ? (m.week_xp ?? 0) : 0
    }

    struct Badge: Identifiable, Equatable { let id: String; let emoji: String; let name: String; let hint: String; let unlocked: Bool }
    /// every badge, and whether `m` has earned it. `monthsWithEntries` is how many different months this year have entries (nil if not loaded).
    static func badges(_ m: HBMember, _ s: HBNestSnapshot, monthsWithEntries: Int? = nil) -> [Badge] {
        let logs = m.logs ?? 0, best = m.best_streak ?? 0, lvl = levelFor(m.xp ?? 0)
        let hasPayday = s.recurring.contains { $0.type == "income" }
        let bills = s.recurring.filter { $0.type == "expense" }.count
        let hasBudget = !(s.budgets ?? []).isEmpty
        let goalDone = s.goals.contains { $0.saved_cents >= $0.target_cents }
        let debtDone = (s.debts ?? []).contains { $0.paid_cents >= $0.start_cents }
        let together = s.members.count >= 2
        let yearOK = (monthsWithEntries ?? 0) >= 6
        let list: [(String, String, String, String, Bool)] = [
            ("star", "🐣", "First hop", "Log your first thing", logs >= 1),
            ("paw", "🐾", "3-day hop", "Keep a 3-day streak", best >= 3),
            ("sparkle", "🌟", "Week hopper", "Keep a 7-day streak", best >= 7),
            ("medal", "🏅", "Month marathon", "Keep a 30-day streak", best >= 30),
            ("carrot", "🥕", "Carrot counter", "Log 50 things", logs >= 50),
            ("basket", "🧺", "Carrot basket", "Log 200 things", logs >= 200),
            ("coin", "💰", "Payday planner", "Add a payday", hasPayday),
            ("calcheck", "📅", "Bill boss", "Add 3 bills", bills >= 3),
            ("target", "🎯", "Limit setter", "Set a monthly budget", hasBudget),
            ("jar", "🍯", "Goal getter", "Reach a savings goal", goalDone),
            ("party", "🎉", "Debt free-ish", "Pay off a debt", debtDone),
            ("heart", "💞", "Better together", "Share your budget", together),
            ("home2", "🏡", "Burrow builder", "Reach level 5", lvl >= 5),
            ("moon", "🌙", "Moon hopper", "Reach level 9", lvl >= 9),
            ("crown", "👑", "Legend", "Reach level 10", lvl >= 10),
            ("cal", "🗓️", "Year in review", "Log something in 6 different months", yearOK),
        ]
        return list.map { Badge(id: $0.0, emoji: $0.1, name: $0.2, hint: $0.3, unlocked: $0.4) }
    }
}

/// What the bunny wears at each level: the same rules as the website's gearSvg() / UNLOCKS in app.js. (The website draws the bunny in code; the
/// native app draws the same shapes, see HBLevelBunny.)
struct HBBunnyGear: Equatable {
    let sprout: Bool, bow: Bool, scarf: Bool, flowerCrown: Bool, goldenCrown: Bool
    static func forLevel(_ l: Int) -> HBBunnyGear {
        HBBunnyGear(sprout: l >= 2 && l < 7, bow: l >= 3, scarf: l >= 5, flowerCrown: l >= 7 && l < 10, goldenCrown: l >= 10)
    }
    /// "a little sprout", "a pink bow"… for the levels that unlock something new (the level-up message)
    static func unlock(_ l: Int) -> String? { [2: "a little sprout", 3: "a pink bow", 5: "a cozy scarf", 7: "a flower crown", 10: "a tiny golden crown"][l] }
}

/// the carrot reward the server sends back with most changes: only a level-up matters on screen
enum HBCarrotReward {
    static func leveledUp(in data: Data) -> Int? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let r = o["reward"] as? [String: Any],
              r["leveled"] as? Bool == true, let level = r["level"] as? Int else { return nil }
        return level
    }
}
