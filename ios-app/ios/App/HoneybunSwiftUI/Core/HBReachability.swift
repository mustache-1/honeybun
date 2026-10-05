import Foundation
import Network

// Tells the app when the phone gets a connection back, so entries saved offline can sync (see HBAppStore.connectionBack).
final class HBReachability {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "me.honeybun.reachability")
    var onChange: ((Bool) -> Void)?
    private var started = false
    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let up = path.status == .satisfied
            DispatchQueue.main.async { self?.onChange?(up) }
        }
        monitor.start(queue: queue)
    }
}
