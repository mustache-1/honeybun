import XCTest

// Real-touch check of the native screens: launch Home / Money in preview mode, then physically swipe up (a synthesized finger drag, the same
// path a real touch takes) until the content stops moving, and photograph the top and the very bottom. CI publishes the pictures.
final class HoneybunScrollUITests: XCTestCase {
    private let dir = "/tmp/hbshots"

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    private func shot(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        let a = XCTAttachment(screenshot: s); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    private func note(_ text: String) {
        let path = "\(dir)/notes.txt"
        let old = (try? String(contentsOfFile: path)) ?? ""
        try? (old + text + "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func dragToBottom(_ screen: String, overlay: Bool = false) {
        let tag = overlay ? "\(screen)overlay" : screen
        let app = XCUIApplication()
        app.launchArguments = ["-HBPreview", screen] + (overlay ? ["-HBOverlayBar"] : [])
        app.launch()
        Thread.sleep(forTimeInterval: 9)
        shot("\(tag)_top")
        let scroll = app.scrollViews.firstMatch
        note("\(tag): scrollViews=\(app.scrollViews.count) exists=\(scroll.exists) frame=\(scroll.frame) window=\(app.windows.firstMatch.frame)")
        for i in 0..<10 {
            if scroll.exists { scroll.swipeUp() } else { app.swipeUp() }
            Thread.sleep(forTimeInterval: 0.6)
            if i == 1 { shot("\(tag)_mid") }
        }
        Thread.sleep(forTimeInterval: 1.5)
        shot("\(tag)_bottom")
        note("\(tag): after drags frame=\(scroll.frame)")
        // measure the real on-screen frames: last card vs the top of the tab bar
        let last = app.descendants(matching: .any).matching(identifier: "hb-last-card").firstMatch
        let bar = app.descendants(matching: .any).matching(identifier: "hb-tabbar").firstMatch
        if last.exists && bar.exists {
            let gap = bar.frame.minY - last.frame.maxY
            note("\(tag): LAST CARD bottom=\(last.frame.maxY) tab bar top=\(bar.frame.minY) GAP=\(gap) (bar pill is ~4pt taller than this frame)")
            XCTAssertGreaterThanOrEqual(gap, 14, "\(tag): the last card is hidden by the tab bar")
            XCTAssertLessThanOrEqual(gap, 40, "\(tag): too much empty space under the last card")
        } else {
            note("\(tag): could not find last card (\(last.exists)) or tab bar (\(bar.exists))")
            XCTFail("\(tag): last card or tab bar not found")
        }
        app.terminate()
    }

    func testHomeDragToBottom() { dragToBottom("home") }
    func testMoneyDragToBottom() { dragToBottom("money") }
    // the old arrangement (scroll area running underneath the bar), to prove the measured trailing space fixes it too
    func testGoalsDragToBottom() { dragToBottom("goals") }
    func testHomeDragToBottomUnderBar() { dragToBottom("home", overlay: true) }
    func testMoneyDragToBottomUnderBar() { dragToBottom("money", overlay: true) }
}
