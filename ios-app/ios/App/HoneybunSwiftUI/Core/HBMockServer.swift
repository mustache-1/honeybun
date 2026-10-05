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
        authMode = seed == "auth"
        users = []; sessions = [:]; passkeyStore = []; apnsTokens = []
        if authMode { state = [:]; URLProtocol.registerClass(HBMockServer.self); return }
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
        var setCookie: String? = nil
        let origin = request.value(forHTTPHeaderField: "Origin"); let type = request.value(forHTTPHeaderField: "Content-Type") ?? ""
        if method != "GET" && (origin != "https://honeybun.me" || !type.contains("application/json")) {
            status = 403; obj = ["error": "Blocked: not from Honeybun."]
        } else if HBMockServer.authMode, let r = HBMockServer.handleAuth(method, url.path, body, request) {
            (status, obj, setCookie) = r
        } else {
            var query: [String: String] = [:]
            for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] { query[item.name] = item.value ?? "" }
            (status, obj) = Self.handle(method, url.path, body, query)
        }
        let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data("{}".utf8)
        var headers = ["Content-Type": "application/json"]
        if let c = setCookie {
            headers["Set-Cookie"] = c
            // a real URLSession would store this cookie itself; this stand-in does it by hand
            for cookie in HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": c], for: url) {
                if cookie.value.isEmpty { HTTPCookieStorage.shared.deleteCookie(cookie) } else { HTTPCookieStorage.shared.setCookie(cookie) }
            }
        }
        let resp = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
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

    // MARK: sign-in stand-in (seed "auth"): the backend's real rules for accounts, sessions, recovery codes and passkeys, in memory
    private static var authMode = false
    private static var apnsTokens = Set<String>()
    private static var users: [[String: Any]] = []
    private static var sessions: [String: String] = [:]          // session token -> user id
    private static var passkeyStore: [[String: Any]] = []        // {id, user, name, created}
    private static let sessionCookieName = "__Host-hb"

    private static func randomCode() -> String {
        let a = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789"); let c = (0..<12).map { _ in String(a.randomElement()!) }.joined()
        return "\(c.prefix(4))-\(c.dropFirst(4).prefix(4))-\(c.dropFirst(8))"
    }
    private static func cookie(_ token: String, maxAge: Int = 2592000) -> String { "\(sessionCookieName)=\(token); Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=\(maxAge)" }
    private static func newSession(_ uid: String) -> String { let t = UUID().uuidString.lowercased(); sessions[t] = uid; return cookie(t) }
    private static func loginKey(_ v: String) -> String { let x = v.trimmingCharacters(in: .whitespaces).lowercased(); return x.contains("@") ? x : x + "@u.honeybun.invalid" }
    private static func userIndex(key: String) -> Int? { users.firstIndex { ($0["email"] as? String) == key } }
    private static func currentUserIndex() -> Int? {
        guard let c = (HTTPCookieStorage.shared.cookies(for: URL(string: "https://honeybun.me")!) ?? []).first(where: { $0.name == sessionCookieName }),
              let uid = sessions[c.value] else { return nil }
        return users.firstIndex { ($0["id"] as? String) == uid }
    }
    private static func me(_ u: [String: Any]) -> [String: Any] {
        let email = u["email"] as? String ?? ""
        return ["id": u["id"] as? String ?? "", "email": email, "name": u["name"] as? String ?? "", "verified": u["verified"] as? Bool ?? false, "has_email": !email.hasSuffix("@u.honeybun.invalid"),
                "has_password": u["pwKnown"] as? Bool ?? true, "apple": (u["appleSub"] as? String) != nil,
                "mail": ["bills": u["mail_bills"] as? Bool ?? true, "streak": u["mail_streak"] as? Bool ?? true, "weekly": u["mail_weekly"] as? Bool ?? true]]
    }
    /// the snapshot the app reads once a budget exists (built from the preview fixture for this user)
    private static func startBudget(_ i: Int, kind: String, name: String) {
        var s = HBPreviewVariants.make(kind == "couple" ? "partner" : "solo")
        let uid = users[i]["id"] as? String ?? ""
        let old = (s["me"] as? [String: Any])?["id"] as? String ?? ""
        s["me"] = ["id": uid, "email": users[i]["email"] as? String ?? "", "name": users[i]["name"] as? String ?? ""]
        s["members"] = (s["members"] as? [[String: Any]] ?? []).map { var m = $0; if (m["id"] as? String) == old { m["id"] = uid; m["name"] = users[i]["name"] as? String ?? "" }; return m }
        var nest = s["nest"] as? [String: Any] ?? [:]; nest["name"] = name; nest["kind"] = kind; s["nest"] = nest
        s["setup_done"] = false
        state = s
        users[i]["nestID"] = nest["id"] as? String ?? "nest"
        users[i]["setupDone"] = false
    }

    private static func handleAuth(_ method: String, _ path: String, _ body: [String: Any], _ request: URLRequest) -> (Int, Any, String?)? {
        lock.lock(); defer { lock.unlock() }
        func err(_ m: String, _ code: Int = 400) -> (Int, Any, String?) { (code, ["error": m], nil) }
        func ok(_ extra: [String: Any] = [:], _ code: Int = 200, cookie: String? = nil) -> (Int, Any, String?) { var d: [String: Any] = ["ok": true]; for (k, v) in extra { d[k] = v }; return (code, d, cookie) }
        func clean(_ v: Any?, _ n: Int) -> String { String(((v as? String) ?? "").trimmingCharacters(in: .whitespaces).prefix(n)) }
        func pwOK(_ v: Any?) -> String? { guard let p = v as? String, p.count >= 8, p.count <= 200 else { return nil }; return p }
        let pwMsg = "Use a password with at least 8 characters."

        // ----- public -----
        if path == "/api/auth/config" && method == "GET" { return (200, ["apple": true], nil) }
        if path == "/api/signup" && method == "POST" {
            let name = clean(body["name"], 24)
            if name.isEmpty { return err("Enter your name.") }
            let username = ((body["username"] as? String) ?? "").trimmingCharacters(in: .whitespaces).lowercased()
            var email: String
            if !username.isEmpty {
                if username.range(of: "^[a-z0-9][a-z0-9._-]{2,19}$", options: .regularExpression) == nil { return err("Usernames are 3 to 20 letters, numbers, dots, dashes or underscores.") }
                email = username + "@u.honeybun.invalid"
            } else {
                email = clean(body["email"], 254).lowercased()
                if email.range(of: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", options: .regularExpression) == nil { return err("Enter a valid email address.") }
            }
            let passkey = (body["passkey"] as? Bool) ?? false
            if !passkey && pwOK(body["password"]) == nil { return err(pwMsg) }
            if userIndex(key: email) != nil { return err(username.isEmpty ? "An account with that email already exists. Log in instead." : "That username is taken. Try another one.", 409) }
            let id = UUID().uuidString.lowercased(), code = username.isEmpty ? nil : randomCode()
            users.append(["id": id, "name": name, "email": email, "pw": passkey ? UUID().uuidString : (body["password"] as? String ?? ""), "pwKnown": !passkey, "recovery": code as Any, "verified": false, "nestID": NSNull(), "setupDone": false])
            var extra: [String: Any] = [:]; if let c = code { extra["recovery_code"] = c }
            return ok(extra, 201, cookie: newSession(id))
        }
        if path == "/api/login" && method == "POST" {
            let key = loginKey(clean(body["email"], 254))
            guard let i = userIndex(key: key), (users[i]["pw"] as? String) == (body["password"] as? String), (users[i]["pwKnown"] as? Bool ?? true) else { return err("Wrong email, username or password.", 401) }
            return ok([:], 200, cookie: newSession(users[i]["id"] as? String ?? ""))
        }
        if path == "/api/logout" && method == "POST" {
            if let c = (HTTPCookieStorage.shared.cookies(for: URL(string: "https://honeybun.me")!) ?? []).first(where: { $0.name == sessionCookieName }) { sessions[c.value] = nil }
            return ok([:], 200, cookie: "\(sessionCookieName)=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0")
        }
        if path == "/api/auth/apple" && method == "POST" {
            // stand-in token: "mock.<sub>.<sha256hex of the raw nonce>"; the real backend verifies Apple's signature (see auth-contract.mjs)
            let parts = (body["identity_token"] as? String ?? "").split(separator: ".").map(String.init)
            guard parts.count == 3, parts[0] == "mock", let raw = body["nonce"] as? String, parts[2] == HBAppleNonce.sha256Hex(raw) else { return err("Apple sign-in failed. Try again.", 401) }
            if let i = users.firstIndex(where: { ($0["appleSub"] as? String) == parts[1] }) { return ok(["created": false], 200, cookie: newSession(users[i]["id"] as? String ?? "")) }
            let id = UUID().uuidString.lowercased()
            users.append(["id": id, "name": clean(body["name"], 24).isEmpty ? "Friend" : clean(body["name"], 24), "email": "a_\(parts[1])@u.honeybun.invalid", "pw": UUID().uuidString, "pwKnown": false, "appleSub": parts[1], "verified": false, "nestID": NSNull(), "setupDone": false])
            return ok(["created": true], 201, cookie: newSession(id))
        }
        if path == "/api/password/forgot" && method == "POST" {
            let e = clean(body["email"], 254).lowercased()
            if e.range(of: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", options: .regularExpression) == nil { return err("Enter a valid email address.") }
            return ok()
        }
        if path == "/api/password/reset" && method == "POST" {
            guard pwOK(body["password"]) != nil else { return err(pwMsg) }
            guard (body["token"] as? String) == "valid-reset-token", let i = users.firstIndex(where: { !(($0["email"] as? String) ?? "").hasSuffix("@u.honeybun.invalid") }) else { return err("This reset link has expired or was already used. Ask for a new one.") }
            users[i]["pw"] = body["password"] as? String ?? ""; users[i]["pwKnown"] = true
            return ok([:], 200, cookie: newSession(users[i]["id"] as? String ?? ""))
        }
        if path == "/api/password/recover" && method == "POST" {
            guard pwOK(body["password"]) != nil else { return err(pwMsg) }
            let key = loginKey(clean(body["username"], 254))
            let code = ((body["code"] as? String) ?? "").uppercased().filter { $0.isLetter || $0.isNumber }
            guard let i = userIndex(key: key), let rc = users[i]["recovery"] as? String, rc.filter({ $0.isLetter || $0.isNumber }) == code else { return err("That username and recovery code don't match.", 401) }
            let new = randomCode(); users[i]["recovery"] = new; users[i]["pw"] = body["password"] as? String ?? ""; users[i]["pwKnown"] = true
            let uid = users[i]["id"] as? String ?? ""; sessions = sessions.filter { $0.value != uid }
            return ok(["recovery_code": new], 200, cookie: newSession(uid))
        }
        if path == "/api/email/verify" && method == "POST" {
            guard (body["token"] as? String) == "valid-verify-token" else { return err("This link has expired or was already used. You can send a new one from Settings.") }
            for i in users.indices { users[i]["verified"] = true }
            return ok()
        }
        if path == "/api/passkeys/login/options" && method == "POST" { return (200, ["challenge": "Y2hhbGxlbmdlLTEyMw", "rpId": "honeybun.me", "timeout": 120000], nil) }
        if path == "/api/passkeys/login" && method == "POST" {
            guard let id = body["id"] as? String, let pk = passkeyStore.first(where: { ($0["id"] as? String) == id }), body["signature"] is String else { return err("That passkey isn't registered here. Log in with your password and add it in Settings.", 404) }
            return ok([:], 200, cookie: newSession(pk["user"] as? String ?? ""))
        }

        // ----- everything below needs the session cookie -----
        guard let u = currentUserIndex() else { return path.hasPrefix("/api/") ? err("Please log in.", 401) : nil }
        let uid = users[u]["id"] as? String ?? ""
        if path == "/api/me" && method == "GET" { return (200, ["user": me(users[u]), "nest_id": users[u]["nestID"] ?? NSNull()], nil) }
        if path == "/api/me" && method == "PATCH" && body.keys.contains(where: { $0.hasPrefix("mail_") }) {
            for k in ["mail_bills", "mail_streak", "mail_weekly"] { if let v = body[k] as? Bool { users[u][k] = v } }
            return ok(["ok": true])
        }
        // push notification tokens (the phone registers / removes itself), and the test button
        if path == "/api/push/apns" && method == "POST" { if let t = body["token"] as? String, !t.isEmpty { apnsTokens.insert(uid + ":" + t) }; return ok(["ok": true]) }
        if path == "/api/push/apns" && method == "DELETE" { if let t = body["token"] as? String { apnsTokens.remove(uid + ":" + t) }; return ok(["ok": true]) }
        if path == "/api/push/test" && method == "POST" {
            let has = apnsTokens.contains { $0.hasPrefix(uid + ":") }
            return ok(has ? ["ok": true, "message": "Sent!"] : ["ok": false, "step": "phone", "message": "No phone has signed up for notifications yet. Allow notifications for Honeybun in your iPhone Settings, then reopen the app."])
        }
        if path == "/api/nests" && method == "POST" {
            if !(users[u]["nestID"] is NSNull) { return err("You're already in a budget.", 409) }
            let kind = ["solo", "couple", "family"].contains(body["kind"] as? String ?? "") ? (body["kind"] as? String ?? "couple") : "couple"
            startBudget(u, kind: kind, name: clean(body["name"], 24)); return ok(["nest_id": users[u]["nestID"] ?? ""], 201)
        }
        if path == "/api/nests/join" && method == "POST" {
            let code = ((body["code"] as? String) ?? "").uppercased().filter { $0.isLetter || $0.isNumber }
            guard code == "HONEY123" else { return err("That invite code doesn't match any budget. Check it and try again.", 404) }
            startBudget(u, kind: "couple", name: "Our Hive"); users[u]["setupDone"] = true; state["setup_done"] = true
            return ok(["nest_id": users[u]["nestID"] ?? ""])
        }
        if path == "/api/setup/done" && method == "POST" { users[u]["setupDone"] = true; state["setup_done"] = true; return ok() }
        if path == "/api/email/resend" && method == "POST" { return ok() }
        if path == "/api/recovery/new" && method == "POST" {
            if !((users[u]["email"] as? String) ?? "").hasSuffix("@u.honeybun.invalid") { return err("Accounts with an email reset their password by email.") }
            let c = randomCode(); users[u]["recovery"] = c; return ok(["recovery_code": c])
        }
        if path == "/api/password/change" && method == "POST" {
            guard (users[u]["pw"] as? String) == (body["current"] as? String) else { return err("Your current password is wrong.") }
            guard pwOK(body["password"]) != nil else { return err(pwMsg) }
            users[u]["pw"] = body["password"] as? String ?? ""; return ok()
        }
        if path == "/api/passkeys" && method == "GET" { return (200, ["passkeys": passkeyStore.filter { ($0["user"] as? String) == uid }.map { ["id": $0["id"] ?? "", "name": $0["name"] ?? "", "created_at": $0["created"] ?? 0, "last_used": NSNull()] }], nil) }
        if path == "/api/passkeys/options" && method == "POST" {
            return (200, ["challenge": "cmVnLWNoYWxsZW5nZQ", "rp": ["id": "honeybun.me", "name": "Honeybun"], "user": ["id": HBBase64URL.encode(Data(uid.utf8)), "name": users[u]["email"] ?? "", "displayName": users[u]["name"] ?? ""]], nil)
        }
        if path == "/api/passkeys" && method == "POST" {
            guard let id = body["id"] as? String, body["publicKey"] is String, (body["alg"] as? Int) == -7, body["authenticatorData"] is String else { return err("Your browser didn't return a usable passkey. Try a newer browser.") }
            if passkeyStore.contains(where: { ($0["id"] as? String) == id }) { return err("That passkey is already registered.", 409) }
            passkeyStore.append(["id": id, "user": uid, "name": (body["name"] as? String) ?? "Passkey", "created": Date().timeIntervalSince1970]); return ok([:], 201)
        }
        if path.hasPrefix("/api/passkeys/") {
            let id = String(path.dropFirst("/api/passkeys/".count)).removingPercentEncoding ?? ""
            guard let i = passkeyStore.firstIndex(where: { ($0["id"] as? String) == id && ($0["user"] as? String) == uid }) else { return ok() }
            if method == "DELETE" { passkeyStore.remove(at: i); return ok() }
            if method == "PATCH" { passkeyStore[i]["name"] = (body["name"] as? String) ?? "Passkey"; return ok() }
        }
        if path == "/api/account/export" && method == "GET" { return (200, ["exported_at": "now", "account": ["id": uid, "name": users[u]["name"] ?? ""]], nil) }
        if path == "/api/account/delete" && method == "POST" {
            if (users[u]["pwKnown"] as? Bool ?? true) == false {
                if (body["confirm"] as? String) != "DELETE" { return err("Type DELETE to confirm.") }
            } else if (body["password"] as? String) != (users[u]["pw"] as? String) { return err("That password is wrong.") }
            users.remove(at: u); sessions = sessions.filter { $0.value != uid }
            return ok([:], 200, cookie: "\(sessionCookieName)=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0")
        }
        return nil   // everything else (nest, goals, shopping, inbox…) is answered by the handlers above
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
