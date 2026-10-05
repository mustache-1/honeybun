import Foundation

// Entries made while there is no connection. They are written to a file on this iPhone the moment they are made (so a force-quit or restart
// loses nothing), tagged with the account AND the budget they belong to, and sent only for that same account and budget. Each carries a random
// `client_id` the server uses to make a retry harmless (POST /api/entries answers "duplicate" instead of adding it twice).
//
// Stricter than the website's queue (localStorage "hb-queue"): that one is shared by whoever signs in next and silently drops entries the server
// answers with a 4xx. Here nothing is ever deleted except by the sync succeeding or by the person choosing to discard it.

struct HBPendingEntry: Codable, Identifiable, Equatable {
    let clientID: String
    let userID: String
    let nestID: String
    var draft: HBEntryDraft
    let createdAt: Double
    var failure: String? = nil        // the server refused it (not a connection problem): kept, shown, and retried only when asked
    var attempts: Int = 0
    var id: String { clientID }

    /// the entry as it shows in lists and totals until it has synced
    var asEntry: HBEntry {
        let d = draft
        var splitV: Int? = nil
        if let v = d.splitValue { splitV = d.splitMode == "owed" ? Int((v * 100).rounded()) : Int(v.rounded()) }
        return HBEntry(id: clientID, member_id: d.memberID, type: d.type, amount_cents: Int((d.amount * 100).rounded()), label: d.label,
                       category: d.type == "expense" ? d.category : nil, shared: d.shared ? 1 : 0, split_mode: d.shared ? d.splitMode : nil,
                       split_value: d.shared ? splitV : nil, isPrivate: d.isPrivate ? 1 : 0, date: d.date, recurring_id: nil, occ_date: nil, pending: true)
    }
}

enum HBSendOutcome: Equatable { case retryLater, rejected(String) }

enum HBPendingRules {
    /// a connection problem, a timeout, a busy/failing server or an expired sign-in are all "try again later"; any other 4xx is the server refusing this entry
    static func classify(_ error: Error) -> HBSendOutcome {
        if error is URLError { return .retryLater }
        if let e = error as? HBAPIError {
            switch e {
            case .notSignedIn: return .retryLater
            case let .http(code, msg): return (code == 408 || code == 429 || code >= 500) ? .retryLater : .rejected(msg)
            case .badURL, .decoding: return .retryLater
            }
        }
        return .retryLater
    }
    /// should adding this entry just now be saved on the phone instead of reported as an error?
    static func shouldQueue(_ error: Error) -> Bool { classify(error) == .retryLater }
}

struct HBFlushResult: Equatable {
    var sent = 0, rejected = 0
    var stoppedOffline = false
}

actor HBPendingQueue {
    static let shared = HBPendingQueue(fileURL: HBPendingQueue.defaultURL())
    private let url: URL
    private var items: [HBPendingEntry] = []
    private var loaded = false
    private var flushing = false

    init(fileURL: URL) { url = fileURL }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Honeybun", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pending-entries.json")
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: url) else { return }
        if let list = try? JSONDecoder().decode([HBPendingEntry].self, from: data) { items = list; return }
        // unreadable file: keep it aside (never delete someone's pending entries) and start a new one
        try? FileManager.default.moveItem(at: url, to: url.deletingLastPathComponent().appendingPathComponent("pending-entries.unreadable-\(Int(Date().timeIntervalSince1970)).json"))
    }
    private func save() throws {
        let data = try JSONEncoder().encode(items)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func all() -> [HBPendingEntry] { load(); return items }
    func items(user: String, nest: String) -> [HBPendingEntry] { load(); return items.filter { $0.userID == user && $0.nestID == nest } }
    func count(user: String) -> Int { load(); return items.filter { $0.userID == user }.count }

    /// Throws if it could not be written to disk, so the caller never tells someone an entry is safe when it is not.
    @discardableResult
    func add(_ draft: HBEntryDraft, user: String, nest: String, clientID: String = UUID().uuidString.lowercased(), now: Date = Date()) throws -> HBPendingEntry {
        load()
        if let have = items.first(where: { $0.clientID == clientID }) { return have }
        let item = HBPendingEntry(clientID: clientID, userID: user, nestID: nest, draft: draft, createdAt: now.timeIntervalSince1970)
        items.append(item)
        do { try save() } catch { items.removeAll { $0.clientID == clientID }; throw error }
        return item
    }
    func remove(_ clientID: String) { load(); items.removeAll { $0.clientID == clientID }; try? save() }
    /// a person's own choice: discard everything this account has waiting
    func removeAll(user: String) { load(); items.removeAll { $0.userID == user }; try? save() }
    func clearFailure(_ clientID: String) {
        load()
        if let i = items.firstIndex(where: { $0.clientID == clientID }) { items[i].failure = nil; try? save() }
    }
    func clearFailures(user: String, nest: String) {
        load()
        for i in items.indices where items[i].userID == user && items[i].nestID == nest { items[i].failure = nil }
        try? save()
    }
    func editDraft(_ clientID: String, _ draft: HBEntryDraft) {
        load()
        if let i = items.firstIndex(where: { $0.clientID == clientID }) { items[i].draft = draft; items[i].failure = nil; try? save() }
    }

    /// Send what is waiting for THIS account and budget, oldest first. A connection problem stops the run (the rest stays queued, in order);
    /// the server refusing one entry marks only that one (kept, with the reason) and the run goes on. Only one run happens at a time.
    func flush(user: String, nest: String, send: (HBPendingEntry) async throws -> Void) async -> HBFlushResult {
        load()
        var result = HBFlushResult()
        if flushing { return result }
        flushing = true; defer { flushing = false }
        let todo = items.filter { $0.userID == user && $0.nestID == nest && $0.failure == nil }.sorted { $0.createdAt < $1.createdAt }
        for item in todo {
            do {
                try await send(item)
                items.removeAll { $0.clientID == item.clientID }; try? save()
                result.sent += 1
            } catch {
                switch HBPendingRules.classify(error) {
                case .retryLater:
                    if let i = items.firstIndex(where: { $0.clientID == item.clientID }) { items[i].attempts += 1; try? save() }
                    result.stoppedOffline = true
                    return result
                case let .rejected(msg):
                    if let i = items.firstIndex(where: { $0.clientID == item.clientID }) { items[i].failure = msg; items[i].attempts += 1; try? save() }
                    result.rejected += 1
                }
            }
        }
        return result
    }
}
