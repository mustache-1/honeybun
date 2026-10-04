import UIKit
import Capacitor

// Registers Honeybun's own native plugins with the web view, and adds the real iPhone chrome around the
// website: a native tab bar, native pull-to-refresh, and edge-swipe back.
class MainViewController: CAPBridgeViewController, UITabBarDelegate {
    private let tabBar = UITabBar()
    // index matches each item's tag
    private let tabIDs = ["home", "plan", "add", "stats", "us"]
    private var lastItem: UITabBarItem?
    private var tabsWanted = true

    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(BiometricLockPlugin())
        bridge?.registerPluginInstance(HoneybunNativePlugin())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NativeChrome.shared.vc = self
        webView?.allowsBackForwardNavigationGestures = true
        webView?.scrollView.showsVerticalScrollIndicator = false // no scroll line down the right side
        webView?.scrollView.showsHorizontalScrollIndicator = false
        buildTabBar()
        buildRefreshControl()
        webView?.scrollView.bounces = false // signed-out screens (login) stay put like an app, not a web page
        webView?.scrollView.refreshControl = nil
        tabBar.isHidden = true // the website switches it on once the user is signed in
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let h = tabsHeight
        tabBar.frame = CGRect(x: 0, y: view.bounds.height - h, width: view.bounds.width, height: h)
        view.bringSubviewToFront(tabBar)
    }

    var tabsHeight: CGFloat {
        let bottom = view.window?.safeAreaInsets.bottom ?? view.safeAreaInsets.bottom
        return 49 + bottom
    }

    // MARK: tab bar

    private func buildTabBar() {
        let orange = UIColor(red: 0.96, green: 0.60, blue: 0.29, alpha: 1)
        let muted = UIColor(white: 1, alpha: 0.55)
        let items: [(String, String)] = [
            ("Home", "house.fill"), ("Plan", "calendar"), ("Add", "plus.circle.fill"), ("Stats", "chart.bar.fill"), ("Together", "heart.fill")
        ]
        tabBar.items = items.enumerated().map { (i, it) in
            let item = UITabBarItem(title: it.0, image: UIImage(systemName: it.1), tag: i)
            return item
        }
        tabBar.delegate = self
        tabBar.overrideUserInterfaceStyle = .dark // dark glass, readable labels, to match the app
        tabBar.tintColor = orange
        tabBar.unselectedItemTintColor = muted
        let ap = UITabBarAppearance()
        ap.configureWithDefaultBackground()
        ap.backgroundColor = UIColor(red: 0.082, green: 0.059, blue: 0.106, alpha: 0.94)
        ap.shadowColor = UIColor(white: 1, alpha: 0.08)
        for layout in [ap.stackedLayoutAppearance, ap.inlineLayoutAppearance, ap.compactInlineLayoutAppearance] {
            layout.normal.iconColor = muted
            layout.normal.titleTextAttributes = [.foregroundColor: muted]
            layout.selected.iconColor = orange
            layout.selected.titleTextAttributes = [.foregroundColor: orange]
        }
        tabBar.standardAppearance = ap
        if #available(iOS 15.0, *) { tabBar.scrollEdgeAppearance = ap }
        view.addSubview(tabBar)
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let id = tabIDs[item.tag]
        if id == "add" {
            tabBar.selectedItem = lastItem // Add opens a screen, it isn't a place you stay
        } else {
            lastItem = item
        }
        webView?.evaluateJavaScript("window.hbNativeGo && window.hbNativeGo('\(id)')", completionHandler: nil)
    }

    // called from the website (through HoneybunNative.setTab) whenever the screen changes
    func setTab(_ tab: String?, visible: Bool, app: Bool) {
        tabsWanted = visible
        tabBar.isHidden = !visible
        // rubber-band scrolling and pull-to-refresh only once you're inside the app
        webView?.scrollView.bounces = app
        webView?.scrollView.refreshControl = (app && visible) ? refresher : nil
        if let tab = tab, let idx = tabIDs.firstIndex(of: tab), idx != 2 {
            let item = tabBar.items?.first(where: { $0.tag == idx })
            tabBar.selectedItem = item
            lastItem = item
        } else {
            tabBar.selectedItem = nil
            lastItem = nil
        }
        view.setNeedsLayout()
    }

    // MARK: pull to refresh

    private let refresher = UIRefreshControl()

    private func buildRefreshControl() {
        refresher.tintColor = UIColor(white: 1, alpha: 0.8)
        refresher.addTarget(self, action: #selector(pulled), for: .valueChanged)
    }

    @objc private func pulled() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        webView?.evaluateJavaScript("window.hbNativeRefresh && window.hbNativeRefresh()", completionHandler: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.webView?.scrollView.refreshControl?.endRefreshing()
        }
    }
}

// The one place the bridge plugin reaches the native screen.
final class NativeChrome {
    static let shared = NativeChrome()
    weak var vc: MainViewController?
    var height: Double { Double(vc?.tabsHeight ?? 0) }
    func set(tab: String?, visible: Bool, app: Bool) { vc?.setTab(tab, visible: visible, app: app) }
}
