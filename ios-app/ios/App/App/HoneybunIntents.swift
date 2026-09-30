import AppIntents

// Siri and Shortcuts: "Hey Siri, log an expense in Honeybun" and "Hey Siri, how much is left in Honeybun?"
// They use the phone's own token (set when you open Honeybun on this phone), so no sign-in is needed.
@available(iOS 16.0, *)
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log an expense"
    static var description = IntentDescription("Add something you spent to your Honeybun budget.")

    @Parameter(title: "Amount", requestValueDialog: "How much was it?")
    var amount: Double

    @Parameter(title: "Where", requestValueDialog: "Where did you spend it?")
    var store: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) at \(\.$store)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let message = try await HoneybunAPI.logExpense(amount: amount, store: store)
            return .result(dialog: IntentDialog(stringLiteral: message))
        } catch HoneybunError.notSignedIn {
            return .result(dialog: "Open Honeybun on this iPhone once and sign in, then try again.")
        } catch HoneybunError.server(let msg) {
            return .result(dialog: IntentDialog(stringLiteral: msg))
        } catch {
            return .result(dialog: "I couldn't reach Honeybun. Check your connection and try again.")
        }
    }
}

@available(iOS 16.0, *)
struct LeftThisMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "How much is left"
    static var description = IntentDescription("Hear what's left in your Honeybun budget this month.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let s = try await HoneybunAPI.summary()
            var line = "You have \(s.left.dollars) left this month."
            if let n = s.next { line += " Next up: \(n.label), \(n.amount.dollars)." }
            return .result(dialog: IntentDialog(stringLiteral: line))
        } catch HoneybunError.notSignedIn {
            return .result(dialog: "Open Honeybun on this iPhone once and sign in, then try again.")
        } catch {
            return .result(dialog: "I couldn't reach Honeybun. Check your connection and try again.")
        }
    }
}

@available(iOS 16.0, *)
struct HoneybunShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: ["Log an expense in \(.applicationName)", "Add an expense to \(.applicationName)", "Tell \(.applicationName) I spent money"],
            shortTitle: "Log an expense",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: LeftThisMonthIntent(),
            phrases: ["How much is left in \(.applicationName)", "What's left in \(.applicationName)", "Check my \(.applicationName) budget"],
            shortTitle: "How much is left",
            systemImageName: "pawprint.fill"
        )
    }
}
