import Foundation

// Drives every Goals action through the app's REAL data path (HBAPI -> URLSession -> JSON -> HBNestSnapshot decoder) against the in-process
// stand-in backend (HBMockServer, which follows src/worker.js), and checks the numbers the screen would show after each step.
// Compiled and run by CI on macOS. This proves the data/refresh logic; it does not tap the SwiftUI views.
var failures = 0
func check(_ name: String, _ ok: Bool) { print((ok ? "PASS " : "FAIL ") + name); if !ok { failures += 1 } }

func run() async {
    HBMockServer.install(seed: "default")
    let api = HBAPI.shared
    func snap() async -> HBNestSnapshot? { try? await api.nest(month: "2026-10") }
    func goal(_ s: HBNestSnapshot?, _ name: String) -> HBGoal? { s?.goals.first { $0.name == name } }
    func moves(_ s: HBNestSnapshot?, _ id: String) -> [HBJarMove] { (s?.jar ?? []).filter { $0.goal_id == id }.sorted { $0.created_at > $1.created_at } }

    var s = await snap()
    check("seed loads: 4 goals, Wedding Fund is complete", s?.goals.count == 4 && goal(s, "Wedding Fund")?.isDone == true)
    check("icons follow the name rules (Vacation->palm, PC->pc, Emergency->shield)",
          HBGoalKind(name: "Vacation Fund", emoji: "✈️") == .palm && HBGoalKind(name: "New PC Build", emoji: "🎓") == .pc && HBGoalKind(name: "Emergency Fund", emoji: "🛟") == .shield)

    // create
    var d = HBGoalDraft(); d.name = "Test Trip"; d.target = 500; d.emoji = "✈️"
    do { try await api.addGoal(d) } catch { check("create goal (\(error))", false) }
    s = await snap()
    check("CREATE: new goal listed, $0 of $500, not complete", goal(s, "Test Trip")?.saved_cents == 0 && goal(s, "Test Trip")?.target_cents == 50000 && goal(s, "Test Trip")?.isDone == false)
    check("CREATE: goal count is 5", s?.goals.count == 5)
    guard let id = goal(s, "Test Trip")?.id else { print("FAIL no id"); exit(1) }

    // edit
    var e = HBGoalDraft(); e.name = "Beach Trip"; e.target = 400; e.emoji = "✈️"
    do { try await api.updateGoal(id: id, e) } catch { check("edit goal (\(error))", false) }
    s = await snap()
    check("EDIT: renamed and retargeted", goal(s, "Beach Trip")?.id == id && goal(s, "Beach Trip")?.target_cents == 40000 && goal(s, "Test Trip") == nil)
    check("EDIT: icon follows the new name", HBGoalKind(name: "Beach Trip", emoji: "✈️") == .palm)

    // quick amounts
    var expected = 0
    for q in [10, 25, 50, 100] {
        do { try await api.moveJar(goalID: id, amount: Double(q), out: false) } catch { check("add $\(q) (\(error))", false) }
        expected += q * 100
        s = await snap()
        check("ADD $\(q): saved is now \(expected) cents, newest activity row is +$\(q)", goal(s, "Beach Trip")?.saved_cents == expected && moves(s, id).first?.amount_cents == q * 100)
    }
    // custom
    do { try await api.moveJar(goalID: id, amount: 15.5, out: false) } catch { check("custom (\(error))", false) }
    expected += 1550; s = await snap()
    check("CUSTOM $15.50: saved 20050 cents, activity row +15.50", goal(s, "Beach Trip")?.saved_cents == expected && moves(s, id).first?.amount_cents == 1550)
    // take out
    do { try await api.moveJar(goalID: id, amount: 20, out: true) } catch { check("take out (\(error))", false) }
    expected -= 2000; s = await snap()
    check("TAKE OUT $20: saved 18050 cents, newest row is −$20", goal(s, "Beach Trip")?.saved_cents == expected && moves(s, id).first?.amount_cents == -2000)
    // take out more than saved is refused with the server's message
    do { try await api.moveJar(goalID: id, amount: 9999, out: true); check("TAKE OUT too much is refused", false) }
    catch { check("TAKE OUT too much is refused with the server's message", "\(error)".contains("can't take out more") || (error as? HBAPIError)?.errorDescription?.contains("can't take out more") == true) }
    s = await snap()
    check("refused take-out changed nothing", goal(s, "Beach Trip")?.saved_cents == expected)
    // undo the take-out
    if let m = moves(s, id).first { do { try await api.deleteJarMove(id: m.id) } catch { check("undo (\(error))", false) } }
    expected += 2000; s = await snap()
    check("UNDO take-out: saved back to 20050 cents, row gone", goal(s, "Beach Trip")?.saved_cents == expected && moves(s, id).count == 5)
    // undo a deposit
    if let m = moves(s, id).first(where: { $0.amount_cents == 1550 }) { try? await api.deleteJarMove(id: m.id) }
    expected -= 1550; s = await snap()
    check("UNDO deposit $15.50: saved 18500 cents", goal(s, "Beach Trip")?.saved_cents == expected)
    // complete
    let rest = Double(40000 - expected) / 100
    do { try await api.moveJar(goalID: id, amount: rest, out: false) } catch { check("complete (\(error))", false) }
    s = await snap()
    check("COMPLETE: $400 of $400, isDone, progress 100%", goal(s, "Beach Trip")?.saved_cents == 40000 && goal(s, "Beach Trip")?.isDone == true && goal(s, "Beach Trip")?.progress == 1)
    check("COMPLETE: shows under Completed, not Active", (s?.goals.filter { $0.isDone }.contains { $0.name == "Beach Trip" }) == true && (s?.goals.filter { !$0.isDone }.contains { $0.name == "Beach Trip" }) == false)
    // delete
    do { try await api.deleteGoal(id: id) } catch { check("delete (\(error))", false) }
    s = await snap()
    check("DELETE: goal gone, its activity gone, others untouched", goal(s, "Beach Trip") == nil && moves(s, id).isEmpty && s?.goals.count == 4 && goal(s, "Vacation Fund")?.saved_cents == 42000)
    // validation
    var bad = HBGoalDraft(); bad.name = "  "; bad.target = 10
    do { try await api.addGoal(bad); check("blank name is refused", false) } catch { check("blank name is refused", true) }
}

let done = DispatchSemaphore(value: 0)
Task { await run(); done.signal() }
if done.wait(timeout: .now() + 60) == .timedOut { print("FAIL timed out"); exit(1) }
print(failures == 0 ? "ALL GOALS FLOW CHECKS PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
