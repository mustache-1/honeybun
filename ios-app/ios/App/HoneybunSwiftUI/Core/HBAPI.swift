import Foundation

enum HBAPIError: LocalizedError {
    case badURL, notSignedIn, http(Int, String), decoding(String)
    var errorDescription: String? {
        switch self {
        case .badURL: return "Bad Honeybun URL."
        case .notSignedIn: return "Please log in."
        case let .http(_, s): return s
        case let .decoding(s): return "Honeybun sent something this screen didn't expect (\(s))."
        }
    }
}

// Talks to the existing honeybun.me backend with the website's own session cookie (see HBSession).
// The server only accepts changes that come from its own origin as JSON, so every request says so.
actor HBAPI {
    static let shared = HBAPI()
    nonisolated let baseURL = URL(string: "https://honeybun.me")!
    private let decoder = JSONDecoder()

    /// `unauth: true` is for the sign-in calls themselves: a 401 there is "wrong password", with the server's own message, not "you are signed out".
    func send(_ path: String, method: String, body: [String: Any]?, unauth: Bool = false) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { throw HBAPIError.badURL }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.timeoutInterval = 20
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue("https://honeybun.me", forHTTPHeaderField: "Origin")
        r.setValue(HBDevice.id(), forHTTPHeaderField: "x-hb-device")
        r.setValue(HBDay.todayString, forHTTPHeaderField: "x-local-date")      // so the carrot streak counts the phone's own day, like the website
        if let body = body {
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if method != "GET" {
            r.httpBody = Data("{}".utf8)
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: r)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 && !unauth { throw HBAPIError.notSignedIn }
        guard (200..<300).contains(status) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw HBAPIError.http(status, msg ?? "Something went wrong (\(status)).")
        }
        return data
    }

    func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try decoder.decode(T.self, from: data) }
        catch { throw HBAPIError.decoding(String(describing: error)) }
    }

    func nest(month: String) async throws -> HBNestSnapshot { try decode(try await send("/api/nest?month=\(month)", method: "GET", body: nil)) }
    func me() async throws -> HBMeEnvelope { try decode(try await send("/api/me", method: "GET", body: nil)) }

    /// `clientID` makes a retry harmless: the server answers "duplicate" instead of adding the entry twice. Returns the server's answer (it holds the carrot reward).
    @discardableResult
    func addEntry(_ d: HBEntryDraft, clientID: String? = nil) async throws -> Data {
        var body = d.json
        if let c = clientID { body["client_id"] = c }
        return try await send("/api/entries", method: "POST", body: body)
    }

    // The last good /api/me and /api/nest answers are kept on the phone (HBOfflineCache), so the app can still open with no connection.
    // A connection problem (and only that) falls back to them; "not signed in" and server errors never do.
    func meOrCached() async throws -> (me: HBMeEnvelope, cached: Bool) {
        do {
            let data = try await send("/api/me", method: "GET", body: nil)
            let me: HBMeEnvelope = try decode(data)
            if let id = me.user?.id { HBOfflineCache.shared.save("/api/me", data, owner: id) }
            return (me, false)
        } catch let e as URLError {
            if let data = HBOfflineCache.shared.load("/api/me"), let me: HBMeEnvelope = try? decode(data), me.user != nil { return (me, true) }
            throw e
        }
    }
    func nestOrCached(month: String) async throws -> (snapshot: HBNestSnapshot, cached: Bool) {
        let path = "/api/nest?month=\(month)"
        do {
            let data = try await send(path, method: "GET", body: nil)
            let snap: HBNestSnapshot = try decode(data)
            if let id = snap.me?.id { HBOfflineCache.shared.save(path, data, owner: id) }
            return (snap, false)
        } catch let e as URLError {
            if let data = HBOfflineCache.shared.load(path), let snap: HBNestSnapshot = try? decode(data) { return (snap, true) }
            throw e
        }
    }
    func updateEntry(id: String, _ d: HBEntryDraft) async throws { _ = try await send("/api/entries/\(id)", method: "PATCH", body: d.json) }
    func deleteEntry(id: String) async throws { _ = try await send("/api/entries/\(id)", method: "DELETE", body: nil) }
    /// "Undo" after a delete: the same entry again, with its split, privacy and any bill it came from (the website's entryPayload + restore)
    func restoreEntry(_ e: HBEntry) async throws {
        var b: [String: Any] = ["type": e.type, "amount": e.amount, "label": e.label, "member_id": e.member_id, "shared": e.shared == 1, "private": e.isPrivate == 1, "date": e.date, "restore": true]
        if let c = e.category { b["category"] = c }
        if let m = e.split_mode, e.shared == 1 { b["split_mode"] = m; if let v = e.split_value { b["split_value"] = m == "owed" ? Double(v) / 100.0 : Double(v) } }
        if let r = e.recurring_id { b["recurring_id"] = r }
        if let o = e.occ_date { b["occ_date"] = o }
        _ = try await send("/api/entries", method: "POST", body: b)
    }

    func addGoal(_ d: HBGoalDraft) async throws { _ = try await send("/api/goals", method: "POST", body: d.json) }
    func updateGoal(id: String, _ d: HBGoalDraft) async throws { _ = try await send("/api/goals/\(id)", method: "PATCH", body: d.json) }
    func deleteGoal(id: String) async throws { _ = try await send("/api/goals/\(id)", method: "DELETE", body: nil) }
    @discardableResult
    func moveJar(goalID: String, amount: Double, out: Bool) async throws -> Data { try await send("/api/jar", method: "POST", body: ["goal_id": goalID, "amount": amount, "direction": out ? "out" : "in"]) }
    func deleteJarMove(id: String) async throws { _ = try await send("/api/jar/\(id)", method: "DELETE", body: nil) }

    // Together: shared shopping list, paying each other back, the household
    func shopping() async throws -> [HBShopItem] { let e: HBShopEnvelope = try decode(try await send("/api/shopping", method: "GET", body: nil)); return e.items }
    func addShopItem(_ label: String) async throws { _ = try await send("/api/shopping", method: "POST", body: ["label": label]) }
    func setShopDone(id: String, done: Bool) async throws { _ = try await send("/api/shopping/\(id)", method: "PATCH", body: ["done": done]) }
    func renameShopItem(id: String, label: String) async throws { _ = try await send("/api/shopping/\(id)", method: "PATCH", body: ["label": label]) }
    func deleteShopItem(id: String) async throws { _ = try await send("/api/shopping/\(id)", method: "DELETE", body: nil) }
    func clearShopDone() async throws { _ = try await send("/api/shopping/clear", method: "POST", body: nil) }
    func shopCheckout(amount: Double, date: String) async throws { _ = try await send("/api/shopping/checkout", method: "POST", body: ["amount": amount, "date": date]) }
    @discardableResult
    func settle(from: String, to: String, amount: Double, date: String) async throws -> Data {
        try await send("/api/settlements", method: "POST", body: ["from_id": from, "to_id": to, "amount": amount, "date": date])
    }
    func deleteSettlement(id: String) async throws { _ = try await send("/api/settlements/\(id)", method: "DELETE", body: nil) }
    func patchNest(_ body: [String: Any]) async throws { _ = try await send("/api/nest", method: "PATCH", body: body) }
    func newInviteCode() async throws -> String {
        let data = try await send("/api/nest/invite", method: "POST", body: nil)
        return ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["invite_code"] as? String ?? ""
    }
    func updateMe(name: String, emoji: String, color: String) async throws { _ = try await send("/api/me", method: "PATCH", body: ["name": name, "emoji": emoji, "color": color]) }
    func search(q: String, type: String, member: String) async throws -> [HBEntry] {
        var f = HBSearchFilter(); f.q = q; f.type = type.isEmpty ? "all" : type; f.member = member.isEmpty ? "all" : member
        return try await search(f)
    }
    func search(_ f: HBSearchFilter) async throws -> [HBEntry] {
        var c = URLComponents(); c.path = "/api/search"
        c.queryItems = f.queryItems
        let env: HBSearchEnvelope = try decode(try await send(c.string ?? "/api/search", method: "GET", body: nil))
        return env.entries
    }

    // Inbox: Bun's messages
    func inbox() async throws -> [HBInboxMessage] { let e: HBInboxEnvelope = try decode(try await send("/api/inbox", method: "GET", body: nil)); return e.messages }
    func markInboxRead() async throws { _ = try await send("/api/inbox/read", method: "POST", body: nil) }
    func decideCarry(month: String, accept: Bool, remember: Bool) async throws {
        _ = try await send("/api/carry", method: "POST", body: ["month": month, "accept": accept, "change": false, "remember": remember])
    }

    @discardableResult
    func logOccurrence(recurringID: String, date: String) async throws -> Data { try await send("/api/recurring/\(recurringID)/log", method: "POST", body: ["occ_date": date]) }
    func updateRecurring(id: String, _ d: HBRecurringDraft) async throws { _ = try await send("/api/recurring/\(id)", method: "PATCH", body: d.json) }
    @discardableResult
    func addRecurring(_ d: HBRecurringDraft) async throws -> Data { try await send("/api/recurring", method: "POST", body: d.json) }
    func deleteRecurring(id: String) async throws { _ = try await send("/api/recurring/\(id)", method: "DELETE", body: nil) }
}
