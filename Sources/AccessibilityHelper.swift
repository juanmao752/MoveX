import Cocoa
import ApplicationServices

enum AccessibilityHelper {
    static func isTrusted(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Checks whether Finder's currently focused UI element is a text input control
    /// (e.g. inline filename rename field, search bar, or Go-to-Folder dialog),
    /// so Cmd+X / Cmd+V continue to edit text normally.
    static func isFinderEditingText(finderPID: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(finderPID)
        var focusedValue: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard status == .success,
              let focused = focusedValue,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return false
        }

        let focusedElement = unsafeBitCast(focused, to: AXUIElement.self)
        let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

        if let role = stringAttribute(focusedElement, attribute: kAXRoleAttribute as CFString),
           textRoles.contains(role) {
            return true
        }

        if let subrole = stringAttribute(focusedElement, attribute: kAXSubroleAttribute as CFString),
           textRoles.contains(subrole) {
            return true
        }

        return false
    }

    private static func stringAttribute(_ element: AXUIElement, attribute: CFString) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success else { return nil }
        return value as? String
    }
}
