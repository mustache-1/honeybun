import Foundation

// The Together tab's logic, kept free of any UI so CI can test it on macOS: who owes whom, per-person totals, and the buddy artwork names.
// It ports the website's pairs() / shareStats() / BUDDY (public/app.js) so both apps always agree.

enum HBSituation: Equatable { case solo, partner, family }

struct HBPair: Identifiable {
    let from: HBMember
    let to: HBMember
    let amount: Double
    var id: String { from.id + ">" + to.id }
}

struct HBPersonTotals: Identifiable {
    let member: HBMember
    let income: Double
    let spent: Double
    let shared: Double
    var own: Double { spent - shared }
    var id: String { member.id }
}

enum HBTogether {
    /// how many people are in the budget decides what Together shows (the budget "type" only changes the wording)
    static func situation(memberCount: Int) -> HBSituation { memberCount <= 1 ? .solo : (memberCount == 2 ? .partner : .family) }

    /// Joint account is a couple-only mode with two or more people (the same rule as the website's JOINT())
    static func isJoint(kind: String?, joint: Int?, memberCount: Int) -> Bool { (joint ?? 0) == 1 && memberCount > 1 && (kind ?? "couple") == "couple" }

    /// "who pays whom" from the running balances (positive = others owe that person), exactly the website's greedy pairing
    static func pairs(members: [HBMember], balances: [String: Int]) -> [HBPair] {
        var debt: [(m: HBMember, v: Double)] = [], cred: [(m: HBMember, v: Double)] = []
        for m in members {
            let v = Double(balances[m.id] ?? 0) / 100.0
            if v < -0.005 { debt.append((m, -v)) } else if v > 0.005 { cred.append((m, v)) }
        }
        var out: [HBPair] = []
        var i = 0, j = 0
        while i < debt.count && j < cred.count {
            let pay = min(debt[i].v, cred[j].v)
            out.append(HBPair(from: debt[i].m, to: cred[j].m, amount: (pay * 100).rounded() / 100))
            debt[i].v -= pay; cred[j].v -= pay
            if debt[i].v < 0.005 { i += 1 }
            if cred[j].v < 0.005 { j += 1 }
        }
        return out
    }

    /// each person's income / spending for the entries you can see (their private entries never reach anyone else's phone)
    static func totals(members: [HBMember], entries: [HBEntry]) -> [HBPersonTotals] {
        members.map { m in
            let mine = entries.filter { $0.member_id == m.id }
            let inc = mine.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
            let out = mine.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
            let sh = mine.filter { !$0.isIncome && $0.shared != 0 }.reduce(0) { $0 + $1.amount }
            return HBPersonTotals(member: m, income: inc, spent: out, shared: sh)
        }
    }

    static func percent(_ v: Double, of total: Double) -> Int { total > 0 ? Int((v / total * 100).rounded()) : 0 }

    // MARK: buddies (the picture each member picked; the backend stores one of these 12 emoji)

    static let emojis = ["🐰", "🐻", "🐱", "🐶", "🦊", "🐼", "🐨", "🐸", "🐧", "🦄", "🐥", "🐹"]
    static let colors = ["#FFD6E5", "#FFF0C2", "#DDF5E9", "#E4EDFF", "#EADFFF", "#FFE1CC"]
    private static let buddyName: [String: String] = ["🐰": "default", "🐻": "happy", "🐱": "sleepy", "🐶": "cool", "🦊": "devil", "🐼": "angel",
                                                       "🐨": "witch", "🐸": "ghost", "🐧": "nerd", "🦄": "cowboy", "🐥": "frog", "🐹": "dinosaur"]
    /// asset-catalog name of the buddy picture (HBBuddy_default, …), or nil for an emoji the website doesn't draw
    static func buddyAsset(_ emoji: String?) -> String? { emoji.flatMap { buddyName[$0] }.map { "HBBuddy_" + $0 } }

    // MARK: invite

    static func prettyCode(_ code: String) -> String { code.count > 4 ? String(code.prefix(4)) + "-" + String(code.dropFirst(4)) : code }
    static func inviteLink(_ code: String) -> String { "https://honeybun.me/join/" + code }

    /// "Just me" / "Couple" / "Family"
    static func kindName(_ kind: String?) -> String { switch kind { case "solo": return "Just me"; case "family": return "Family"; default: return "Couple" } }
}
