import WidgetKit
import SwiftUI

// Honeybun home-screen and lock-screen widgets: what's left this month and the next bill.
// The widget asks honeybun.me itself (with this phone's token), so it stays current without opening the app.

struct HoneybunEntry: TimelineEntry {
    let date: Date
    let summary: BudgetSummary?
    let signedIn: Bool
}

struct HoneybunProvider: TimelineProvider {
    func placeholder(in context: Context) -> HoneybunEntry { HoneybunEntry(date: Date(), summary: .sample, signedIn: true) }

    func getSnapshot(in context: Context, completion: @escaping (HoneybunEntry) -> Void) {
        completion(HoneybunEntry(date: Date(), summary: .sample, signedIn: true))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HoneybunEntry>) -> Void) {
        Task {
            var entry = HoneybunEntry(date: Date(), summary: nil, signedIn: Honeybun.token != nil)
            if Honeybun.token != nil {
                do { entry = HoneybunEntry(date: Date(), summary: try await HoneybunAPI.summary(), signedIn: true) }
                catch HoneybunError.notSignedIn { entry = HoneybunEntry(date: Date(), summary: nil, signedIn: false) }
                catch { /* offline: keep the last look below */ }
            }
            // ask again in 30 minutes (iOS decides the exact time)
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
        }
    }
}

private let cocoa = Color(red: 0.96, green: 0.60, blue: 0.29)
private let night = Color(red: 0.09, green: 0.06, blue: 0.11)

struct BackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) { LinearGradient(colors: [Color(red: 0.17, green: 0.11, blue: 0.23), night], startPoint: .top, endPoint: .bottom) }
        } else {
            content.background(LinearGradient(colors: [Color(red: 0.17, green: 0.11, blue: 0.23), night], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct HoneybunWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: HoneybunEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .systemMedium: medium
            default: small
            }
        }
        .modifier(BackgroundModifier())
    }

    private var signInHint: some View {
        VStack(spacing: 4) {
            Text("🐰").font(.title)
            Text("Open Honeybun to set up this widget").font(.caption).multilineTextAlignment(.center).foregroundColor(.white.opacity(0.8))
        }
    }

    private var small: some View {
        Group {
            if let s = entry.summary {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Left this month").font(.caption2).fontWeight(.bold).foregroundColor(.white.opacity(0.7))
                    Text(s.left.dollars).font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundColor(.white).minimumScaleFactor(0.6).lineLimit(1)
                    Spacer(minLength: 4)
                    if let n = s.next {
                        Text("Next: \(n.label)").font(.caption2).foregroundColor(cocoa).lineLimit(1)
                        Text(n.amount.dollars).font(.caption).fontWeight(.bold).foregroundColor(.white)
                    } else {
                        Text("No bills soon 🐾").font(.caption2).foregroundColor(.white.opacity(0.8))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else { signInHint }
        }
    }

    private var medium: some View {
        Group {
            if let s = entry.summary {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name).font(.caption).fontWeight(.bold).foregroundColor(.white.opacity(0.7)).lineLimit(1)
                        Text(s.left.dollars).font(.system(size: 36, weight: .heavy, design: .rounded)).foregroundColor(.white).minimumScaleFactor(0.6).lineLimit(1)
                        Text("left this month").font(.caption2).foregroundColor(.white.opacity(0.7))
                        ProgressView(value: min(max(s.income > 0 ? s.spent / s.income : 0, 0), 1)).tint(cocoa).padding(.top, 4)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        stat("Came in", s.income.dollars)
                        stat("Spent", s.spent.dollars)
                        if let n = s.next { stat("Next: \(n.label)", n.amount.dollars) }
                    }
                }
            } else { signInHint }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption2).foregroundColor(.white.opacity(0.65)).lineLimit(1)
            Text(value).font(.subheadline).fontWeight(.bold).foregroundColor(.white)
        }
    }

    private var circular: some View {
        Group {
            if let s = entry.summary {
                VStack(spacing: 0) {
                    Text("🐰").font(.caption)
                    Text(s.left.dollars).font(.caption).fontWeight(.bold).minimumScaleFactor(0.5).lineLimit(1)
                }
            } else { Text("🐰") }
        }
    }

    private var rectangular: some View {
        Group {
            if let s = entry.summary {
                VStack(alignment: .leading) {
                    Text("Honeybun").font(.caption2).fontWeight(.bold)
                    Text("\(s.left.dollars) left").font(.headline)
                    if let n = s.next { Text("\(n.label) \(n.amount.dollars)").font(.caption2).lineLimit(1) }
                }
            } else { Text("Open Honeybun to set up") }
        }
    }
}

@main
struct HoneybunWidget: Widget {
    let kind = "HoneybunWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HoneybunProvider()) { entry in
            HoneybunWidgetView(entry: entry)
        }
        .configurationDisplayName("Honeybun")
        .description("See what's left this month and your next bill.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
