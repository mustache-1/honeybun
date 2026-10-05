import SwiftUI

// The level bunny: the website's own drawing (bunnySvg / gearSvg in app.js, a 120 x 128 picture) redrawn with the same shapes and colours, wearing
// what the level unlocks (see HBBunnyGear). There is no bitmap for it in the asset catalog; Classic draws it in code too.
@available(iOS 15.0, *)
struct HBLevelBunny: View {
    let level: Int
    var width: CGFloat = 64
    private static let ink = Color(red: 0.078, green: 0.071, blue: 0.09)
    private static func hex(_ v: UInt32) -> Color { Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255) }

    var body: some View {
        Canvas { ctx, size in
            let k = size.width / 120
            func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * k, y: y * k) }
            let ink = Self.ink
            let line = StrokeStyle(lineWidth: 4 * k, lineCap: .round, lineJoin: .round)
            // ears
            var ear = Path(); ear.move(to: P(44, 52)); ear.addCurve(to: P(42, 6), control1: P(34, 30), control2: P(34, 8)); ear.addCurve(to: P(54, 46), control1: P(50, 4), control2: P(54, 28))
            var ear2 = Path(); ear2.move(to: P(76, 52)); ear2.addCurve(to: P(78, 6), control1: P(86, 30), control2: P(86, 8)); ear2.addCurve(to: P(66, 46), control1: P(70, 4), control2: P(66, 28))
            let body = Self.hex(0xF8F4F8)
            for e in [ear, ear2] { ctx.fill(e, with: .color(body)); ctx.stroke(e, with: .color(ink), style: line) }
            // body
            let torso = Path(ellipseIn: CGRect(x: 22 * k, y: 48 * k, width: 76 * k, height: 68 * k))
            ctx.fill(torso, with: .color(body)); ctx.stroke(torso, with: .color(ink), style: line)
            // face
            for x in [47.0, 73.0] { ctx.fill(Path(ellipseIn: CGRect(x: (x - 3.5) * k, y: 74.5 * k, width: 7 * k, height: 7 * k)), with: .color(ink)) }
            for x in [38.0, 82.0] { ctx.fill(Path(ellipseIn: CGRect(x: (x - 6) * k, y: 86.5 * k, width: 12 * k, height: 7 * k)), with: .color(Self.hex(0xF6B7CB))) }
            var mouth = Path(); mouth.move(to: P(52, 89)); mouth.addQuadCurve(to: P(68, 89), control: P(60, 97))
            ctx.stroke(mouth, with: .color(ink), style: StrokeStyle(lineWidth: 3 * k, lineCap: .round, lineJoin: .round))

            // what it wears
            let g = HBBunnyGear.forLevel(level)
            let gold = Self.hex(0xF6CF73), pink = Self.hex(0xEE7FA3), deep = Self.hex(0xD9668C)
            if g.goldenCrown {
                var c = Path(); c.move(to: P(45, 52)); c.addLine(to: P(49, 37)); c.addLine(to: P(60, 46)); c.addLine(to: P(71, 37)); c.addLine(to: P(75, 52)); c.closeSubpath()
                ctx.fill(c, with: .color(gold)); ctx.stroke(c, with: .color(Self.hex(0xDDA13F)), style: StrokeStyle(lineWidth: 2 * k, lineJoin: .round))
                ctx.fill(Path(ellipseIn: CGRect(x: 57.5 * k, y: 41.5 * k, width: 5 * k, height: 5 * k)), with: .color(pink))
            } else if g.flowerCrown {
                let petals: [(Double, Double, Color)] = [(40, 56, pink), (49, 51, gold), (60, 49, .white), (71, 51, gold), (80, 56, pink)]
                for (x, y, c) in petals {
                    let p = Path(ellipseIn: CGRect(x: (x - 4.5) * k, y: (y - 4.5) * k, width: 9 * k, height: 9 * k))
                    ctx.fill(p, with: .color(c)); ctx.stroke(p, with: .color(deep), lineWidth: 1.2 * k)
                }
                ctx.fill(Path(ellipseIn: CGRect(x: 58.4 * k, y: 47.4 * k, width: 3.2 * k, height: 3.2 * k)), with: .color(gold))
            } else if g.sprout {
                var stem = Path(); stem.move(to: P(60, 49)); stem.addLine(to: P(60, 37))
                ctx.stroke(stem, with: .color(Self.hex(0x3E9B6B)), style: StrokeStyle(lineWidth: 3 * k))
                var l1 = Path(); l1.move(to: P(60, 40)); l1.addCurve(to: P(49, 28), control1: P(52, 39), control2: P(47, 33)); l1.addCurve(to: P(60, 40), control1: P(56, 28), control2: P(60, 32)); l1.closeSubpath()
                var l2 = Path(); l2.move(to: P(60, 42)); l2.addCurve(to: P(70, 29), control1: P(67, 39), control2: P(72, 33)); l2.addCurve(to: P(60, 42), control1: P(63, 30), control2: P(60, 35)); l2.closeSubpath()
                ctx.fill(l1, with: .color(Self.hex(0x58B287))); ctx.fill(l2, with: .color(Self.hex(0x7FCB9F)))
            }
            if g.bow {
                var t1 = Path(); t1.move(to: P(79, 53)); t1.addLine(to: P(70, 47)); t1.addLine(to: P(70, 59)); t1.closeSubpath()
                var t2 = Path(); t2.move(to: P(79, 53)); t2.addLine(to: P(88, 47)); t2.addLine(to: P(88, 59)); t2.closeSubpath()
                ctx.fill(t1, with: .color(pink)); ctx.fill(t2, with: .color(pink))
                ctx.fill(Path(ellipseIn: CGRect(x: 76 * k, y: 50 * k, width: 6 * k, height: 6 * k)), with: .color(deep))
            }
            if g.scarf {
                var s1 = Path(); s1.move(to: P(33, 104)); s1.addQuadCurve(to: P(87, 104), control: P(60, 120)); s1.addLine(to: P(89, 112)); s1.addQuadCurve(to: P(31, 112), control: P(60, 129)); s1.closeSubpath()
                var s2 = Path(); s2.move(to: P(77, 111)); s2.addLine(to: P(82, 125)); s2.addLine(to: P(90, 122)); s2.addLine(to: P(85, 109)); s2.closeSubpath()
                ctx.fill(s1, with: .color(gold)); ctx.fill(s2, with: .color(Self.hex(0xEDBE55)))
            }
        }
        .frame(width: width, height: width * 128 / 120)
        .accessibilityLabel("Your bunny, level \(level)")
        .accessibilityIdentifier("hb-level-bunny")
    }
}

/// "Level up!" with the bunny, shown when a reward raises your level (the website's level-up dialog)
@available(iOS 15.0, *)
struct HBLevelUpCard: View {
    let level: Int
    let onClose: () -> Void
    var body: some View {
        let title = HBProgress.titles[min(level, HBProgress.titles.count) - 1]
        let text = HBRewardEvent.levelUpText(level)
        return ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 10) {
                HBLevelBunny(level: level, width: 120)
                Text("Level up!").font(.system(size: 13, weight: .heavy)).foregroundColor(HB.orange).textCase(.uppercase)
                Text("Level \(level) · \(title)").font(.system(size: 22, weight: .bold)).foregroundColor(.white).multilineTextAlignment(.center)
                Text(text).font(.system(size: 15)).foregroundColor(HB.soft).multilineTextAlignment(.center)
                Button(action: onClose) {
                    Text("Yay!").font(.system(size: 17, weight: .bold)).foregroundColor(Color.black.opacity(0.85)).frame(maxWidth: .infinity, minHeight: 48)
                        .background(Capsule().fill(HB.orange))
                }
                .accessibilityIdentifier("hb-levelup-ok").padding(.top, 6)
            }
            .padding(22).frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(red: 0.13, green: 0.09, blue: 0.17)))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(HB.orange.opacity(0.5), lineWidth: 1.5))
            .padding(24)
        }
        .accessibilityElement(children: .contain)
    }
}

/// One small message at the bottom of the screen: what just happened, the carrots earned, and sometimes Undo. Only one is ever shown at a time.
struct HBToast: Identifiable {
    let id = UUID()
    let text: String
    var detail: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
}

@available(iOS 15.0, *)
struct HBToastView: View {
    let toast: HBToast
    let onDismiss: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.text).font(.system(size: 15, weight: .semibold)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
                if let d = toast.detail { Text(d).font(.system(size: 13)).foregroundColor(Color(red: 1, green: 0.83, blue: 0.48)) }
            }
            Spacer(minLength: 4)
            if let title = toast.actionTitle, let act = toast.action {
                Button { onDismiss(); act() } label: { Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(HB.orange).padding(.horizontal, 6).frame(minHeight: 36) }
                    .accessibilityIdentifier("hb-toast-action")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Capsule().fill(Color(red: 0.16, green: 0.11, blue: 0.2)))
        .overlay(Capsule().stroke(HB.orange.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain).accessibilityIdentifier("hb-toast")
    }
}
