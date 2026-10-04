import SwiftUI
import UIKit

// Measured scroll geometry. Every scrolling screen ends with a spacer whose height comes from here: how far the scroll view's real viewport
// ends from the top edge of the floating tab bar, both read from UIKit in window coordinates. If the viewport stops above the bar, that
// space already counts; if it runs underneath the bar (whatever the cause), the difference is added as trailing scroll content. So the last
// item always rests `HB.endGap` above the bar when dragged to the very bottom. No screen-height numbers anywhere.
@available(iOS 15.0, *)
@MainActor final class HBLayoutMetrics: ObservableObject {
    static let shared = HBLayoutMetrics()
    @Published private(set) var trailing: CGFloat = 0
    private var viewportEnd: CGFloat?    // bottom of the area the last item can reach (window y), after the safe-area inset
    private var barTop: CGFloat?         // top edge of the tab bar (window y)
    weak var scrollView: UIScrollView?   // the screen's scroll view, for the hidden diagnostic below

    /// Hidden diagnostic (long-press "Classic" on Home): the numbers behind the scroll layout, for bug reports.
    var summary: String {
        func f(_ v: CGFloat?) -> String { v.map { String(format: "%.1f", Double($0)) } ?? "n/a" }
        var lines = ["viewport end y: \(f(viewportEnd))", "tab bar top y: \(f(barTop))", "trailing space added: \(f(trailing))"]
        if let sv = scrollView {
            let fr = sv.superview?.convert(sv.frame, to: nil) ?? .zero
            lines.append("scroll view frame: y \(f(fr.minY)) to \(f(fr.maxY))")
            lines.append("content height: \(f(sv.contentSize.height))")
            lines.append("offset y: \(f(sv.contentOffset.y)), max y: \(f(sv.contentSize.height - sv.bounds.height + sv.adjustedContentInset.bottom))")
            lines.append("insets top/bottom: \(f(sv.adjustedContentInset.top)) / \(f(sv.adjustedContentInset.bottom))")
        }
        lines.append("screen height: \(f(UIScreen.main.bounds.height)), safe bottom: \(f(HBSafeArea.bottom))")
        return lines.joined(separator: "\n")
    }

    func setViewportEnd(_ v: CGFloat) { if viewportEnd == nil || abs((viewportEnd ?? 0) - v) > 0.5 { viewportEnd = v; recompute() } }
    func setBarTop(_ v: CGFloat) { if barTop == nil || abs((barTop ?? 0) - v) > 0.5 { barTop = v; recompute() } }

    private func recompute() {
        guard let end = viewportEnd, let top = barTop else { return }
        let slack = top - end                       // room already between the end of the scroll area and the bar (negative if it runs under it)
        let need = max(0, HB.endGap - slack)
        if abs(need - trailing) > 0.5 { trailing = need }
    }
}

enum HBProbeKind { case scrollEnd, barTop }

/// Invisible UIKit view that reports its position in window coordinates.
struct HBProbe: UIViewRepresentable {
    let kind: HBProbeKind
    func makeUIView(context: Context) -> HBProbeView { let v = HBProbeView(); v.kind = kind; v.isUserInteractionEnabled = false; v.backgroundColor = .clear; return v }
    func updateUIView(_ uiView: HBProbeView, context: Context) { uiView.setNeedsLayout() }
}

final class HBProbeView: UIView {
    var kind: HBProbeKind = .scrollEnd
    override func didMoveToWindow() { super.didMoveToWindow(); schedule() }
    override func layoutSubviews() { super.layoutSubviews(); schedule() }
    private func schedule() { DispatchQueue.main.async { [weak self] in self?.report() } }
    private func report() {
        guard window != nil else { return }
        guard #available(iOS 15.0, *) else { return }
        switch kind {
        case .barTop:
            HBLayoutMetrics.shared.setBarTop(convert(bounds, to: nil).minY)
        case .scrollEnd:
            var v: UIView? = superview
            while let cur = v {
                if let sv = cur as? UIScrollView {
                    HBLayoutMetrics.shared.scrollView = sv
                    let frame = sv.superview?.convert(sv.frame, to: nil) ?? .zero
                    HBLayoutMetrics.shared.setViewportEnd(frame.maxY - sv.adjustedContentInset.bottom)
                    return
                }
                v = cur.superview
            }
        }
    }
}
