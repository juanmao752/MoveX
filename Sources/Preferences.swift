import Foundation
import ServiceManagement

final class Preferences {
    static let shared = Preferences()

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let playSound = "playSound"
        static let escCancelsCut = "escCancelsCut"
        static let menuBarStyle = "menuBarStyle"
        static let selectedLogoVariant = "selectedLogoVariant"
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Keys.isEnabled: true,
            Keys.playSound: true,
            Keys.escCancelsCut: true,
            Keys.menuBarStyle: "scissors",
            Keys.selectedLogoVariant: "A"
        ])
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Keys.isEnabled) }
        set { defaults.set(newValue, forKey: Keys.isEnabled) }
    }

    var playSound: Bool {
        get { defaults.bool(forKey: Keys.playSound) }
        set { defaults.set(newValue, forKey: Keys.playSound) }
    }

    var escCancelsCut: Bool {
        get { defaults.bool(forKey: Keys.escCancelsCut) }
        set { defaults.set(newValue, forKey: Keys.escCancelsCut) }
    }

    /// `"scissors"` or `"cmdx"`
    var menuBarStyle: String {
        get { defaults.string(forKey: Keys.menuBarStyle) ?? "scissors" }
        set { defaults.set(newValue, forKey: Keys.menuBarStyle) }
    }

    /// `"A"`, `"B"`, or `"C"`
    var selectedLogoVariant: String {
        get { defaults.string(forKey: Keys.selectedLogoVariant) ?? "A" }
        set { defaults.set(newValue.uppercased(), forKey: Keys.selectedLogoVariant) }
    }

    var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) -> Error? {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return nil
        } catch {
            return error
        }
    }
}
