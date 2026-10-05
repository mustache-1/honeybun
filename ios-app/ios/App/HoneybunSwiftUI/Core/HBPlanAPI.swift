import Foundation

// Plan's calls to the existing backend: budgets (/api/budgets), debts (/api/debts…), the account's own categories (/api/categories…).
// The same bodies Classic sends.

struct HBDebtDraft {
    var name = ""
    var balance = 0.0     // what is owed (at the start, when editing)
    var apr = 0.0         // percent, 0–100
    var minimum = 0.0     // minimum payment per month
    var json: [String: Any] { ["name": name.trimmingCharacters(in: .whitespaces), "balance": balance, "apr": apr, "min": minimum] }
}

extension HBAPI {
    /// replaces all budgets (a category missing from `limits` or with 0 loses its limit) and sets the roll-over switch
    func saveBudgets(_ limits: [String: Double], rollover: Bool) async throws {
        let items = limits.filter { $0.value > 0 }.map { ["category": $0.key, "limit": $0.value] as [String: Any] }
        _ = try await send("/api/budgets", method: "PUT", body: ["items": items, "rollover": rollover])
    }

    func addDebt(_ d: HBDebtDraft) async throws { _ = try await send("/api/debts", method: "POST", body: d.json) }
    func updateDebt(id: String, _ d: HBDebtDraft) async throws { _ = try await send("/api/debts/" + id, method: "PATCH", body: d.json) }
    func deleteDebt(id: String) async throws { _ = try await send("/api/debts/" + id, method: "DELETE", body: nil) }
    /// logs a payment (the backend also files it as a "Payment: …" expense so it counts in the month)
    func payDebt(id: String, amount: Double, memberID: String, date: String) async throws {
        _ = try await send("/api/debts/" + id + "/pay", method: "POST", body: ["amount": amount, "member_id": memberID, "date": date])
    }
    func deleteDebtPayment(id: String) async throws { _ = try await send("/api/debt-payments/" + id, method: "DELETE", body: nil) }

    @discardableResult func createCategory(name: String, emoji: String) async throws -> String {
        let data = try await send("/api/categories", method: "POST", body: ["name": name, "emoji": emoji])
        return ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["id"] as? String ?? ""
    }
    func updateCategory(id: String, name: String, emoji: String) async throws { _ = try await send("/api/categories/" + id, method: "PATCH", body: ["name": name, "emoji": emoji]) }
    func deleteCategory(id: String) async throws { _ = try await send("/api/categories/" + id, method: "DELETE", body: nil) }
}

// Stats, referrals and household changes: the same endpoints Classic uses.
extension HBAPI {
    func year(_ y: Int) async throws -> HBYearData { try decode(try await send("/api/year?year=\(y)", method: "GET", body: nil)) }
    func referrals() async throws -> HBReferrals { try decode(try await send("/api/referrals", method: "GET", body: nil)) }
    /// Join another budget with its invite code. Only allowed when you are the only member of yours, and it REPLACES yours (the backend deletes the old one).
    func switchBudget(code: String) async throws { _ = try await send("/api/nests/switch", method: "POST", body: ["code": code, "confirm": true]) }
    /// Leave your budget (if you were the only one in it, it is deleted).
    func leaveBudget() async throws { _ = try await send("/api/nest/leave", method: "POST", body: nil) }
}

// Apple Pay auto-logging: a key for an iPhone Shortcut (POST /api/log with "Authorization: Bearer <key>").
extension HBAPI {
    /// makes a new key (the old one stops working) and returns it; it is only shown this once
    func makeShortcutKey() async throws -> String {
        let data = try await send("/api/shortcut/key", method: "POST", body: [:])
        return ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["key"] as? String ?? ""
    }
    func revokeShortcutKey() async throws { _ = try await send("/api/shortcut/key", method: "DELETE", body: nil) }
}
