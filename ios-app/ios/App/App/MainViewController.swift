import UIKit
import Capacitor

// Registers Honeybun's own native plugins with the web view.
class MainViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(BiometricLockPlugin())
        bridge?.registerPluginInstance(HoneybunNativePlugin())
    }
}
