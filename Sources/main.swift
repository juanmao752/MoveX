import Cocoa

let bundleID = Bundle.main.bundleIdentifier ?? "com.linwk.MoveX"
let currentPID = ProcessInfo.processInfo.processIdentifier
let existingInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    .filter { $0.processIdentifier != currentPID }

if !existingInstances.isEmpty {
    DistributedNotificationCenter.default().post(
        name: Notification.Name("com.linwk.MoveX.reopen"),
        object: nil
    )
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
