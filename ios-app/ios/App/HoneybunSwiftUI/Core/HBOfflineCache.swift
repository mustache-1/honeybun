import Foundation

// The last good answers from /api/me and /api/nest?month=…, kept so the app can open and show your last known numbers with no connection
// (the website does the same with localStorage "hb-cache:<path>"). It is tied to the account that was signed in, and wiped on logout.
final class HBOfflineCache {
    static let shared = HBOfflineCache(fileURL: HBOfflineCache.defaultURL())
    private struct Box: Codable { var owner: String; var items: [String: Data] }
    private let url: URL
    private let lock = NSLock()
    init(fileURL: URL) { url = fileURL }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Honeybun", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("last-known.json")
    }

    private func read() -> Box? { (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Box.self, from: $0) } }
    /// `owner` is the signed-in account's id; answers saved for another account are dropped first
    func save(_ path: String, _ data: Data, owner: String) {
        lock.lock(); defer { lock.unlock() }
        var box = read() ?? Box(owner: owner, items: [:])
        if box.owner != owner { box = Box(owner: owner, items: [:]) }
        box.items[path] = data
        if let out = try? JSONEncoder().encode(box) { try? out.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }
    func load(_ path: String) -> Data? { lock.lock(); defer { lock.unlock() }; return read()?.items[path] }
    var owner: String? { lock.lock(); defer { lock.unlock() }; return read()?.owner }
    func clear() { lock.lock(); defer { lock.unlock() }; try? FileManager.default.removeItem(at: url) }
}
