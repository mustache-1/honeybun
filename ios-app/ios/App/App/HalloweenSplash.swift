import SwiftUI
import UIKit

// Halloween Honeybun, native loading screen. It plays the supplied witch Bun frames (HoneybunWitch01...12 in the asset catalog)
// in order: the pot, Bun rising, settling, a wink, a heart, then sinking back down for a seamless loop.
// It only ever appears when "Halloween Honeybun" is on in Settings. It never delays the app: the website tells the app the moment
// it has its first real screen and this view fades out right then.

/// The one stored switch for Halloween Honeybun inside the iPhone app. The website reads the same value (injected as window.__hbHH),
/// so there is no second copy that could disagree.
enum HalloweenPref {
    static let key = "halloweenHoneybunEnabled"
    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

/// The animation frames, decoded once up front so playback never hitches.
final class HalloweenFrames {
    static let shared = HalloweenFrames()
    let images: [UIImage]
    /// How long each frame stays on screen, in seconds (about 1.7 s per loop, roughly 12 frames per second on average).
    let durations: [Double] = [0.22, 0.09, 0.09, 0.09, 0.09, 0.12, 0.14, 0.16, 0.16, 0.22, 0.10, 0.10]

    private init() {
        images = (1...12).compactMap { i -> UIImage? in
            guard let img = UIImage(named: String(format: "HoneybunWitch%02d", i)) else { return nil }
            // draw once now so the image is already decoded when the animation starts
            UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
            img.draw(at: .zero)
            let decoded = UIGraphicsGetImageFromCurrentImageContext() ?? img
            UIGraphicsEndImageContext()
            return decoded
        }
    }

    private var total: Double { durations.prefix(max(images.count, 1)).reduce(0, +) }

    func index(at time: TimeInterval) -> Int {
        guard images.count > 1 else { return 0 }
        var x = time.truncatingRemainder(dividingBy: total)
        for (i, d) in durations.prefix(images.count).enumerated() {
            if x < d { return i }
            x -= d
        }
        return 0
    }

    /// A calm frame for Reduce Motion: Bun up, winking.
    var stillIndex: Int { min(8, max(images.count - 1, 0)) }
}

struct HalloweenLoadingView: View {
    var reduceMotion: Bool = UIAccessibility.isReduceMotionEnabled
    private let frames = HalloweenFrames.shared

    var body: some View {
        ZStack {
            HalloweenSky(animated: !reduceMotion)
            VStack(spacing: 18) {
                Spacer()
                mascot
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text("honeybun")
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 1.0, green: 0.72, blue: 0.40))
                        .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.2).opacity(0.45), radius: 14)
                        .accessibilityAddTraits(.isHeader)
                    Text("Loading your hive...")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(Color(red: 0.78, green: 0.70, blue: 0.9))
                }
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Honeybun is loading")
    }

    @ViewBuilder
    private var mascot: some View {
        if frames.images.isEmpty {
            Text("🎃").font(.system(size: 90))
        } else if reduceMotion {
            frameView(frames.stillIndex)
        } else if #available(iOS 15.0, *) {
            TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { ctx in
                frameView(frames.index(at: ctx.date.timeIntervalSinceReferenceDate))
            }
        } else {
            frameView(frames.stillIndex)
        }
    }

    private func frameView(_ i: Int) -> some View {
        Image(uiImage: frames.images[min(i, frames.images.count - 1)])
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 170, height: 278)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color(red: 1.0, green: 0.67, blue: 0.31).opacity(0.5), lineWidth: 1))
            .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.2).opacity(0.35), radius: 26)
    }
}

/// Night sky: plum gradient, a moon, stars and a few small Halloween friends.
private struct HalloweenSky: View {
    var animated: Bool
    @State private var twinkle = false

    private let stars: [(x: CGFloat, y: CGFloat, s: CGFloat)] = (0..<46).map { i in
        let a = CGFloat((i * 7919) % 1000) / 1000, b = CGFloat((i * 104729) % 1000) / 1000
        return (a, b * 0.82, 1.2 + CGFloat((i * 13) % 3))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.16, green: 0.07, blue: 0.26), Color(red: 0.05, green: 0.02, blue: 0.09)], startPoint: .top, endPoint: .bottom)
                ForEach(0..<stars.count, id: \.self) { i in
                    Circle().fill(Color.white)
                        .frame(width: stars[i].s, height: stars[i].s)
                        .opacity(animated && twinkle && i % 3 == 0 ? 0.35 : 0.8)
                        .position(x: stars[i].x * geo.size.width, y: stars[i].y * geo.size.height)
                }
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1.0, green: 0.92, blue: 0.66), Color(red: 0.96, green: 0.72, blue: 0.29)], center: .init(x: 0.35, y: 0.3), startRadius: 2, endRadius: 46))
                    .frame(width: 76, height: 76)
                    .shadow(color: Color(red: 1.0, green: 0.8, blue: 0.35).opacity(0.5), radius: 34)
                    .position(x: geo.size.width - 64, y: geo.size.height * 0.12 + 28)
                Text("🎃").font(.system(size: 40)).opacity(0.9).position(x: 44, y: geo.size.height - 86)
                Text("👻").font(.system(size: 30)).opacity(0.75).position(x: geo.size.width - 48, y: geo.size.height - 120)
                Text("🕯️").font(.system(size: 26)).opacity(0.7).position(x: geo.size.width * 0.5 + 100, y: geo.size.height - 70)
            }
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { twinkle = true }
        }
    }
}

#if DEBUG
#Preview("Halloween loading") { HalloweenLoadingView() }
#Preview("Halloween loading, Reduce Motion") { HalloweenLoadingView(reduceMotion: true) }
#endif
