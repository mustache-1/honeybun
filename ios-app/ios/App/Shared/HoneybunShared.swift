import Foundation

// Shared by the app (Siri shortcuts) and the widget. The token is made by honeybun.me for this phone only
// and stored in the App Group, so the widget can ask "what's left?" without opening the app.
enum Honeybun {
    static let group = "group.me.honeybun.app"
    static let api = "https://honeybun.me"
    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }
    static var token: String? {
        get { defaults.string(forKey: "appToken") }
        set { defaults.set(newValue, forKey: "appToken") }
    }
}

struct NextBill: Codable {
    let label: String
    let amount: Double
    let date: String
}

struct BudgetSummary: Codable {
    let month: String
    let name: String
    let kind: String
    let income: Double
    let spent: Double
    let left: Double
    let next: NextBill?

    static let sample = BudgetSummary(month: "2026-10", name: "Rosie & Rodrigo", kind: "couple", income: 5300, spent: 1630, left: 3670, next: NextBill(label: "Car insurance", amount: 132, date: "2026-10-01"))
}

enum HoneybunError: Error { case notSignedIn, network, server(String) }

enum HoneybunAPI {
    private static func request(_ path: String, method: String = "GET", body: Data? = nil, form: Bool = false) async throws -> Data {
        guard let token = Honeybun.token, let url = URL(string: Honeybun.api + path) else { throw HoneybunError.notSignedIn }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 15
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body = body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw HoneybunError.network }
        if http.statusCode == 401 { throw HoneybunError.notSignedIn }
        if !(200..<300).contains(http.statusCode) {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw HoneybunError.server(msg ?? "Something went wrong.")
        }
        return data
    }

    static func summary() async throws -> BudgetSummary {
        let data = try await request("/api/app/summary")
        return try JSONDecoder().decode(BudgetSummary.self, from: data)
    }

    // Logs an expense the same way the Apple Pay shortcut does; Bun guesses the category from the store name.
    static func logExpense(amount: Double, store: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["amount": String(format: "%.2f", amount), "store": store])
        let data = try await request("/api/log", method: "POST", body: body)
        let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
        return msg ?? "Logged."
    }
}

extension Double {
    var dollars: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = self.rounded() == self ? 0 : 2
        return f.string(from: NSNumber(value: self)) ?? "$\(self)"
    }
}
