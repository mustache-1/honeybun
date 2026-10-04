#if DEBUG
import Foundation

// Debug builds only: the sample accounts behind the Together screenshots and the in-process test backend (solo, partner, family, joint couple).
// Built from the one generated preview fixture, so the shapes are exactly what /api/nest really returns.
enum HBPreviewVariants {
    static let riley = "a1b2c3d4-0000-4000-8000-000000000001"
    static let jordan = "a1b2c3d4-0000-4000-8000-000000000002"

    static func base() -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(HBPreviewData.json.utf8))) as? [String: Any] ?? [:]
    }

    static func make(_ name: String) -> [String: Any] {
        var d = base()
        var nest = d["nest"] as? [String: Any] ?? [:]
        var members = d["members"] as? [[String: Any]] ?? []
        let meID = (d["me"] as? [String: Any])?["id"] as? String ?? ""
        func person(_ id: String, _ n: String, _ emoji: String, _ color: String, _ streak: Int) -> [String: Any] {
            ["id": id, "name": n, "emoji": emoji, "color": color, "xp": 120, "streak": streak, "best_streak": streak, "last_day": "2026-10-04", "week_key": "2026-09-28", "week_xp": 80, "logs": 12]
        }
        func others(_ ids: [String], _ share: Double) {
            // a few of the fixture's entries again under the other people, so "brought in / spent" has something to show
            var entries = d["entries"] as? [[String: Any]] ?? []
            var extra: [[String: Any]] = []
            for (i, e) in entries.prefix(6).enumerated() {
                var c = e; c["id"] = UUID().uuidString.lowercased(); c["member_id"] = ids[i % ids.count]
                if let a = e["amount_cents"] as? Int { c["amount_cents"] = Int((Double(a) * share).rounded()) }
                if i % 2 == 0, (c["type"] as? String) == "expense" { c["shared"] = 1 }
                extra.append(c)
            }
            entries += extra; d["entries"] = entries
        }
        switch name {
        case "solo":
            nest["kind"] = "solo"; nest["joint"] = 0
            d["balances"] = [meID: 0]; d["settlements"] = [[String: Any]]()
        case "family":
            nest["kind"] = "family"; nest["joint"] = 0
            members += [person(riley, "Riley", "🐻", "#FFF0C2", 5), person(jordan, "Jordan", "🐱", "#DDF5E9", 2)]
            d["balances"] = [meID: -1200, riley: 3000, jordan: -1800]
            d["settlements"] = [["id": "5e771e00-0000-4000-8000-000000000001", "from_id": jordan, "to_id": riley, "amount_cents": 2500, "date": "2026-10-02", "created_at": 1791100000]]
            others([riley, jordan], 0.6)
        case "inbox", "inboxempty":   // partner household; the full inbox also has a carry-over question waiting
            nest["kind"] = "couple"; nest["joint"] = 0
            members += [person(riley, "Riley", "🐻", "#FFF0C2", 5)]
            d["balances"] = [meID: 4250, riley: -4250]
            d["settlements"] = [[String: Any]]()
            others([riley], 0.7)
            d["inbox"] = ["unread": name == "inbox" ? 6 : 0]
            if name == "inbox" { d["carry_pending"] = ["from": "2026-09", "amount_cents": 12450] }
        default: // "partner" and "joint"
            nest["kind"] = "couple"; nest["joint"] = name == "joint" ? 1 : 0
            members += [person(riley, "Riley", "🐻", "#FFF0C2", 5)]
            d["balances"] = [meID: 4250, riley: -4250]
            d["settlements"] = [
                ["id": "5e771e00-0000-4000-8000-000000000002", "from_id": riley, "to_id": meID, "amount_cents": 6000, "date": "2026-10-03", "created_at": 1791200000],
                ["id": "5e771e00-0000-4000-8000-000000000003", "from_id": meID, "to_id": riley, "amount_cents": 3500, "date": "2026-09-27", "created_at": 1791000000],
            ]
            others([riley], 0.7)
        }
        d["nest"] = nest; d["members"] = members
        return d
    }

    /// Bun's messages for the Inbox screenshots and tests ("mixed", "long" = the same list twice, "empty"), dated relative to now
    static func inboxMessages(_ kind: String, recurring: [(String, String, Int)]) -> [[String: Any]] {
        if kind == "empty" { return [] }
        let now = Date().timeIntervalSince1970
        let today = HBDay.todayString
        func day(_ n: Int) -> String { HBDay.string(HBDay.addDays(HBDay.startOfToday(), n)) }
        func r(_ i: Int) -> (String, String, Int) { recurring.isEmpty ? ("none", "Rent", 85000) : recurring[i % recurring.count] }
        func m(_ kind: String, _ data: [String: Any], ago: Double, unread: Bool) -> [String: Any] {
            ["id": UUID().uuidString.lowercased(), "kind": kind, "data": data, "created_at": now - ago, "read_at": unread ? NSNull() : now - ago + 60]
        }
        var list: [[String: Any]] = [
            m("bill_today", ["rid": r(0).0, "occ": today, "label": r(0).1, "amount": r(0).2], ago: 1800, unread: true),
            m("bill_late", ["rid": r(1).0, "occ": day(-2), "label": r(1).1, "amount": r(1).2], ago: 3600, unread: true),
            m("bill_soon", ["rid": r(2).0, "occ": day(2), "label": r(2).1, "amount": r(2).2], ago: 5400, unread: true),
            m("carry_ask", ["amount": 12450, "neg": false, "from": "September"], ago: 7200, unread: true),
            m("shared_expense", ["name": "Riley", "label": "Groceries", "amount": 6200], ago: 9000, unread: true),
            m("budget_warn", ["cat": "food", "spent": 21000, "limit": 25000], ago: 10800, unread: true),
            m("streak_risk", ["n": 12], ago: 86400 + 3600, unread: false),
            m("week", ["spent": 41230, "cat": "food", "xp": 90], ago: 86400 + 7200, unread: false),
            m("goal_done", ["goal": "Wedding Fund"], ago: 2 * 86400, unread: false),
            m("settled", ["name": "Riley", "amount": 2000, "you_paid": true], ago: 2 * 86400 + 3600, unread: false),
            m("level", ["level": 3], ago: 3 * 86400, unread: false),
            m("ref_intro", ["goal": 10, "amount": 1000], ago: 4 * 86400, unread: false),
            m("welcome", ["name": "Sam"], ago: 9 * 86400, unread: false),
        ]
        if kind == "long" {
            list += list.map { var c = $0; c["id"] = UUID().uuidString.lowercased(); c["created_at"] = ($0["created_at"] as? Double ?? now) - 12 * 86400; c["read_at"] = now; return c }
        }
        return list
    }

    static var shopping: [[String: Any]] {
        [["Oat milk", false], ["Eggs", false], ["Dish soap", false], ["Coffee beans", false], ["Bananas", true]].map {
            ["id": UUID().uuidString.lowercased(), "label": $0[0] as? String ?? "", "added_by": "", "done": $0[1] as? Bool ?? false, "done_by": NSNull()]
        }
    }
}
#endif
