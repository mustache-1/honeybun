import SwiftUI

// "Join with a code" for someone who already has a budget (Classic's Settings → switch). The backend only allows it when you are the only member
// of yours, and it REPLACES it: the old budget and everything in it is deleted. So it asks twice, and says so.
@available(iOS 15.0, *)
struct HBJoinOtherBudgetSheet: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var error: String?
    @State private var busy = false
    @State private var confirm = false

    var body: some View {
        HBSheetScaffold(title: "Join with a code", onBack: { dismiss() }) {
            VStack(alignment: .leading, spacing: 8) {
                Label("This replaces your current budget", systemImage: "exclamationmark.triangle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(HB.red)
                Text("You're the only one in your budget, so joining will replace it. Everything in your current budget (entries, goals, bills, debts and more) will be deleted. Your account stays.")
                    .font(.system(size: 14)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)).fixedSize(horizontal: false, vertical: true)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
            HBAuthField(label: "Invite code", placeholder: "ABCD-EFGH", text: $code, id: "hb-switch-code")
            if let e = error { Text(e).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
            HBPillButton(title: busy ? "Joining…" : "Join budget") { confirm = true }.disabled(busy || HBAuthText.inviteCode(code).isEmpty).accessibilityIdentifier("hb-switch-join")
        }
        .confirmationDialog("Replace your budget?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Delete my budget and join", role: .destructive) { join() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Your current budget and everything in it will be deleted. This can't be undone.") }
    }
    private func join() {
        busy = true; error = nil
        Task {
            do { try await store.joinAnotherBudget(code: HBAuthText.inviteCode(code)); dismiss() } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
