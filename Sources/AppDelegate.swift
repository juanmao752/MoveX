import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = CutPasteEngine()
    private var statusItem: NSStatusItem!
    private var permissionTimer: Timer?

    private lazy var logoGalleryController = LogoGalleryWindowController()
    private lazy var permissionGuideController = PermissionGuideWindowController()

    private let statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let cancelCutMenuItem = NSMenuItem(title: "取消待剪切状态 (Esc)", action: #selector(cancelCutClicked), keyEquivalent: "")
    private let grantAccessMenuItem = NSMenuItem(title: "⚠️ 授予辅助功能权限...", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private let enabledMenuItem = NSMenuItem(title: "启用 MoveX", action: #selector(toggleEnabled), keyEquivalent: "")
    private let soundMenuItem = NSMenuItem(title: "剪切时播放提示音", action: #selector(toggleSound), keyEquivalent: "")
    private let escCancelMenuItem = NSMenuItem(title: "按 Esc 取消待剪切", action: #selector(toggleEscCancel), keyEquivalent: "")
    private let launchAtLoginMenuItem = NSMenuItem(title: "开机自动启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let styleScissorsMenuItem = NSMenuItem(title: "剪刀图标 (✂️)", action: #selector(selectScissorsStyle), keyEquivalent: "")
    private let styleCmdXMenuItem = NSMenuItem(title: "⌘X 字符徽章", action: #selector(selectCmdXStyle), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        applySelectedAppIcon()
        setupStatusBar()

        engine.onStateChanged = { [weak self] in
            DispatchQueue.main.async {
                self?.refreshUI()
            }
        }

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleReopenNotification),
            name: Notification.Name("com.linwk.MoveX.reopen"),
            object: nil
        )

        if AccessibilityHelper.isTrusted(prompt: true) {
            _ = engine.start()
        } else {
            showPermissionGuide()
            startPermissionPolling()
        }

        refreshUI()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        engine.stop()
    }

    private func applySelectedAppIcon() {
        let variant = Preferences.shared.selectedLogoVariant.lowercased()
        if let url = Bundle.main.url(forResource: "preview-\(variant)", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = image
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()

        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(grantAccessMenuItem)
        menu.addItem(cancelCutMenuItem)
        menu.addItem(.separator())

        enabledMenuItem.target = self
        soundMenuItem.target = self
        escCancelMenuItem.target = self
        launchAtLoginMenuItem.target = self
        grantAccessMenuItem.target = self
        cancelCutMenuItem.target = self

        menu.addItem(enabledMenuItem)
        menu.addItem(soundMenuItem)
        menu.addItem(escCancelMenuItem)

        let styleItem = NSMenuItem(title: "菜单栏图标样式", action: nil, keyEquivalent: "")
        let styleSubmenu = NSMenu()
        styleScissorsMenuItem.target = self
        styleCmdXMenuItem.target = self
        styleSubmenu.addItem(styleScissorsMenuItem)
        styleSubmenu.addItem(styleCmdXMenuItem)
        styleItem.submenu = styleSubmenu
        menu.addItem(styleItem)

        menu.addItem(launchAtLoginMenuItem)
        menu.addItem(.separator())

        let galleryItem = NSMenuItem(title: "选择 App Logo 图标 (A / B / C)...", action: #selector(openLogoGallery), keyEquivalent: "")
        galleryItem.target = self
        menu.addItem(galleryItem)

        let aboutItem = NSMenuItem(title: "关于 MoveX", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "退出 MoveX", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if AccessibilityHelper.isTrusted(prompt: false) {
                timer.invalidate()
                self.permissionTimer = nil
                _ = self.engine.start()
                self.permissionGuideController.refreshStatus()
                self.refreshUI()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.permissionGuideController.window?.close()
                }
            }
        }
    }

    private func refreshUI() {
        let trusted = AccessibilityHelper.isTrusted(prompt: false)
        let enabled = Preferences.shared.isEnabled

        grantAccessMenuItem.isHidden = trusted
        cancelCutMenuItem.isHidden = !engine.isCutPending

        if !trusted {
            statusMenuItem.title = "⚠️ 等待授予辅助功能权限"
        } else if !enabled {
            statusMenuItem.title = "⏸ MoveX 已暂停"
        } else if engine.isCutPending {
            let names = engine.cutItemNames
            if names.count == 1, let first = names.first {
                let display = first.count > 24 ? String(first.prefix(22)) + "…" : first
                statusMenuItem.title = "✂️ 待移动: \(display)"
            } else {
                statusMenuItem.title = "✂️ 待移动: \(names.count) 个项目（按 ⌘V 移动）"
            }
        } else if engine.isTapActive {
            statusMenuItem.title = "✅ MoveX 运行中（仅在 Finder 生效）"
        } else {
            statusMenuItem.title = "⚠️ 事件监听未启动，请检查辅助功能权限"
        }

        enabledMenuItem.state = enabled ? .on : .off
        soundMenuItem.state = Preferences.shared.playSound ? .on : .off
        escCancelMenuItem.state = Preferences.shared.escCancelsCut ? .on : .off
        launchAtLoginMenuItem.state = Preferences.shared.isLaunchAtLoginEnabled ? .on : .off

        let style = Preferences.shared.menuBarStyle
        styleScissorsMenuItem.state = (style == "scissors") ? .on : .off
        styleCmdXMenuItem.state = (style == "cmdx") ? .on : .off

        updateStatusBarButton(trusted: trusted, enabled: enabled, isCutPending: engine.isCutPending)
    }

    private func updateStatusBarButton(trusted: Bool, enabled: Bool, isCutPending: Bool) {
        guard let button = statusItem.button else { return }

        if !trusted {
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "需要辅助功能权限")
            button.title = ""
            button.appearsDisabled = false
            return
        }

        if Preferences.shared.menuBarStyle == "cmdx" {
            button.image = renderCmdXBadgeImage(isPending: isCutPending)
            button.title = ""
            button.appearsDisabled = !enabled
            return
        }

        let symbolName = isCutPending ? "scissors.circle.fill" : "scissors"
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MoveX")
        img?.isTemplate = true
        button.image = img
        button.title = ""
        button.appearsDisabled = !enabled
    }

    private func renderCmdXBadgeImage(isPending: Bool) -> NSImage {
        let size = NSSize(width: 28, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let badgeRect = rect.insetBy(dx: 1, dy: 2)
            let path = NSBezierPath(roundedRect: badgeRect, xRadius: 4.5, yRadius: 4.5)

            if isPending {
                NSColor.labelColor.setFill()
                path.fill()
            } else {
                path.lineWidth = 1.2
                NSColor.labelColor.setStroke()
                path.stroke()
            }

            let textColor = isPending ? NSColor.windowBackgroundColor : NSColor.labelColor
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .semibold),
                .foregroundColor: textColor
            ]
            let label = "⌘X" as NSString
            let textSize = label.size(withAttributes: attrs)
            let textPoint = NSPoint(
                x: (rect.width - textSize.width) / 2.0,
                y: (rect.height - textSize.height) / 2.0 + 0.5
            )
            label.draw(at: textPoint, withAttributes: attrs)
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc private func handleReopenNotification() {
        if !AccessibilityHelper.isTrusted(prompt: false) {
            showPermissionGuide()
        } else {
            openLogoGallery()
        }
    }

    private func showPermissionGuide() {
        NSApp.activate(ignoringOtherApps: true)
        permissionGuideController.refreshStatus()
        permissionGuideController.showWindow(nil)
        permissionGuideController.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityHelper.openSystemSettings()
        showPermissionGuide()
        if permissionTimer == nil {
            startPermissionPolling()
        }
    }

    @objc private func cancelCutClicked() {
        engine.cancelCut()
    }

    @objc private func toggleEnabled() {
        let newValue = !Preferences.shared.isEnabled
        Preferences.shared.isEnabled = newValue
        if !newValue {
            engine.cancelCut()
        } else if AccessibilityHelper.isTrusted(prompt: false) && !engine.isTapActive {
            _ = engine.start()
        }
        refreshUI()
    }

    @objc private func toggleSound() {
        Preferences.shared.playSound.toggle()
        refreshUI()
    }

    @objc private func toggleEscCancel() {
        Preferences.shared.escCancelsCut.toggle()
        refreshUI()
    }

    @objc private func selectScissorsStyle() {
        Preferences.shared.menuBarStyle = "scissors"
        refreshUI()
    }

    @objc private func selectCmdXStyle() {
        Preferences.shared.menuBarStyle = "cmdx"
        refreshUI()
    }

    @objc private func toggleLaunchAtLogin() {
        let target = !Preferences.shared.isLaunchAtLoginEnabled
        if let error = Preferences.shared.setLaunchAtLogin(target) {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "无法更改开机自启设置"
            alert.informativeText = "请先将 MoveX.app 拖入「应用程序 (/Applications)」文件夹后再开启开机自启。\n\n详细信息：\(error.localizedDescription)"
            alert.runModal()
        }
        refreshUI()
    }

    @objc private func openLogoGallery() {
        NSApp.activate(ignoringOtherApps: true)
        logoGalleryController.refreshSelectionUI()
        logoGalleryController.showWindow(nil)
        logoGalleryController.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "MoveX (v1.0.0)"
        alert.informativeText = """
        在 macOS 访达（Finder）和桌面中实现真正的：
        • ⌘X 剪切文件 / 文件夹（安全触发原生复制并标记待移动）
        • ⌘V 粘贴并移动（自动转换为原生 ⌥⌘V 移动项目）
        • 重命名或搜索输入框中自动放行文本 ⌘X / ⌘V
        • Esc 或其他应用复制自动取消待移动状态
        """
        alert.icon = NSApp.applicationIconImage
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
