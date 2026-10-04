import XCTest

// Real taps and swipes on the native Goals screens. The app is launched with `-HBMock <seed>` (debug only): the real native code runs, talking to an
// in-process stand-in for the goals/jar endpoints (HBMockServer), so no login or network is involved. Pictures + notes go to /tmp/hbshots for CI.
final class HoneybunGoalsUITests: XCTestCase {
    private let dir = "/tmp/hbshots"
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    // MARK: helpers

    private func shot(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        let a = XCTAttachment(screenshot: s); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    private func note(_ text: String) {
        let path = "\(dir)/goals-notes.txt"
        let old = (try? String(contentsOfFile: path)) ?? ""
        try? (old + text + "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func launch(_ seed: String) {
        app = XCUIApplication()
        app.launchArguments = ["-HBMock", seed]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["hb-tabbar"].waitForExistence(timeout: 40), "native Goals never appeared (\(seed))")
        Thread.sleep(forTimeInterval: 1.5)
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func labelled(_ prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// swipe up until the element can be tapped (the opaque tab bar counts as covering it)
    private func reveal(_ el: XCUIElement) {
        for _ in 0..<10 { if el.exists && el.isHittable { return }; app.swipeUp(); Thread.sleep(forTimeInterval: 0.4) }
    }

    private func tap(_ el: XCUIElement, _ what: String) {
        XCTAssertTrue(el.waitForExistence(timeout: 8), "missing: \(what)")
        reveal(el)
        el.tap()
    }

    private func dismissKeyboard() {
        let done = app.buttons["Done"]
        if done.exists && done.isHittable { done.tap(); Thread.sleep(forTimeInterval: 0.4) }
    }

    /// put the caret at the end of the field, wipe what is there, type the new text
    private func replaceText(_ field: XCUIElement, _ text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 8), "missing field")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        let cur = (field.value as? String) ?? ""
        if !cur.isEmpty && cur != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: cur.count + 2))
        }
        field.typeText(text)
    }

    /// waits for the summary line ("$X of $Y") to change on screen without leaving the Goal Details; returns how long it took
    @discardableResult
    private func expectSummary(_ text: String, step: String) -> Double {
        let t0 = Date()
        let el = app.staticTexts[text]
        let ok = el.waitForExistence(timeout: 5)
        let dt = Date().timeIntervalSince(t0)
        note("REFRESH \(step): expected \"\(text)\" -> \(ok ? "shown" : "NOT SHOWN") after \(String(format: "%.2f", dt))s (screen was not left)")
        XCTAssertTrue(ok, "\(step): the details did not refresh to \(text)")
        return dt
    }

    private func scrollBounds() -> (gap: CGFloat?, lastMaxY: CGFloat?, barMinY: CGFloat?) {
        let last = any("hb-last-card"), bar = any("hb-tabbar")
        guard last.exists, bar.exists else { return (nil, nil, nil) }
        return (bar.frame.minY - last.frame.maxY, last.frame.maxY, bar.frame.minY)
    }

    // MARK: 1. the bottom of Goals, for every list size and filter

    func testGoalsBottomMatrix() {
        for seed in ["empty", "short", "default", "long"] {
            launch(seed)
            for filter in ["active", "done", "all"] {
                tap(app.buttons["hb-filter-\(filter)"], "filter \(filter)")
                Thread.sleep(forTimeInterval: 0.8)
                let before = scrollBounds()
                for _ in 0..<5 { app.swipeDown(); Thread.sleep(forTimeInterval: 0.2) }
                let b0 = scrollBounds()
                let needsScroll = (b0.lastMaxY ?? 0) > ((b0.barMinY ?? 0) - 14)
                for _ in 0..<14 { app.swipeUp(); Thread.sleep(forTimeInterval: 0.35) }
                Thread.sleep(forTimeInterval: 1.0)
                shot("goals_\(seed)_\(filter)_bottom")
                let after = scrollBounds()
                if let gap = after.gap {
                    note("BOTTOM \(seed)/\(filter): scrollable=\(needsScroll) gap(last item -> tab bar top)=\(gap) (frame before=\(String(describing: before.gap)))")
                    XCTAssertGreaterThanOrEqual(gap, 14, "\(seed)/\(filter): the last item is hidden behind the tab bar")
                    if needsScroll { XCTAssertLessThanOrEqual(gap, 40, "\(seed)/\(filter): too much empty space under the last item") }
                } else {
                    note("BOTTOM \(seed)/\(filter): could not find last item or tab bar")
                    XCTFail("\(seed)/\(filter): last item or tab bar not found")
                }
                for _ in 0..<14 { app.swipeDown(); Thread.sleep(forTimeInterval: 0.2) }
            }
            app.terminate()
        }
    }

    // MARK: 2. every Goals action, by tapping the real screens

    func testGoalsFlow() {
        launch("default")
        shot("flow_01_goals_list")
        XCTAssertTrue(labelled("Vacation Fund").exists, "seeded goals missing")

        // create
        tap(app.buttons["hb-goal-create"], "Create a new goal")
        replaceText(app.textFields["hb-goal-name"], "Test Trip")
        replaceText(app.textFields["hb-goal-target"], "500")
        dismissKeyboard()
        shot("flow_02_create_form")
        tap(app.buttons["hb-goal-save"], "Create goal")
        let created = labelled("Test Trip")
        XCTAssertTrue(created.waitForExistence(timeout: 6), "the new goal did not appear in the list")
        note("CREATE: \"Test Trip\" appears in the Active list right after saving (form closed itself)")
        shot("flow_03_created_in_list")

        // open it
        tap(created, "Test Trip row")
        expectSummary("$0.00 of $500.00", step: "open new goal")
        shot("flow_04_detail_new")

        // edit: rename + new target, back to the details
        tap(app.buttons["hb-edit-goal"], "Edit goal")
        replaceText(app.textFields["hb-goal-name"], "Beach Trip")
        replaceText(app.textFields["hb-goal-target"], "400")
        dismissKeyboard()
        shot("flow_05_edit_form")
        tap(app.buttons["hb-goal-save"], "Save changes")
        expectSummary("$0.00 of $400.00", step: "edit goal")
        XCTAssertTrue(app.staticTexts["Beach Trip"].waitForExistence(timeout: 4), "renamed goal not shown")
        shot("flow_06_after_edit")

        // quick amounts
        var saved = 0.0
        for q in [10, 25, 50, 100] {
            tap(app.buttons["hb-quick-\(q)"], "$\(q)")
            tap(app.buttons["hb-add-funds"], "Add Funds")
            saved += Double(q)
            expectSummary(String(format: "$%.2f of $400.00", saved), step: "add $\(q)")
            shot("flow_07_added_\(q)")
        }

        // custom amount
        tap(app.textFields["hb-amount"], "Other amount")
        app.textFields["hb-amount"].typeText("15.50")
        dismissKeyboard()
        tap(app.buttons["hb-add-funds"], "Add Funds (custom)")
        saved += 15.5
        expectSummary(String(format: "$%.2f of $400.00", saved), step: "add custom 15.50")
        shot("flow_08_added_custom")

        // take out
        tap(app.textFields["hb-amount"], "Other amount")
        app.textFields["hb-amount"].typeText("20")
        dismissKeyboard()
        tap(app.buttons["hb-take-out"], "Take out")
        saved -= 20
        expectSummary(String(format: "$%.2f of $400.00", saved), step: "take out 20")
        shot("flow_09_taken_out")

        // undo the take-out (newest row first)
        reveal(app.buttons["hb-undo-move"].firstMatch)
        app.buttons["hb-undo-move"].firstMatch.tap()
        saved += 20
        expectSummary(String(format: "$%.2f of $400.00", saved), step: "undo the take-out")
        shot("flow_10_after_undo")

        // complete the goal
        tap(app.textFields["hb-amount"], "Other amount")
        app.textFields["hb-amount"].typeText(String(format: "%.2f", 400 - saved))
        dismissKeyboard()
        tap(app.buttons["hb-add-funds"], "Add Funds (complete)")
        expectSummary("$400.00 of $400.00", step: "complete the goal")
        XCTAssertTrue(app.staticTexts["You reached this goal!"].waitForExistence(timeout: 3), "completed state not shown")
        note("COMPLETE: \"You reached this goal!\" shown, 100%")
        shot("flow_11_completed")

        // back to the list: it is in Completed, not Active
        app.swipeDown()
        tap(app.buttons["Back"].exists ? app.buttons["Back"] : app.navigationBars.buttons.firstMatch, "Back")
        tap(app.buttons["hb-filter-done"], "Completed filter")
        let done = labelled("Beach Trip")
        XCTAssertTrue(done.waitForExistence(timeout: 4), "completed goal not under Completed")
        shot("flow_12_completed_filter")
        tap(app.buttons["hb-filter-active"], "Active filter")
        XCTAssertFalse(labelled("Beach Trip").waitForExistence(timeout: 1.5), "completed goal still under Active")

        // delete
        tap(app.buttons["hb-filter-done"], "Completed filter")
        tap(labelled("Beach Trip"), "Beach Trip row")
        tap(app.buttons["hb-edit-goal"], "Edit goal")
        tap(app.buttons["hb-goal-delete"], "Delete goal")
        shot("flow_13_delete_confirm")
        let confirm = app.buttons["Delete"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 4), "no delete confirmation")
        confirm.tap()
        Thread.sleep(forTimeInterval: 1.2)
        tap(app.buttons["hb-filter-all"], "All filter")
        XCTAssertFalse(labelled("Beach Trip").waitForExistence(timeout: 1.5), "deleted goal still listed")
        note("DELETE: goal gone from the list right after confirming")
        shot("flow_14_after_delete")
    }
}
