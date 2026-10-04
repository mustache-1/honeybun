import SwiftUI
import UIKit

// Halloween Honeybun, native loading screen: the supplied splash artwork (HBSplash in the asset catalog: moon, stars, ghost, fence, Bun in the
// honey pot, pumpkins, candle, leaves) fills the whole display, with the real "honeybun" wordmark, "Loading your hive..." and a progress bar
// drawn on top by SwiftUI. It is shown while the app starts and while the native screens load your account (see HBRootView).
// It only ever appears when "Halloween Honeybun" is on in Settings (the classic app), or for the native screens. It never delays the app:
// the website tells the app the moment it has its first real screen and this view fades out right then.

/// The one stored switch for Halloween Honeybun inside the iPhone app. The website reads the same value (injected as window.__hbHH),
/// so there is no second copy that could disagree.
enum HalloweenPref {
    static let key = "halloweenHoneybunEnabled"
    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

struct HalloweenLoadingView: View {
    var reduceMotion: Bool = UIAccessibility.isReduceMotionEnabled
    @State private var sweep = false

    // where the wordmark, loading line and bar sit, as a share of the screen height (they sit in the empty ground area of the artwork)
    private let wordmarkY: CGFloat = 0.722, loadingY: CGFloat = 0.797, barY: CGFloat = 0.862

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Color(red: 0.10, green: 0.05, blue: 0.13)
                // aspect-fill: the artwork keeps its proportions and covers the whole screen, under the Dynamic Island and home indicator
                Image("HBSplash")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: w, height: h)
                    .clipped()
                    .accessibilityHidden(true)

                Text("honeybun")
                    .font(wordmarkFont(size: min(w * 0.19, 84)))
                    .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.40))
                    .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.2).opacity(0.55), radius: 14)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.horizontal, 28)
                    .position(x: w / 2, y: h * wordmarkY)
                    .accessibilityAddTraits(.isHeader)

                Text("Loading your hive...")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.80, green: 0.74, blue: 0.92))
                    .position(x: w / 2, y: h * loadingY)

                progressBar(width: w * 0.70)
                    .position(x: w / 2, y: h * barY)
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { sweep = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Honeybun is loading")
    }

    // The Fredoka SemiBold wordmark (registered from the asset catalog at launch); the system rounded font is the fallback.
    private func wordmarkFont(size: CGFloat) -> Font {
        HBFonts.register()
        if UIFont(name: HBFonts.wordmarkName, size: size) != nil { return Font.custom(HBFonts.wordmarkName, size: size) }
        return Font.system(size: size, weight: .bold, design: .rounded)
    }

    private func progressBar(width: CGFloat) -> some View {
        let fillShare: CGFloat = reduceMotion ? 0.55 : (sweep ? 0.92 : 0.18)
        return ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.10))
            Capsule()
                .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.70, blue: 0.30), Color(red: 1.0, green: 0.55, blue: 0.45), Color(red: 0.72, green: 0.52, blue: 0.95)], startPoint: .leading, endPoint: .trailing))
                .frame(width: max(14, width * fillShare))
        }
        .frame(width: width, height: 14)
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}

#if DEBUG
#Preview("Halloween loading") { HalloweenLoadingView() }
#Preview("Halloween loading, Reduce Motion") { HalloweenLoadingView(reduceMotion: true) }
#endif
