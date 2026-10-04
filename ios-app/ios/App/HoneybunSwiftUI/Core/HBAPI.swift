import Foundation

enum HBAPIError: LocalizedError {
    case badURL, notSignedIn, http(Int, String), decoding(String)
    var errorDescription: String? {
        switch self {
        case .badURL: return "Bad Honeybun URL."
        case .notSignedIn: return "You're signed out. Open the classic Honeybun and sign in first."
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

    private func send(_ path: String, method: String, body: [String: Any]?) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { throw HBAPIError.badURL }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.timeoutInterval = 20
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue("https://honeybun.me", forHTTPHeaderField: "Origin")
        if let body = body {
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if method != "GET" {
            r.httpBody = Data("{}".utf8)
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: r)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw HBAPIError.notSignedIn }
        guard (200..<300).contains(status) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw HBAPIError.http(status, msg ?? "Something went wrong (\(status)).")
        }
        return data
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try decoder.decode(T.self, from: data) }
        catch { throw HBAPIError.decoding(String(describing: error)) }
    }

    func nest(month: String) async throws -> HBNestSnapshot { try decode(try await send("/api/nest?month=\(month)", method: "GET", body: nil)) }
    func me() async throws -> HBMeEnvelope { try decode(try await send("/api/me", method: "GET", body: nil)) }

    func addEntry(_ d: HBEntryDraft) async throws { _ = try await send("/api/entries", method: "POST", body: d.json) }
    func updateEntry(id: String, _ d: HBEntryDraft) async throws { _ = try await send("/api/entries/\(id)", method: "PATCH", body: d.json) }
    func deleteEntry(id: String) async throws { _ = try await send("/api/entries/\(id)", method: "DELETE", body: nil) }

    func addGoal(_ d: HBGoalDraft) async throws { _ = try await send("/api/goals", method: "POST", body: d.json) }
    func updateGoal(id: String, _ d: HBGoalDraft) async throws { _ = try await send("/api/goals/\(id)", method: "PATCH", body: d.json) }
    func deleteGoal(id: String) async throws { _ = try await send("/api/goals/\(id)", method: "DELETE", body: nil) }
    func moveJar(goalID: String, amount: Double, out: Bool) async throws { _ = try await send("/api/jar", method: "POST", body: ["goal_id": goalID, "amount": amount, "direction": out ? "out" : "in"]) }
    func deleteJarMove(id: String) async throws { _ = try await send("/api/jar/\(id)", method: "DELETE", body: nil) }

    func logOccurrence(recurringID: String, date: String) async throws { _ = try await send("/api/recurring/\(recurringID)/log", method: "POST", body: ["occ_date": date]) }
    func updateRecurring(id: String, _ d: HBRecurringDraft) async throws { _ = try await send("/api/recurring/\(id)", method: "PATCH", body: d.json) }
    func addRecurring(_ d: HBRecurringDraft) async throws { _ = try await send("/api/recurring", method: "POST", body: d.json) }
    func deleteRecurring(id: String) async throws { _ = try await send("/api/recurring/\(id)", method: "DELETE", body: nil) }
}
