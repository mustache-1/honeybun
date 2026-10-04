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
        let together = ["solo", "partner", "family", "joint", "inbox", "inboxempty"].contains(seed)
        var s = together ? HBPreviewVariants.make(seed) : ((try? JSONSerialization.jsonObject(with: Data(HBPreviewData.json.utf8))) as? [String: Any] ?? [:])
        s["shopping"] = HBPreviewVariants.shopping
        if seed == "inbox" || seed == "inboxempty" {
            let rec = (s["recurring"] as? [[String: Any]] ?? []).map { ($0["id"] as? String ?? "", $0["label"] as? String ?? "", $0["amount_cents"] as? Int ?? 0) }
            s["inboxMessages"] = HBPreviewVariants.inboxMessages(seed == "inbox" ? "mixed" : "empty", recurring: rec)
        }
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
            var query: [String: String] = [:]
            for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] { query[item.name] = item.value ?? "" }
            (status, obj) = Self.handle(method, url.path, body, query)
        }
        let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data("{}".utf8)
        let resp = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    // Together: household, shared shopping list, settling up, joint account, edit yourself, search. Mirrors src/worker.js.
    // (called with the lock already held)
    private static func intDict(_ v: Any?) -> [String: Int] { (v as? [String: Any])?.compactMapValues { ($0 as? NSNumber)?.intValue } ?? [:] }

    private static func handleTogether(_ method: String, _ path: String, _ body: [String: Any], _ query: [String: String]) -> (Int, Any)? {
        var nest = state["nest"] as? [String: Any] ?? [:]
        var members = state["members"] as? [[String: Any]] ?? []
        var entries = state["entries"] as? [[String: Any]] ?? []
        var settlements = state["settlements"] as? [[String: Any]] ?? []
        var balances = intDict(state["balances"])
        var shopping = state["shopping"] as? [[String: Any]] ?? []
        defer { state["nest"] = nest; state["members"] = members; state["entries"] = entries; state["settlements"] = settlements; state["balances"] = balances; state["shopping"] = shopping }
        let meID = ((state["me"] as? [String: Any])?["id"] as? String) ?? ""
        let last = path.split(separator: "/").last.map(String.init) ?? ""
        func clean(_ v: Any?, _ max: Int) -> String { String(((v as? String) ?? "").trimmingCharacters(in: .whitespaces).prefix(max)) }
        func newID() -> String { UUID().uuidString.lowercased() }

        // ---- Inbox: Bun's messages, reading them, the carry-over question, marking a bill paid from a message
        if path == "/api/nest" && method == "GET", let msgs = state["inboxMessages"] as? [[String: Any]] {
            state["inbox"] = ["unread": msgs.filter { $0["read_at"] is NSNull }.count]
            return nil
        }
        if path == "/api/inbox" && method == "GET" {
            let msgs = (state["inboxMessages"] as? [[String: Any]] ?? []).sorted { ($0["created_at"] as? Double ?? 0) < ($1["created_at"] as? Double ?? 0) }
            return (200, ["messages": msgs])
        }
        if path == "/api/inbox/read" && method == "POST" {
            clock += 1
            let stamped: [[String: Any]] = (state["inboxMessages"] as? [[String: Any]] ?? []).map { var c = $0; if c["read_at"] is NSNull { c["read_at"] = clock }; return c }
            state["inboxMessages"] = stamped; state["inbox"] = ["unread": 0]
            return (200, ["ok": true])
        }
        if path == "/api/carry" && method == "POST" {
            guard let pending = state["carry_pending"] as? [String: Any] else { return (200, ["ok": true, "already": true]) }
            let accept = (body["accept"] as? Bool) ?? false
            let amount = pending["amount_cents"] as? Int ?? 0
            state["carry_pending"] = NSNull()
            state["carry_in"] = ["amount_cents": accept ? amount : 0, "accepted": accept]
            if (body["remember"] as? Bool) == true { nest["carry_mode"] = accept ? "always" : "never" }
            return (200, ["ok": true, "amount_cents": accept ? amount : 0, "accepted": accept])
        }
        if path.hasPrefix("/api/recurring/") && path.hasSuffix("/log") && method == "POST" {
            let rid = path.replacingOccurrences(of: "/api/recurring/", with: "").replacingOccurrences(of: "/log", with: "")
            let occ = body["occ_date"] as? String ?? ""
            var logged = state["logged"] as? [[String: Any]] ?? []
            guard let r = (state["recurring"] as? [[String: Any]] ?? []).first(where: { ($0["id"] as? String) == rid }) else { return (404, ["error": "That bill is gone."]) }
            if logged.contains(where: { ($0["recurring_id"] as? String) == rid && ($0["occ_date"] as? String) == occ }) { return (200, ["ok": true, "already": true]) }
            logged.append(["recurring_id": rid, "occ_date": occ]); state["logged"] = logged
            let income = (r["type"] as? String) == "income"
            entries.insert(["id": newID(), "member_id": meID, "type": income ? "income" : "expense", "amount_cents": r["amount_cents"] as? Int ?? 0, "label": r["label"] as? String ?? "",
                            "category": income ? NSNull() : (r["category"] as? String ?? "bills"), "shared": 0, "split_mode": NSNull(), "split_value": NSNull(), "shares": NSNull(), "private": 0,
                            "date": occ, "recurring_id": rid, "occ_date": occ, "created_at": clock], at: 0)
            return (201, ["ok": true])
        }

        if path == "/api/nest" && method == "PATCH" {
            if body["name"] != nil { nest["name"] = clean(body["name"], 24) }
            if body["kind"] != nil {
                let k = body["kind"] as? String ?? ""
                if !["solo", "couple", "family"].contains(k) { return (400, ["error": "Unknown budget type."]) }
                nest["kind"] = k
            }
            if let j = body["joint"] {
                let on = (j as? Bool) ?? ((j as? NSNumber)?.boolValue ?? false)
                if on && (nest["kind"] as? String) != "couple" { return (400, ["error": "Joint account is for couples."]) }
                nest["joint"] = on ? 1 : 0
            }
            return (200, ["ok": true])
        }
        if path == "/api/nest/invite" && method == "POST" {
            let code = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").uppercased().prefix(8))
            nest["invite_code"] = code
            return (200, ["ok": true, "invite_code": code])
        }
        if path == "/api/me" && method == "PATCH" {
            if body["name"] != nil {
                let n = clean(body["name"], 24)
                if n.isEmpty { return (400, ["error": "Enter a name."]) }
                if let i = members.firstIndex(where: { ($0["id"] as? String) == meID }) { members[i]["name"] = n }
                var me = state["me"] as? [String: Any] ?? [:]; me["name"] = n; state["me"] = me
            }
            if let e = body["emoji"] as? String {
                if !HBTogether.emojis.contains(e) { return (400, ["error": "Pick one of the buddies."]) }
                if let i = members.firstIndex(where: { ($0["id"] as? String) == meID }) { members[i]["emoji"] = e }
            }
            if let c = body["color"] as? String {
                if !HBTogether.colors.contains(c) { return (400, ["error": "Pick one of the colors."]) }
                if let i = members.firstIndex(where: { ($0["id"] as? String) == meID }) { members[i]["color"] = c }
            }
            return (200, ["ok": true])
        }

        if path == "/api/shopping" && method == "GET" { return (200, ["items": shopping]) }
        if path == "/api/shopping" && method == "POST" {
            let label = clean(body["label"], 60)
            if label.isEmpty { return (400, ["error": "Type what you need."]) }
            if shopping.count >= 100 { return (400, ["error": "The list is full. Clear the checked items first."]) }
            let id = newID()
            shopping.insert(["id": id, "label": label, "added_by": meID, "done": false, "done_by": NSNull()], at: shopping.firstIndex(where: { ($0["done"] as? Bool) == true }) ?? shopping.count)
            return (201, ["ok": true, "id": id])
        }
        if path == "/api/shopping/clear" && method == "POST" { shopping.removeAll { ($0["done"] as? Bool) == true }; return (200, ["ok": true]) }
        if path == "/api/shopping/checkout" && method == "POST" {
            guard let amount = cents(body["amount"]) else { return (400, ["error": "Enter an amount more than $0."]) }
            let shared = members.count > 1 && (nest["joint"] as? Int ?? 0) == 0
            entries.insert(["id": newID(), "member_id": meID, "type": "expense", "amount_cents": amount, "label": "Groceries", "category": "groc", "shared": shared ? 1 : 0,
                            "split_mode": "equal", "split_value": NSNull(), "shares": NSNull(), "private": 0, "date": (body["date"] as? String) ?? "2026-10-04",
                            "recurring_id": NSNull(), "occ_date": NSNull(), "created_at": clock], at: 0)
            if shared {   // equal split: I paid it all, everyone owes their share
                let each = amount / members.count
                for m in members { let id = m["id"] as? String ?? ""; balances[id, default: 0] += (id == meID ? amount - each : -each) }
            }
            shopping.removeAll { ($0["done"] as? Bool) == true }
            return (201, ["ok": true])
        }
        if path.hasPrefix("/api/shopping/") {
            guard let i = shopping.firstIndex(where: { ($0["id"] as? String) == last }) else { return method == "DELETE" ? (200, ["ok": true]) : (404, ["error": "That item is gone."]) }
            if method == "DELETE" { shopping.remove(at: i); return (200, ["ok": true]) }
            if method == "PATCH" {
                if body["label"] != nil && body["done"] == nil {
                    let label = clean(body["label"], 60)
                    if label.isEmpty { return (400, ["error": "Type what you need."]) }
                    shopping[i]["label"] = label
                } else {
                    let done = (body["done"] as? Bool) ?? ((body["done"] as? NSNumber)?.boolValue ?? false)
                    shopping[i]["done"] = done; shopping[i]["done_by"] = done ? meID : NSNull()
                    let item = shopping.remove(at: i)   // ticked items sink to the bottom, like the website
                    if done { shopping.append(item) } else { shopping.insert(item, at: shopping.firstIndex(where: { ($0["done"] as? Bool) == true }) ?? shopping.count) }
                }
                return (200, ["ok": true])
            }
        }

        if path == "/api/settlements" && method == "POST" {
            let ids = members.compactMap { $0["id"] as? String }
            let from = body["from_id"] as? String ?? "", to = body["to_id"] as? String ?? ""
            if !ids.contains(from) || !ids.contains(to) || from == to { return (400, ["error": "Pick who paid who."]) }
            guard let c = cents(body["amount"]) else { return (400, ["error": "Enter an amount more than $0."]) }
            clock += 1
            settlements.insert(["id": newID(), "from_id": from, "to_id": to, "amount_cents": c, "date": (body["date"] as? String) ?? "2026-10-04", "created_at": clock], at: 0)
            balances[from, default: 0] += c; balances[to, default: 0] -= c
            return (201, ["ok": true])
        }
        if path.hasPrefix("/api/settlements/") && method == "DELETE" {
            if let i = settlements.firstIndex(where: { ($0["id"] as? String) == last }) {
                let c = settlements[i]["amount_cents"] as? Int ?? 0
                balances[settlements[i]["from_id"] as? String ?? "", default: 0] -= c; balances[settlements[i]["to_id"] as? String ?? "", default: 0] += c
                settlements.remove(at: i)
            }
            return (200, ["ok": true])
        }

        if path == "/api/search" && method == "GET" {
            let q = (query["q"] ?? "").lowercased(), type = query["type"] ?? "", who = query["member"] ?? ""
            let hits = entries.filter { e in
                (q.isEmpty || ((e["label"] as? String) ?? "").lowercased().contains(q)) && (type.isEmpty || (e["type"] as? String) == type) && (who.isEmpty || (e["member_id"] as? String) == who)
            }
            return (200, ["entries": hits])
        }
        return nil
    }

    private static func cents(_ v: Any?) -> Int? {
        guard let d = (v as? NSNumber)?.doubleValue, d > 0, d <= 100_000_000 else { return nil }
        return Int((d * 100).rounded())
    }

    private static func handle(_ method: String, _ path: String, _ body: [String: Any], _ query: [String: String]) -> (Int, Any) {
        lock.lock(); defer { lock.unlock() }
        if let r = handleTogether(method, path, body, query) { return r }
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
