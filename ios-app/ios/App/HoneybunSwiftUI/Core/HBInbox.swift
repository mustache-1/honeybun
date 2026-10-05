import Foundation

// Bun's inbox, without any UI so CI can test it on macOS. It ports the website's msgText() / msgActions() (public/app.js) so the same
// message from the backend reads the same, and offers the same buttons, in the app and on the web.

enum HBInboxTab: String, CaseIterable { case bills = "Bills", shared = "Shared", updates = "Updates" }

/// What a message's button does. Every one is carried out by a native screen.
enum HBInboxAction: Equatable {
    case markPaid(rid: String, occ: String, label: String)   // "Paid" / "Got it": logs that bill or payday through the backend
    case logSomething                                         // opens the native Add Expense form
    case openHome(String), openMoney(String), openGoals(String), openTogether(String)   // switch to that native tab (the String is the button label)
    case decideCarry                                          // the native carry-over sheet
    case openPlan(String), openStats(String), openReferrals(String)   // Plan (budgets, debts…), Stats (year, bunny, badges), Invite friends
    var label: String {
        switch self {
        case let .markPaid(_, _, l): return l
        case .logSomething: return "Log something"
        case let .openHome(l), let .openMoney(l), let .openGoals(l), let .openTogether(l), let .openPlan(l), let .openStats(l), let .openReferrals(l): return l
        case .decideCarry: return "Decide"
        }
    }
}

enum HBInbox {
    static let titles = ["Tiny Sprout", "Curious Kit", "Hoppy Saver", "Carrot Collector", "Burrow Builder", "Budget Bunny", "Clover Keeper", "Garden Guardian", "Moon Hopper", "Honeybun Legend"]
    static let unlocks: [Int: String] = [2: "a little sprout", 3: "a pink bow", 5: "a cozy scarf", 7: "a flower crown", 10: "a tiny golden crown"]
    /// the website's "Smart Tip" suggestions (GENERAL_TIPS), in the same order
    static let generalTips = [
        "Try a no-spend day this week. Paw prints on your hop calendar mark each one 🐾",
        "Wait a day before buying anything over $50. If you still want it tomorrow, go for it 🐰",
        "Set a budget for your biggest category. I'll give you a heads-up at 80% 🥕",
        "Give your savings goal a fun name. People save more for a \"Beach trip\" than for \"Savings\" 🍯",
        "Planning meals on Sunday is one of the easiest ways to spend less on food 🥕",
        "Add your bills once in Plan, and I'll remind you before each one is due 🐰",
        "Check Together once a week, so nobody's surprised by who owes who 💞",
        "Mark personal spending as private. Only you will see it 🔒",
        "Paying yourself first works: move a little into a honey jar right after payday 🍯",
        "Small daily treats add up. $5 a day is about $150 a month ☕",
    ]

    static func money(_ cents: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencyCode = "USD"; f.currencySymbol = "$"; f.minimumFractionDigits = 2; f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: cents / 100)) ?? "$\(cents / 100)"
    }

    /// whole days from `today` to `occ` (negative = in the past), both "yyyy-MM-dd"
    static func dayDiff(_ occ: String, today: String) -> Int {
        guard let a = HBDay.parse(today), let b = HBDay.parse(occ) else { return 0 }
        return HBDay.cal.dateComponents([.day], from: a, to: b).day ?? 0
    }

    // MARK: which tab a message belongs to

    static func tab(for kind: String) -> HBInboxTab {
        switch kind {
        case "bill_soon", "bill_today", "bill_late", "payday", "carry_ask", "carry_auto", "budget_warn", "budget_over": return .bills
        case "shared_expense", "joint_entry", "joined", "settled", "joint", "carry_done": return .shared
        default: return .updates
        }
    }

    /// the small title on each card
    static func heading(for kind: String) -> String {
        switch kind {
        case "bill_soon": return "Upcoming bill"
        case "bill_today": return "Bill due today"
        case "bill_late": return "Overdue bill"
        case "payday": return "Payday"
        case "carry_ask": return "New month"
        case "carry_auto", "carry_done": return "Carry over"
        case "budget_warn": return "Budget heads-up"
        case "budget_over": return "Over budget"
        case "shared_expense": return "Shared expense"
        case "joint_entry": return "Joint account"
        case "joint": return "Joint account"
        case "joined": return "New member"
        case "settled": return "Payment"
        case "welcome": return "Hi from Bun"
        case "streak_risk": return "Streak check-in"
        case "streak_milestone": return "Streak"
        case "level": return "Level up"
        case "week": return "Weekly recap"
        case "goal_done": return "Goal reached"
        case "debt_done": return "Debt paid off"
        case "ref_intro", "ref_nudge", "ref_signup", "ref_qualified", "reward_earned", "reward_sent": return "Gift card"
        default: return "Bun"
        }
    }

    /// kinds that should look urgent (orange outline, like the mockup's bill card)
    static func isUrgent(_ kind: String) -> Bool { ["bill_today", "bill_late", "bill_soon", "carry_ask", "budget_over"].contains(kind) }

    // MARK: text (port of MSG.en + msgText)

    static func text(_ m: HBInboxMessage, today: String, categoryName: (String) -> String) -> String {
        var kind = m.kind
        var n = 0
        if ["bill_soon", "bill_today", "bill_late"].contains(kind), !m.str("occ").isEmpty {
            n = dayDiff(m.str("occ"), today: today)
            kind = n < 0 ? "bill_late" : (n == 0 ? "bill_today" : "bill_soon")   // keep the wording up to date
        }
        let name = m.str("name"), label = m.str("label")
        let amount = money(m.num("amount")), sign = m.flag("neg") ? "-" : ""
        func gift() -> String { money(m.data["amount"]?.double ?? 1000).replacingOccurrences(of: ".00", with: "") }
        switch kind {
        case "welcome": return "Hi \(name)! I'm Bun 🐰 I'll pop in here with bill reminders, paydays, and streak check-ins."
        case "bill_soon": return "\(label) (\(amount)) is due \(n == 1 ? "tomorrow" : "in \(n) days") 🐰"
        case "bill_today": return "\(label) (\(amount)) is due today. Tap Paid once it's done ✓"
        case "bill_late": return "\(label) (\(amount)) was due \(HBDay.short(m.str("occ"))). Did it get paid?"
        case "payday": return "It's payday! \(label) (\(amount)) should land today 💰"
        case "streak_risk": return "Your \(Int(m.num("n")))-day streak ends at midnight 🐾 Log one thing to keep hopping!"
        case "streak_milestone": return "\(Int(m.num("n")))-day hop streak! You're on a roll 🐾✨"
        case "level":
            let l = max(1, Int(m.num("level")))
            let title = titles[min(l, titles.count) - 1]
            let un = unlocks[l].map { " I got \($0) to wear 🎀" } ?? " Keep hopping!"
            return "Level \(l)! You're now a \(title).\(un)"
        case "budget_warn":
            let limit = m.num("limit")
            return "Heads up: \(categoryName(m.str("cat"))) is at \(Int((limit > 0 ? m.num("spent") / limit * 100 : 0).rounded()))% of its budget (\(money(m.num("spent"))) of \(money(limit))) 🥕"
        case "budget_over": return "\(categoryName(m.str("cat"))) went over budget by \(money(m.num("over"))). No stress, next month is a fresh start ♡"
        case "week":
            let cat = m.str("cat")
            return "Last week you spent \(money(m.num("spent")))\(cat.isEmpty ? "" : ", mostly on \(categoryName(cat).lowercased())"). You earned \(Int(m.num("xp"))) carrots 🥕"
        case "goal_done": return "You reached your \"\(m.str("goal"))\" goal! 🍯 So proud of you."
        case "debt_done": return "\(m.str("debt")) is paid off! 🎉 One less thing to carry."
        case "joined": return "\(name) joined your budget 💞 Say hi!"
        case "carry_auto": return "New month! \(sign)\(amount) from \(m.str("from")) was carried over for you."
        case "carry_ask": return "New month! \(m.str("from")) ended at \(sign)\(amount). Carry it over or start fresh?"
        case "carry_done": return m.flag("accepted") ? "\(name) carried \(sign)\(amount) over from \(m.str("from"))." : "\(name) started this month fresh."
        case "joint": return m.flag("on") ? "\(name) turned on Joint account. Everything now adds up together and nobody owes anybody." : "\(name) turned off Joint account. Splitting and balances are back."
        case "settled": return m.flag("you_paid") ? "\(name) marked your \(amount) payment as received 💸" : "\(name) marked \(amount) as paid to you 💸"
        case "shared_expense": return "\(name) added \(label) (\(amount)) and split it with you."
        case "joint_entry": return "\(name) added \(label) (\(amount))."
        case "ref_intro": return "Psst 🎁 Share Honeybun with friends and earn a \(gift()) gift card for every \(Int(m.num("goal"))) who stick around for a week. Tap below for your link!"
        case "ref_nudge": return "Know someone who'd love a cute budget? Every \(Int(m.num("goal"))) friends who join with your link = a \(gift()) gift card 🎁"
        case "ref_signup": return "\(name) just signed up with your link! 🎉 They'll count once they've used Honeybun for a week."
        case "ref_qualified": return "\(name) counts now! That's \(Int(m.num("n"))) of \(Int(m.num("goal"))) toward your next gift card 🥕"
        case "reward_earned": return "You did it! \(Int(m.num("n"))) friends counted, so you earned a \(gift()) gift card 🎁 It'll be emailed to you within a few days."
        case "reward_sent": return "Your \(gift()) gift card was sent! Check your email 💌 Thanks for sharing Honeybun."
        default: return ""
        }
    }

    // MARK: buttons (port of msgActions + native routing)

    static func action(for m: HBInboxMessage, recurringExists: (String) -> Bool, carryPending: Bool) -> HBInboxAction? {
        switch m.kind {
        case "bill_soon", "bill_today", "bill_late":
            return recurringExists(m.str("rid")) ? .markPaid(rid: m.str("rid"), occ: m.str("occ"), label: "Paid") : nil
        case "payday":
            return recurringExists(m.str("rid")) ? .markPaid(rid: m.str("rid"), occ: m.str("occ"), label: "Got it") : nil
        case "streak_risk": return .logSomething
        case "budget_warn", "budget_over": return .openPlan("See budgets")
        case "goal_done": return .openGoals("See goals")
        case "debt_done": return .openPlan("See Plan")
        case "week": return .openStats("See stats")
        case "level", "streak_milestone": return .openStats("See my bunny")
        case "carry_ask": return carryPending ? .decideCarry : nil
        case "shared_expense", "joint_entry", "settled", "joint", "joined", "carry_done": return .openTogether("Open Together")
        case "ref_intro", "ref_nudge": return .openReferrals("Get my link")
        case "ref_signup", "ref_qualified", "reward_earned", "reward_sent": return .openReferrals("See referrals")
        default: return nil
        }
    }

    // MARK: grouping by day

    /// "Today" / "Yesterday" / "Mon, Oct 3" for a message time, relative to `now`
    static func dayTitle(_ date: Date, now: Date = Date()) -> String {
        let cal = HBDay.cal
        if cal.isDate(date, inSameDayAs: now) { return "Today" }
        if let y = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(date, inSameDayAs: y) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f.string(from: date)
    }
    static func timeText(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: date) }

    /// newest first, grouped by calendar day
    static func groups(_ messages: [HBInboxMessage], now: Date = Date()) -> [(title: String, items: [HBInboxMessage])] {
        var out: [(title: String, items: [HBInboxMessage])] = []
        for m in messages.sorted(by: { $0.created_at > $1.created_at }) {
            let t = dayTitle(m.date, now: now)
            if let i = out.indices.last, out[i].title == t { out[i].items.append(m) } else { out.append((t, [m])) }
        }
        return out
    }
}
