import SwiftUI
import StoreKit

// MARK: - Support Honeybun 💛: the tip jar (three consumable in-app purchases made in App Store Connect). The same product IDs and the same StoreKit calls the Classic app's bridge uses.

@available(iOS 15.0, *)
struct HBTipsView: View {
    @Environment(\.dismiss) private var dismiss
    static let ids = ["me.honeybun.app.tip.small", "me.honeybun.app.tip.medium", "me.honeybun.app.tip.large"]
    @State private var products: [Product] = []
    @State private var loading = true
    @State private var message: String?
    @State private var busy = false
    @State private var thanks = false

    var body: some View {
        HBSheetScaffold(title: "Support Honeybun 💛", onBack: { dismiss() }) {
            Text("Honeybun is free and made by one person. A tip helps keep it going. Thank you!").font(.system(size: 15)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)).fixedSize(horizontal: false, vertical: true)
            if loading { ProgressView().tint(HB.orange).frame(maxWidth: .infinity).padding(30) }
            ForEach(products, id: \.id) { p in
                Button { buy(p) } label: {
                    HStack { Text(p.displayName).font(.system(size: 17, weight: .bold)); Spacer(); Text(p.displayPrice).font(.system(size: 17, weight: .semibold).monospacedDigit()) }
                        .foregroundColor(.white).padding(16).frame(maxWidth: .infinity).hbCard()
                }.disabled(busy).accessibilityIdentifier("hb-tip-" + p.id)
            }
            if let m = message { Text(m).font(.footnote.weight(.semibold)).foregroundColor(thanks ? HB.green : HB.red) }
        }
        .task { await load() }
    }
    private func load() async {
        do {
            let list = try await Product.products(for: Self.ids)
            products = list.sorted { $0.price < $1.price }
            if products.isEmpty { message = "Tips aren't available right now. Please try again later." }
        } catch { message = "Tips aren't available right now. Please try again later." }
        loading = false
    }
    private func buy(_ p: Product) {
        busy = true; message = nil; thanks = false
        Task {
            do {
                switch try await p.purchase() {
                case .success(let v):
                    if case .verified(let t) = v { await t.finish(); thanks = true; message = "Thank you so much! 💛" } else { message = "Apple couldn't verify the purchase." }
                case .pending: thanks = true; message = "Your tip is waiting for approval. Thank you!"
                case .userCancelled: break
                @unknown default: break
                }
            } catch { message = "Couldn't complete the tip." }
            busy = false
        }
    }
}
