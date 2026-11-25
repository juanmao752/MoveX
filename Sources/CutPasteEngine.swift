import Cocoa
import Carbon

final class CutPasteEngine {
    static let syntheticEventTag: Int64 = 0x4D4F_5658 // "MOVX"

    private enum KeyCode {
        static let x: CGKeyCode = CGKeyCode(kVK_ANSI_X)
        static let c: CGKeyCode = CGKeyCode(kVK_ANSI_C)
        static let v: CGKeyCode = CGKeyCode(kVK_ANSI_V)
        static let escape: CGKeyCode = CGKeyCode(kVK_Escape)
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pasteboardWatchdog: Timer?

    private(set) var isTapActive: Bool = false
    private(set) var isCutPending: Bool = false
    private(set) var cutChangeCount: Int = -1
    private(set) var cutItemNames: [String] = []

    var onStateChanged: (() -> Void)?

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        if isTapActive {
            return true
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }
            let engine = Unmanaged<CutPasteEngine>.fromOpaque(refcon).takeUnretainedValue()
            return engine.handleEvent(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: userInfo
        ) else {
            isTapActive = false
            onStateChanged?()
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        isTapActive = true
        onStateChanged?()
        return true
    }

    func stop() {
        cancelCut()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        isTapActive = false
        onStateChanged?()
    }

    func cancelCut() {
        let wasPending = isCutPending
        pasteboardWatchdog?.invalidate()
        pasteboardWatchdog = nil
        isCutPending = false
        cutChangeCount = -1
        cutItemNames = []
        if wasPending {
            onStateChanged?()
        }
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        guard Preferences.shared.isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventTag {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let relevantMods: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        let mods = event.flags.intersection(relevantMods)

        let isCmdX = (keyCode == KeyCode.x && mods == .maskCommand)
        let isCmdV = (keyCode == KeyCode.v && mods == .maskCommand)
        let isCmdC = (keyCode == KeyCode.c && mods == .maskCommand)
        let isBareEsc = (keyCode == KeyCode.escape && mods.isEmpty && isCutPending)

        guard isCmdX || isCmdV || isCmdC || isBareEsc else {
            return Unmanaged.passUnretained(event)
        }

        // Pressing Cmd+C anywhere while files are cut resets the pending cut state.
        if isCmdC {
            if isCutPending {
                cancelCut()
            }
            return Unmanaged.passUnretained(event)
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier == "com.apple.finder" else {
            return Unmanaged.passUnretained(event)
        }

        let finderPID = frontApp.processIdentifier

        if isBareEsc {
            if Preferences.shared.escCancelsCut && !AccessibilityHelper.isFinderEditingText(finderPID: finderPID) {
                cancelCut()
            }
            return Unmanaged.passUnretained(event)
        }

        if isCmdX {
            if AccessibilityHelper.isFinderEditingText(finderPID: finderPID) {
                return Unmanaged.passUnretained(event)
            }

            let baselineCount = NSPasteboard.general.changeCount
            DispatchQueue.main.async { [weak self] in
                self?.triggerCopyAndArmCut(baselineCount: baselineCount)
            }
            return nil
        }

        if isCmdV {
            if AccessibilityHelper.isFinderEditingText(finderPID: finderPID) {
                return Unmanaged.passUnretained(event)
            }

            guard isCutPending else {
                return Unmanaged.passUnretained(event)
            }

            // Verify pasteboard still holds the exact cut items before moving.
            let currentCount = NSPasteboard.general.changeCount
            let fileURLs = readPasteboardFileURLs()
            guard currentCount == cutChangeCount, !fileURLs.isEmpty else {
                cancelCut()
                return Unmanaged.passUnretained(event)
            }

            cancelCut()
            DispatchQueue.main.async { [weak self] in
                self?.postKeyShortcut(keyCode: KeyCode.v, flags: [.maskCommand, .maskAlternate])
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func triggerCopyAndArmCut(baselineCount: Int) {
        postKeyShortcut(keyCode: KeyCode.c, flags: .maskCommand)
        pollPasteboardForCut(baselineCount: baselineCount, attemptsRemaining: 15)
    }

    private func pollPasteboardForCut(baselineCount: Int, attemptsRemaining: Int) {
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount != baselineCount {
            let urls = readPasteboardFileURLs()
            guard !urls.isEmpty else {
                cancelCut()
                return
            }

            pasteboardWatchdog?.invalidate()
            isCutPending = true
            cutChangeCount = pasteboard.changeCount
            cutItemNames = urls.map { $0.lastPathComponent }

            if Preferences.shared.playSound {
                NSSound(named: NSSound.Name("Tink"))?.play()
            }

            pasteboardWatchdog = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
                guard let self = self, self.isCutPending else { return }
                if NSPasteboard.general.changeCount != self.cutChangeCount {
                    self.cancelCut()
                }
            }

            onStateChanged?()
            return
        }

        guard attemptsRemaining > 1 else {
            // Nothing was selected in Finder or copy did not modify the pasteboard.
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.pollPasteboardForCut(baselineCount: baselineCount, attemptsRemaining: attemptsRemaining - 1)
        }
    }

    private func readPasteboardFileURLs() -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return (NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: options) as? [URL]) ?? []
    }

    private func postKeyShortcut(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .privateState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }

        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventTag)
        up.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventTag)

        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}
