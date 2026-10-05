import Foundation

// Help (FAQ) and What's new: the website's own lists, generated into HBContent.swift (see scripts/gen-content.mjs).
struct HBHelpTopic: Decodable, Identifiable {
    let t: String; let d: String; let q: [[String]]
    var id: String { t }
    var faqs: [(question: String, answer: String)] { q.compactMap { $0.count == 2 ? (question: $0[0], answer: $0[1]) : nil } }
}
struct HBReleaseItem: Decodable { let t: String; let d: String; let tags: [String]; let icon: String? }
struct HBRelease: Decodable, Identifiable { let v: String; let date: String; let name: String; let items: [HBReleaseItem]; var id: String { v } }

enum HBHelp {
    static let topics: [HBHelpTopic] = (try? JSONDecoder().decode([HBHelpTopic].self, from: Data(HBContent.helpJSON.utf8))) ?? []
    static let releases: [HBRelease] = (try? JSONDecoder().decode([HBRelease].self, from: Data(HBContent.updatesJSON.utf8))) ?? []
    static let tagNames: [String: String] = (try? JSONDecoder().decode([String: String].self, from: Data(HBContent.tagsJSON.utf8))) ?? [:]

    /// the questions to show: only the chosen topic (if one is chosen), and only those whose question or answer contains the search words
    static func faqs(topic: Int?, query: String, in list: [HBHelpTopic] = topics) -> [(question: String, answer: String)] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        var out: [(question: String, answer: String)] = []
        for (i, t) in list.enumerated() {
            if let only = topic, only != i { continue }
            for f in t.faqs where q.isEmpty || (f.question + " " + f.answer).lowercased().contains(q) { out.append(f) }
        }
        return out
    }
}
