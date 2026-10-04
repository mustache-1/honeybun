#if DEBUG
import Foundation

// Debug builds only (compiled out of Release/TestFlight). Launch with `-HBMock <default|empty|short|long>` and the native screens run their REAL
// code path (HBAPI -> URLSession -> JSON -> decoder -> store -> views) against this in-process stand-in for honeybun.me's goals/jar endpoints,
// which follow src/worker.js (same validation, same saved_cents arithmetic, same CSRF header check). It lets the simulator tap through every
// Goals action with no login and no network, and keeps real money out of the tests.
final class HBMockServer: URLProtocol {
    private static let lock = NSLock()
    private static var state: [String: Any] = [:]
    private static var clock = 1_791_200_000.0

    static var requestedSeed: String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-HBMock"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    static func install(seed: String) {
        lock.lock(); defer { lock.unlock() }
        var s = (try? JSONSerialization.jsonObject(with: Data(HBPreviewData.json.utf8))) as? [String: Any] ?? [:]
        var goals = s["goals"] as? [[String: Any]] ?? []
        var jar = s["jar"] as? [[String: Any]] ?? []
        func goal(_ name: String, _ emoji: String, _ target: Int, _ saved: Int) -> [String: Any] {
            ["id": UUID().uuidString.lowercased(), "name": name, "emoji": emoji, "target_cents": target * 100, "saved_cents": saved * 100]
        }
        switch seed {
        case "empty":
            goals = []; jar = []
        case "short":
            if goals.count >= 3 { goals = [goals[0], goals[2]] }
            let ids = Set(goals.compactMap { $0["id"] as? String })
            jar = jar.filter { ids.contains($0["goal_id"] as? String ?? "") }
        case "long":
            goals += [
                goal("Car Down Payment", "🚗", 4000, 1250), goal("House Deposit", "🏠", 20000, 6400), goal("Birthday Gifts", "🎁", 300, 300),
                goal("Pet Care", "🐶", 800, 120), goal("Course Fees", "🎓", 1500, 900), goal("Holiday Trip", "🎄", 2500, 2500),
                goal("Rainy Day Buffer", "🛟", 5000, 2750), goal("Savings Jar", "🍯", 1000, 0),
            ]
        default: break
        }
        clock = (jar.compactMap { $0["created_at"] as? Double }.max() ?? clock) + 1
        s["goals"] = goals; s["jar"] = jar
        state = s
        URLProtocol.registerClass(HBMockServer.self)
    }

    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "honeybun.me" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        var raw = request.httpBody
        if raw == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var data = Data(); var buf = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buf, maxLength: buf.count); if n <= 0 { break }; data.append(buf, count: n) }
            raw = data
        }
        var body: [String: Any] = [:]
        if let raw = raw, let o = (try? JSONSerialization.jsonObject(with: raw)) as? [String: Any] { body = o }
        let url = request.url ?? URL(string: "https://honeybun.me/")!
        let method = request.httpMethod ?? "GET"
        var status = 200; var obj: Any = [:]
        let origin = request.value(forHTTPHeaderField: "Origin"); let type = request.value(forHTTPHeaderField: "Content-Type") ?? ""
        if method != "GET" && (origin != "https://honeybun.me" || !type.contains("application/json")) {
            status = 403; obj = ["error": "Blocked: not from Honeybun."]
        } else {
            (status, obj) = Self.handle(method, url.path, body)
        }
        let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data("{}".utf8)
        let resp = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func cents(_ v: Any?) -> Int? {
        guard let d = (v as? NSNumber)?.doubleValue, d > 0, d <= 100_000_000 else { return nil }
        return Int((d * 100).rounded())
    }

    private static func handle(_ method: String, _ path: String, _ body: [String: Any]) -> (Int, Any) {
        lock.lock(); defer { lock.unlock() }
        var goals = state["goals"] as? [[String: Any]] ?? []
        var jar = state["jar"] as? [[String: Any]] ?? []
        defer { state["goals"] = goals; state["jar"] = jar }
        let emojis = HBGoalStyle.emojis
        func index(_ id: String) -> Int? { goals.firstIndex { ($0["id"] as? String) == id } }
        let last = path.split(separator: "/").last.map(String.init) ?? ""

        if path == "/api/nest" && method == "GET" { var s = state; s["goals"] = goals; s["jar"] = jar; return (200, s) }

        if path == "/api/goals" && method == "POST" {
            let name = String((body["name"] as? String ?? "").trimmingCharacters(in: .whitespaces).prefix(30))
            if name.isEmpty { return (400, ["error": "Name your goal."]) }
            guard let t = cents(body["target"]) else { return (400, ["error": "Enter a target more than $0."]) }
            let e = emojis.contains(body["emoji"] as? String ?? "") ? (body["emoji"] as? String ?? emojis[0]) : emojis[0]
            let id = UUID().uuidString.lowercased()
            goals.append(["id": id, "name": name, "emoji": e, "target_cents": t, "saved_cents": 0])
            return (201, ["ok": true, "id": id])
        }
        if path.hasPrefix("/api/goals/") && method == "PATCH" {
            let name = String((body["name"] as? String ?? "").trimmingCharacters(in: .whitespaces).prefix(30))
            if name.isEmpty { return (400, ["error": "Name your goal."]) }
            guard let t = cents(body["target"]) else { return (400, ["error": "Enter a target more than $0."]) }
            if let i = index(last) {
                goals[i]["name"] = name; goals[i]["target_cents"] = t
                if let e = body["emoji"] as? String, emojis.contains(e) { goals[i]["emoji"] = e }
            }
            return (200, ["ok": true])
        }
        if path.hasPrefix("/api/goals/") && method == "DELETE" {
            jar.removeAll { ($0["goal_id"] as? String) == last }
            goals.removeAll { ($0["id"] as? String) == last }
            return (200, ["ok": true])
        }
        if path == "/api/jar" && method == "POST" {
            guard let gid = body["goal_id"] as? String, let i = index(gid) else { return (400, ["error": "Pick a savings goal."]) }
            guard let c = cents(body["amount"]) else { return (400, ["error": "Enter an amount more than $0."]) }
            let signed = (body["direction"] as? String) == "out" ? -c : c
            let saved = goals[i]["saved_cents"] as? Int ?? 0
            if saved + signed < 0 { return (400, ["error": "You can't take out more than you've saved for this goal."]) }
            clock += 1
            let me = ((state["me"] as? [String: Any])?["id"] as? String) ?? ""
            jar.append(["id": UUID().uuidString.lowercased(), "goal_id": gid, "member_id": me, "amount_cents": signed, "created_at": clock])
            goals[i]["saved_cents"] = saved + signed
            return (200, ["ok": true])
        }
        if path.hasPrefix("/api/jar/") && method == "DELETE" {
            guard let j = jar.firstIndex(where: { ($0["id"] as? String) == last }) else { return (404, ["error": "Not found."]) }
            let amount = jar[j]["amount_cents"] as? Int ?? 0
            if let gid = jar[j]["goal_id"] as? String, let i = index(gid) { goals[i]["saved_cents"] = max(0, (goals[i]["saved_cents"] as? Int ?? 0) - amount) }
            jar.remove(at: j)
            return (200, ["ok": true])
        }
        return (404, ["error": "Not found."])
    }
}
#endif
