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

    static var shopping: [[String: Any]] {
        [["Oat milk", false], ["Eggs", false], ["Dish soap", false], ["Coffee beans", false], ["Bananas", true]].map {
            ["id": UUID().uuidString.lowercased(), "label": $0[0] as? String ?? "", "added_by": "", "done": $0[1] as? Bool ?? false, "done_by": NSNull()]
        }
    }
}
#endif
