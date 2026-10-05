import SwiftUI
import UIKit

// MARK: - Apple Pay auto-logging: a key for an iPhone Shortcut that sends each tap-to-pay to Honeybun (/api/shortcut/key, then POST /api/log)

@available(iOS 15.0, *)
struct HBShortcutView: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var newKey: String?
    @State private var copied = false
    @State private var error: String?
    @State private var busy = false
    @State private var confirmNew = false
    @State private var confirmOff = false

    private var info: HBShortcutInfo? { store.account?.shortcut }
    private static let dayFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d"; return f }()

    var body: some View {
        HBSheetScaffold(title: "Apple Pay auto-logging", onBack: { dismiss() }) {
            Text("Every time you tap to pay, your iPhone can send the amount and store to Honeybun. No bank connection needed.").font(.system(size: 15)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)).fixedSize(horizontal: false, vertical: true)
            if info == nil && newKey == nil { offCard } else { onCard }
            if let k = newKey { keyCard(k) }
            if info != nil || newKey != nil { stepsCard }
            if let e = error { Text(e).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
        }
        .confirmationDialog("Make a new key?", isPresented: $confirmNew, titleVisibility: .visible) {
            Button("New key", role: .destructive) { make() }; Button("Keep my key", role: .cancel) {}
        } message: { Text("Your old key stops working, so update the Shortcut with the new one.") }
        .confirmationDialog("Turn off auto-logging?", isPresented: $confirmOff, titleVisibility: .visible) {
            Button("Turn off", role: .destructive) { revoke() }; Button("Keep it on", role: .cancel) {}
        } message: { Text("Your Shortcut will stop working until you make a new key.") }
    }

    private var offCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Step 1 is making a key. It's like a password just for your Shortcut, so keep it to yourself.").font(.footnote).foregroundColor(HB.soft)
            HBPillButton(title: busy ? "Making…" : "Make my key", symbol: "key") { make() }.disabled(busy).accessibilityIdentifier("hb-shortcut-make")
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }
    private var onCard: some View {
        let used = info?.uses ?? 0
        let last = info?.last_used.map { " Last one " + Self.dayFmt.string(from: Date(timeIntervalSince1970: $0)) + "." } ?? ""
        return VStack(alignment: .leading, spacing: 10) {
            Label("Your Shortcut key is on", systemImage: "checkmark.seal.fill").font(.system(size: 16, weight: .bold)).foregroundColor(HB.green)
            Text(used > 0 ? "Logged \(used) \(used == 1 ? "purchase" : "purchases") so far.\(last)" : "Nothing logged yet. Finish the Shortcut below and tap to pay once to test it.").font(.footnote).foregroundColor(HB.soft)
            HStack(spacing: 10) {
                HBPillButton(title: "New key", symbol: "arrow.triangle.2.circlepath", filled: false) { confirmNew = true }.disabled(busy)
                Button { confirmOff = true } label: { Text("Turn off").font(.system(size: 16, weight: .semibold)).foregroundColor(HB.red).frame(maxWidth: .infinity, minHeight: 50).overlay(Capsule().stroke(HB.red.opacity(0.6), lineWidth: 1)) }.disabled(busy)
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }
    private func keyCard(_ k: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Copy this key now. For safety it's only shown once. If you lose it, make a new one.").font(.footnote.weight(.semibold)).foregroundColor(HB.orange)
            Text(k).font(.system(size: 14, design: .monospaced)).foregroundColor(.white).textSelection(.enabled).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06))).accessibilityIdentifier("hb-shortcut-key")
            HBPillButton(title: copied ? "Copied" : "Copy", symbol: copied ? "checkmark" : "doc.on.doc", filled: false) { UIPasteboard.general.string = k; copied = true }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }
    private var stepsCard: some View {
        let steps: [String] = [
            "Open the Shortcuts app, go to Automation, tap +, and pick Transaction. Choose your card, leave it on Run Immediately, and tap Next.",
            "Tap New Blank Automation and add the action Get Contents of URL.",
            "Set the URL to https://honeybun.me/api/log, Method to POST, and under Headers add Authorization with the value Bearer followed by a space and your key.",
            "Under Request Body (JSON) add amount → the Amount from the Transaction, and store → the Merchant.",
            "Optional: add a Show Notification action with the message from the result, so Bun confirms each log.",
        ]
        return VStack(alignment: .leading, spacing: 10) {
            Text("Set up the Shortcut (2 minutes)").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
            ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)").font(.system(size: 13, weight: .bold)).foregroundColor(.black.opacity(0.8)).frame(width: 24, height: 24).background(Circle().fill(HB.orange))
                    Text(s).font(.system(size: 14)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Honeybun picks the category from the store name and remembers how you split each store. You can edit anything after, like any other entry.").font(.footnote).foregroundColor(HB.soft)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private func make() {
        busy = true; error = nil
        Task {
            do {
                newKey = try await HBAPI.shared.makeShortcutKey(); copied = false
                if let me = try? await HBAPI.shared.me() { store.account = me.user }
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    private func revoke() {
        busy = true; error = nil
        Task {
            do { try await HBAPI.shared.revokeShortcutKey(); newKey = nil; if let me = try? await HBAPI.shared.me() { store.account = me.user } } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
