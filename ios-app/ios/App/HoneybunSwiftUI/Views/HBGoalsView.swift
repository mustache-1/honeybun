import SwiftUI

// MARK: - pieces

@available(iOS 15.0, *)
struct HBGoalIcon: View {
    let goal: HBGoal
    var size: CGFloat = 74
    var body: some View {
        let kind = HBGoalKind(name: goal.name, emoji: goal.emoji)
        HBGoalKindIcon(kind: kind, size: size)
    }
}

@available(iOS 15.0, *)
struct HBGoalKindIcon: View {
    let kind: HBGoalKind
    var size: CGFloat = 74
    var body: some View {
        // the illustrated Honeybun goal icons (HBGoalIcon_<kind> in the asset catalog, the same drawings the website uses)
        Image("HBGoalIcon_\(kind.rawValue)").resizable().scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: Color(rgb: kind.ink).opacity(0.30), radius: 10)
            .accessibilityHidden(true)
    }
}

@available(iOS 15.0, *)
struct HBGoalBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 12
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule().fill(LinearGradient(colors: [color, color.opacity(0.78)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: progress > 0 ? max(height, g.size.width * CGFloat(progress)) : 0)
            }
        }
        .frame(height: height)
    }
}

@available(iOS 15.0, *)
private func hbGoalColor(index: Int, done: Bool) -> Color {
    if done { return HB.orange }
    return index % 3 == 0 ? Color(red: 0.42, green: 0.90, blue: 0.62) : Color(red: 0.62, green: 0.50, blue: 0.98)
}

// MARK: - Goals tab

@available(iOS 15.0, *)
struct HBGoalsView: View {
    @ObservedObject var store: HBAppStore
    @ObservedObject private var metrics = HBLayoutMetrics.shared
    @State private var filter = "active"

    private var shown: [HBGoal] {
        switch filter {
        case "active": return store.goals.filter { !$0.isDone }
        case "done": return store.goals.filter { $0.isDone }
        default: return store.goals
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    filterBar
                    list
                    createCard
                    if let n = store.notice { Text(n).font(.footnote).foregroundColor(HB.red).onTapGesture { store.notice = nil } }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, HB.gutter).padding(.top, 8)
                .frame(maxWidth: .infinity)
                scene
                Color.clear.frame(height: max(1, metrics.trailing)).id("hb-end").background(HBProbe(kind: .scrollEnd))
            }
        }
        .refreshable { await store.refresh() }
        #if DEBUG
        .onAppear { if store.previewScrollToEnd { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { proxy.scrollTo("hb-end", anchor: .bottom) } } }
        #endif
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Goals").font(.system(size: 34, weight: .bold)).foregroundColor(.white)
                Text("Small steps. Big things together.").font(.system(size: 16)).foregroundColor(Color(red: 0.74, green: 0.69, blue: 0.9))
            }
            Spacer(minLength: 8)
            Button { store.selectedTab = .inbox } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell").font(.system(size: 18, weight: .medium)).foregroundColor(.white)
                        .frame(width: 44, height: 44).background(Circle().fill(Color.white.opacity(0.08))).overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    if store.unread > 0 { Circle().fill(Color(red: 1, green: 0.37, blue: 0.53)).frame(width: 10, height: 10).offset(x: -3, y: 3) }
                }
            }
            .accessibilityLabel("Messages from Bun")
        }
    }

    private var filterBar: some View {
        HStack(spacing: 0) {
            ForEach([("active", "Active"), ("done", "Completed"), ("all", "All")], id: \.0) { key, title in
                Button { filter = key } label: {
                    Text(title).font(.system(size: 16, weight: .semibold))
                        .foregroundColor(filter == key ? Color.black.opacity(0.82) : Color(red: 0.74, green: 0.69, blue: 0.9))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Capsule().fill(filter == key ? HB.orange : Color.clear).shadow(color: filter == key ? HB.orange.opacity(0.45) : .clear, radius: 8))
                }
                .accessibilityAddTraits(filter == key ? .isSelected : [])
                .accessibilityIdentifier("hb-filter-\(key)")
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var list: some View {
        VStack(spacing: 12) {
            if shown.isEmpty {
                Text(filter == "done" ? "No completed goals yet." : "No active goals yet.")
                    .font(.subheadline).foregroundColor(HB.soft).padding(18).frame(maxWidth: .infinity, alignment: .leading).hbCard()
            }
            ForEach(Array(shown.enumerated()), id: \.element.id) { i, g in
                Button { store.sheet = .goalDetail(g.id) } label: { row(g, index: i) }.buttonStyle(.plain).accessibilityIdentifier("hb-goal-row")
            }
        }
    }

    private func row(_ g: HBGoal, index: Int) -> some View {
        HStack(spacing: 14) {
            HBGoalIcon(goal: g)
            VStack(alignment: .leading, spacing: 6) {
                Text(g.name).font(.system(size: 19, weight: .bold)).foregroundColor(.white).lineLimit(1)
                Text("\(HBFormat.money(g.saved, cents: g.saved.truncatingRemainder(dividingBy: 1) != 0)) of \(HBFormat.money(g.target, cents: g.target.truncatingRemainder(dividingBy: 1) != 0))")
                    .font(.system(size: 17)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)).lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: 10) {
                    HBGoalBar(progress: g.progress, color: hbGoalColor(index: index, done: g.isDone))
                    Text("\(Int((g.progress * 100).rounded()))%").font(.system(size: 17, weight: .semibold).monospacedDigit()).foregroundColor(.white)
                        .frame(minWidth: 44, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .hbCard()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(g.name), \(HBFormat.money(g.saved)) of \(HBFormat.money(g.target)), \(Int((g.progress * 100).rounded())) percent")
    }

    private var createCard: some View {
        Button { store.sheet = .goalForm(nil) } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus").font(.system(size: 22, weight: .regular))
                Text("Create a new goal").font(.system(size: 18, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])))
        }
        .accessibilityIdentifier("hb-goal-create")
    }

    // the supplied "You can do it!" scene, full width at the end of the list
    private var scene: some View {
        Image("HBGoalsScene").resizable().scaledToFit().frame(maxWidth: .infinity)
            .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35)))
            .padding(.top, 8)
            .accessibilityElement(children: .ignore).accessibilityLabel("Bun cheering you on").accessibilityIdentifier("hb-last-card")
    }
}

// MARK: - Goal details

@available(iOS 15.0, *)
struct HBGoalDetail: View {
    @ObservedObject var store: HBAppStore
    let goalID: String
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var quick: Int? = nil
    @State private var error: String?
    @State private var working = false
    @State private var message: String?

    private static let dayFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f }()

    var body: some View {
        NavigationView {
            ZStack {
                HBBackground(glow: false, scene: false)
                if let g = store.goal(goalID) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            header
                            summary(g)
                            quickAmounts
                            amountField
                            if let error = error { Text(error).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
                            if let message = message { Text(message).font(.footnote.weight(.semibold)).foregroundColor(HB.green) }
                            addButton
                            if g.saved_cents > 0 { takeOutButton }
                            activity(g)
                        }
                        .frame(maxWidth: 560).padding(.horizontal, HB.gutter).padding(.top, 6).padding(.bottom, 28)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    HBMessageView(title: "That goal is gone", message: "It was deleted. Nothing else changed.", primary: ("Back", { dismiss() }))
                }
            }
            .navigationBarHidden(true)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { hbHideKeyboard() } } }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        ZStack {
            HStack {
                Button { dismiss() } label: { Image(systemName: "arrow.left").font(.system(size: 20, weight: .medium)).foregroundColor(.white).frame(width: 44, height: 44) }
                    .accessibilityLabel("Back")
                Spacer()
            }
            Text("Goal Details").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
        }
    }

    private func summary(_ g: HBGoal) -> some View {
        let pct = Int((g.progress * 100).rounded())
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                HBGoalIcon(goal: g, size: 68)
                VStack(alignment: .leading, spacing: 4) {
                    Text(g.name).font(.system(size: 22, weight: .bold)).foregroundColor(.white).lineLimit(2)
                    Text("\(HBFormat.money(g.saved)) of \(HBFormat.money(g.target))").font(.system(size: 17)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                HBGoalBar(progress: g.progress, color: g.isDone ? HB.orange : Color(red: 0.42, green: 0.90, blue: 0.62), height: 14)
                Text("\(pct)%").font(.system(size: 17, weight: .bold).monospacedDigit()).foregroundColor(.white).frame(minWidth: 46, alignment: .trailing)
            }
            if g.isDone { Text("You reached this goal!").font(.system(size: 15, weight: .semibold)).foregroundColor(HB.orange) }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LinearGradient(colors: [Color(red: 0.25, green: 0.16, blue: 0.14), Color(red: 0.13, green: 0.09, blue: 0.14)], startPoint: .topTrailing, endPoint: .bottomLeading)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(HB.orange.opacity(0.35), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            // the supplied form-peek-bun.png (381x267, purple witch hat), peeking over the top-right edge of the card
            Image("HBGoalsPeek").resizable().scaledToFit().frame(width: 124, height: 87).offset(x: -8, y: -73).allowsHitTesting(false).accessibilityHidden(true)
        }
        .padding(.top, 60)
    }

    private var quickAmounts: some View {
        HStack(spacing: 10) {
            ForEach([10, 25, 50, 100], id: \.self) { v in
                Button { quick = v; amountText = String(v); error = nil; message = nil; hbHideKeyboard() } label: {
                    Text("$\(v)").font(.system(size: 17, weight: .semibold))
                        .foregroundColor(quick == v ? Color.black.opacity(0.85) : .white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Capsule().fill(quick == v ? HB.orange : Color.white.opacity(0.07)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                }
                .accessibilityAddTraits(quick == v ? .isSelected : [])
                .accessibilityIdentifier("hb-quick-\(v)")
            }
        }
    }

    private var amountField: some View {
        TextField("Other amount", text: $amountText)
            .keyboardType(.decimalPad).font(.system(size: 18)).foregroundColor(.white)
            .padding(.horizontal, 16).frame(minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .onChange(of: amountText) { v in if quick.map({ String($0) }) != v { quick = nil } }
            .accessibilityIdentifier("hb-amount")
    }

    private var addButton: some View {
        Button { move(out: false) } label: {
            Text(working ? "Saving…" : "Add Funds").font(.system(size: 19, weight: .bold)).foregroundColor(Color.black.opacity(0.85))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(HB.orange)).shadow(color: HB.orange.opacity(0.4), radius: 12, y: 4)
        }
        .disabled(working)
        .accessibilityIdentifier("hb-add-funds")
    }

    private var takeOutButton: some View {
        Button { move(out: true) } label: {
            Text("Take out").font(.system(size: 17, weight: .semibold)).foregroundColor(HB.orange)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(Capsule().stroke(HB.orange.opacity(0.55), lineWidth: 1))
        }
        .disabled(working)
        .accessibilityIdentifier("hb-take-out")
    }

    private func activity(_ g: HBGoal) -> some View {
        let moves = Array(store.jarMoves(for: g.id).prefix(8))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Activity").font(.system(size: 21, weight: .bold)).foregroundColor(.white)
                Spacer()
                Button { store.sheet = .goalForm(g.id) } label: {
                    Text("Edit goal").font(.subheadline.weight(.semibold)).foregroundColor(Color(red: 0.72, green: 0.68, blue: 0.9))
                }
                .accessibilityIdentifier("hb-edit-goal")
            }
            .padding(.top, 6)
            VStack(spacing: 0) {
                if moves.isEmpty {
                    Text("No activity yet. Add the first bit to \(g.name).").font(.subheadline).foregroundColor(HB.soft).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(moves.enumerated()), id: \.element.id) { i, m in
                    if i > 0 { Divider().background(HB.line).padding(.leading, 62) }
                    moveRow(m)
                }
            }
            .hbCard()
        }
    }

    private func moveRow(_ m: HBJarMove) -> some View {
        let inn = m.amount_cents > 0
        let who = m.member_id == store.myID ? "You" : store.memberName(m.member_id)
        let member = store.members.first { $0.id == m.member_id }
        let tint = Color(hex: member?.color) ?? HB.orange
        return HStack(spacing: 12) {
            Text(String((who.first ?? "?")).uppercased()).font(.system(size: 16, weight: .bold)).foregroundColor(Color.black.opacity(0.75))
                .frame(width: 38, height: 38).background(Circle().fill(tint))
            VStack(alignment: .leading, spacing: 2) {
                Text(who).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Text(Self.dayFmt.string(from: m.date)).font(.system(size: 13)).foregroundColor(HB.soft)
            }
            Spacer(minLength: 8)
            Text((inn ? "+" : "−") + HBFormat.money(abs(m.amount))).font(.system(size: 16, weight: .semibold).monospacedDigit()).foregroundColor(inn ? HB.green : HB.red)
            Button { undo(m) } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(HB.soft).frame(width: 30, height: 30)
            }
            .accessibilityLabel("Remove this entry")
            .accessibilityIdentifier("hb-undo-move")
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    // MARK: actions

    private func move(out: Bool) {
        hbHideKeyboard(); error = nil; message = nil
        guard let amount = hbParseAmount(amountText) else { error = "Enter an amount more than $0."; return }
        let before = store.goal(goalID)
        working = true
        Task {
            do {
                try await store.moveJar(goalID: goalID, amount: amount, out: out)
                amountText = ""; quick = nil
                if !out, let b = before, !b.isDone, let a = store.goal(goalID), a.isDone { message = "You reached \(a.name)!" }
                else { message = out ? "Taken out." : "Added." }
            } catch { self.error = error.localizedDescription }
            working = false
        }
    }

    private func undo(_ m: HBJarMove) {
        error = nil; message = nil
        Task { do { try await store.deleteJarMove(id: m.id) } catch { self.error = error.localizedDescription } }
    }
}

// MARK: - New / edit goal

@available(iOS 15.0, *)
struct HBGoalForm: View {
    @ObservedObject var store: HBAppStore
    let goalID: String?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var targetText: String
    @State private var emoji: String
    @State private var error: String?
    @State private var saving = false
    @State private var confirmDelete = false

    init(store: HBAppStore, goalID: String?) {
        self.store = store; self.goalID = goalID
        let g = goalID.flatMap { store.goal($0) }
        _name = State(initialValue: g?.name ?? "")
        _targetText = State(initialValue: g.map { String(format: "%.2f", $0.target) } ?? "")
        _emoji = State(initialValue: HBGoalStyle.emojis.contains(g?.emoji ?? "") ? (g?.emoji ?? HBGoalStyle.emojis[0]) : HBGoalStyle.emojis[0])
    }

    private var editing: Bool { goalID != nil }
    private var backTarget: HBSheet? { goalID.map { .goalDetail($0) } }

    var body: some View {
        NavigationView {
            ZStack {
                HBBackground(glow: false, scene: false)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ZStack {
                            HStack {
                                Button { close() } label: { Image(systemName: "arrow.left").font(.system(size: 20, weight: .medium)).foregroundColor(.white).frame(width: 44, height: 44) }
                                    .accessibilityLabel("Back")
                                Spacer()
                            }
                            Text(editing ? "Edit goal" : "New goal").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                        }
                        HBField(title: "Name") {
                            TextField("Vacation Fund", text: $name).foregroundColor(.white).padding(14).hbCard().accessibilityIdentifier("hb-goal-name")
                                .onChange(of: name) { v in if v.count > 30 { name = String(v.prefix(30)) } }
                        }
                        HBField(title: "Target") {
                            HStack {
                                Text("$").font(.title2.weight(.bold)).foregroundColor(HB.soft)
                                TextField("1000", text: $targetText).keyboardType(.decimalPad).font(.system(size: 30, weight: .heavy).monospacedDigit()).foregroundColor(.white).accessibilityIdentifier("hb-goal-target")
                            }.padding(14).hbCard()
                        }
                        HBField(title: "Icon") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 5), spacing: 12) {
                                ForEach(HBGoalStyle.choices, id: \.emoji) { c in
                                    Button { emoji = c.emoji } label: {
                                        VStack(spacing: 5) {
                                            HBGoalKindIcon(kind: c.kind, size: 52)
                                                .overlay(Circle().stroke(HB.orange, lineWidth: emoji == c.emoji ? 3 : 0))
                                            Text(c.label).font(.system(size: 11, weight: .medium)).foregroundColor(emoji == c.emoji ? .white : HB.soft).lineLimit(1).minimumScaleFactor(0.7)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .accessibilityLabel(c.label)
                                    .accessibilityAddTraits(emoji == c.emoji ? .isSelected : [])
                                }
                            }
                        }
                        if let error = error { Text(error).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
                        Button(action: save) {
                            Text(saving ? "Saving…" : (editing ? "Save changes" : "Create goal")).font(.system(size: 19, weight: .bold)).foregroundColor(Color.black.opacity(0.85))
                                .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(HB.orange)).shadow(color: HB.orange.opacity(0.4), radius: 12, y: 4)
                        }
                        .disabled(saving)
                        .accessibilityIdentifier("hb-goal-save")
                        if editing {
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Text("Delete goal").font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 50)
                                    .overlay(Capsule().stroke(HB.red.opacity(0.6), lineWidth: 1))
                            }
                            .foregroundColor(HB.red).disabled(saving).accessibilityIdentifier("hb-goal-delete")
                        }
                    }
                    .frame(maxWidth: 560).padding(.horizontal, HB.gutter).padding(.top, 6).padding(.bottom, 28).frame(maxWidth: .infinity)
                }
            }
            .navigationBarHidden(true)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { hbHideKeyboard() } } }
            .confirmationDialog("Delete this goal?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { remove() }
                Button("Keep it", role: .cancel) {}
            } message: { Text("Its savings history goes too. The money you moved stays wherever you put it.") }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    // back goes to the goal's details when editing, or closes when creating
    private func close() { if let b = backTarget { store.sheet = b } else { dismiss() } }

    private func save() {
        hbHideKeyboard(); error = nil
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { error = "Name your goal."; return }
        guard let target = hbParseAmount(targetText) else { error = "Enter a target more than $0."; return }
        var d = HBGoalDraft(); d.name = n; d.target = target; d.emoji = emoji
        saving = true
        Task {
            do {
                if let id = goalID { try await store.updateGoal(id: id, d); store.sheet = .goalDetail(id) }
                else { try await store.addGoal(d); dismiss() }
            } catch { self.error = error.localizedDescription }
            saving = false
        }
    }

    private func remove() {
        guard let id = goalID else { return }
        saving = true
        Task {
            do { try await store.deleteGoal(id: id); dismiss() } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}
