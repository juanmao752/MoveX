import Cocoa

final class LogoGalleryWindowController: NSWindowController {
    private struct LogoOption {
        let id: String
        let title: String
        let subtitle: String
        let imageName: String
    }

    private let options: [LogoOption] = [
        LogoOption(
            id: "A",
            title: "方案 A：极简毛玻璃键帽",
            subtitle: "深海渐变 · 磨砂玻璃 ⌘X 键帽 + 激光切线",
            imageName: "preview-a"
        ),
        LogoOption(
            id: "B",
            title: "方案 B：Finder 穿梭光轨",
            subtitle: "天蓝渐变 · 虚线文件卡片滑向立体文件夹",
            imageName: "preview-b"
        ),
        LogoOption(
            id: "C",
            title: "方案 C：钛金剪刀徽章",
            subtitle: "哑光钛灰 · ⌘ 符号融合精密剪刀与橙色轴心",
            imageName: "preview-c"
        )
    ]

    private var actionButtons: [String: NSButton] = [:]
    private var cardBoxes: [String: NSBox] = [:]
    private let statusLabel = NSTextField(labelWithString: "")

    var onLogoChanged: ((String) -> Void)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MoveX — 选择 App Logo 图标"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        setupUI()
        refreshSelectionUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 16
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])

        let headerTitle = NSTextField(labelWithString: "三套定制 macOS 图标方案（已按苹果 Squircle 圆角规范裁切）")
        headerTitle.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        rootStack.addArrangedSubview(headerTitle)

        let cardsRow = NSStackView()
        cardsRow.orientation = .horizontal
        cardsRow.distribution = .fillEqually
        cardsRow.spacing = 16
        cardsRow.translatesAutoresizingMaskIntoConstraints = false
        rootStack.addArrangedSubview(cardsRow)
        cardsRow.widthAnchor.constraint(equalTo: rootStack.widthAnchor).isActive = true

        for option in options {
            let box = NSBox()
            box.boxType = .custom
            box.cornerRadius = 12
            box.borderWidth = 1.5
            box.contentViewMargins = NSSize(width: 14, height: 14)

            let cardStack = NSStackView()
            cardStack.orientation = .vertical
            cardStack.alignment = .centerX
            cardStack.spacing = 10
            cardStack.translatesAutoresizingMaskIntoConstraints = false

            let imageView = NSImageView()
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 150).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 150).isActive = true
            if let url = Bundle.main.url(forResource: option.imageName, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                imageView.image = image
            }

            let titleLabel = NSTextField(labelWithString: option.title)
            titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            titleLabel.alignment = .center

            let subLabel = NSTextField(wrappingLabelWithString: option.subtitle)
            subLabel.font = NSFont.systemFont(ofSize: 11)
            subLabel.textColor = .secondaryLabelColor
            subLabel.alignment = .center

            let button = NSButton(title: "设为当前图标", target: self, action: #selector(selectLogoClicked(_:)))
            button.bezelStyle = .rounded
            button.tag = optionTag(for: option.id)

            cardStack.addArrangedSubview(imageView)
            cardStack.addArrangedSubview(titleLabel)
            cardStack.addArrangedSubview(subLabel)
            cardStack.addArrangedSubview(button)

            box.contentView = cardStack
            cardsRow.addArrangedSubview(box)

            actionButtons[option.id] = button
            cardBoxes[option.id] = box
        }

        statusLabel.font = NSFont.systemFont(ofSize: 11.5)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 2
        rootStack.addArrangedSubview(statusLabel)
    }

    private func optionTag(for id: String) -> Int {
        switch id {
        case "A": return 1
        case "B": return 2
        case "C": return 3
        default: return 1
        }
    }

    private func optionID(for tag: Int) -> String {
        switch tag {
        case 1: return "A"
        case 2: return "B"
        case 3: return "C"
        default: return "A"
        }
    }

    @objc private func selectLogoClicked(_ sender: NSButton) {
        let selected = optionID(for: sender.tag)
        Preferences.shared.selectedLogoVariant = selected

        if let previewURL = Bundle.main.url(forResource: "preview-\(selected.lowercased())", withExtension: "png"),
           let image = NSImage(contentsOf: previewURL) {
            NSApp.applicationIconImage = image
        }

        onLogoChanged?(selected)
        refreshSelectionUI()
    }

    func refreshSelectionUI() {
        let current = Preferences.shared.selectedLogoVariant
        for option in options {
            let isSelected = (option.id == current)
            if let button = actionButtons[option.id] {
                button.title = isSelected ? "✓ 当前使用中" : "设为当前图标"
                button.isEnabled = !isSelected
                button.keyEquivalent = isSelected ? "" : ""
            }
            if let box = cardBoxes[option.id] {
                box.borderColor = isSelected ? NSColor.controlAccentColor : NSColor.separatorColor
                box.fillColor = isSelected
                    ? NSColor.controlAccentColor.withAlphaComponent(0.08)
                    : NSColor.windowBackgroundColor
            }
        }

        statusLabel.stringValue = "已应用方案 \(current) 到当前运行实例。如需永久替换 Finder 中的 .app 图标并重新签名，可在项目目录执行：./scripts/switch-icon.sh \(current)（重签名后需重新核对一次辅助功能开关）。"
    }
}

final class PermissionGuideWindowController: NSWindowController {
    private let statusBadge = NSTextField(labelWithString: "")
    private let actionButton = NSButton(title: "打开「辅助功能」设置", target: nil, action: nil)

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MoveX — 需要辅助功能权限"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        setupUI()
        refreshStatus()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])

        let titleLabel = NSTextField(labelWithString: "授权 MoveX 监听 Finder 快捷键")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)

        let bodyLabel = NSTextField(wrappingLabelWithString:
            "为了在访达（Finder）和桌面中将 ⌘X / ⌘V 转换为安全的原生文件移动操作（同时在重命名文件或搜索时自动放行文本剪切），请在：\n\n系统设置 → 隐私与安全性 → 辅助功能 中勾选「MoveX」。开启后本窗口会自动识别生效。"
        )
        bodyLabel.font = NSFont.systemFont(ofSize: 12.5)
        bodyLabel.textColor = .secondaryLabelColor

        statusBadge.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10

        actionButton.target = self
        actionButton.action = #selector(openSettingsClicked)
        actionButton.bezelStyle = .rounded
        actionButton.keyEquivalent = "\r"

        let closeButton = NSButton(title: "稍后处理", target: self, action: #selector(closeClicked))
        closeButton.bezelStyle = .rounded

        buttonRow.addArrangedSubview(actionButton)
        buttonRow.addArrangedSubview(closeButton)

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(bodyLabel)
        stack.addArrangedSubview(statusBadge)
        stack.addArrangedSubview(buttonRow)
    }

    func refreshStatus() {
        if AccessibilityHelper.isTrusted(prompt: false) {
            statusBadge.stringValue = "✅ 已获得辅助功能权限，MoveX 已就绪！"
            statusBadge.textColor = NSColor.systemGreen
            actionButton.isEnabled = false
        } else {
            statusBadge.stringValue = "⏳ 当前状态：尚未授权"
            statusBadge.textColor = NSColor.systemOrange
            actionButton.isEnabled = true
        }
    }

    @objc private func openSettingsClicked() {
        AccessibilityHelper.openSystemSettings()
    }

    @objc private func closeClicked() {
        window?.close()
    }
}
