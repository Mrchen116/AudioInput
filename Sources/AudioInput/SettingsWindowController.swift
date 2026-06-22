import AppKit
import Foundation

final class SettingsWindowController: NSWindowController {
    private let appIDField = NSTextField(string: "")
    private let accessTokenField = NSSecureTextField(string: "")
    private let maxSecondsField = NSTextField(string: "180")
    private let retentionDaysField = NSTextField(string: "7")
    private let hotkeyPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let keepClipboardButton = NSButton(checkboxWithTitle: "保留识别结果到剪贴板", target: nil, action: nil)
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "开机自动启动", target: nil, action: nil)
    private let enableDDCButton = NSButton(checkboxWithTitle: "启用语义顺滑 (enable_ddc)", target: nil, action: nil)
    private let hotwordsField = NSTextField(string: "")
    private let saveButton = NSButton(title: "保存", target: nil, action: nil)

    private let getSettings: () -> AppSettings
    private let onSave: (AppSettings) -> Void

    init(getSettings: @escaping () -> AppSettings, onSave: @escaping (AppSettings) -> Void) {
        self.getSettings = getSettings
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "AudioInput 设置"
        super.init(window: window)
        buildUI()
        loadCurrentSettings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show() {
        loadCurrentSettings()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        content.subviews.forEach { $0.removeFromSuperview() }

        let labelWidth: CGFloat = 150
        let rowHeight: CGFloat = 28

        configureHotkeyPopup()

        let appIDRow = makeRow(labelText: "应用 APP_ID", labelWidth: labelWidth, field: appIDField, rowHeight: rowHeight)
        let tokenRow = makeRow(labelText: "访问 ACCESS_TOKEN", labelWidth: labelWidth, field: accessTokenField, rowHeight: rowHeight)
        let hotkeyRow = makeRow(labelText: "触发热键", labelWidth: labelWidth, field: hotkeyPopup, rowHeight: rowHeight)
        let maxSecondsRow = makeRow(labelText: "最大录音时长(秒)", labelWidth: labelWidth, field: maxSecondsField, rowHeight: rowHeight)
        let retentionRow = makeRow(labelText: "日志保留天数", labelWidth: labelWidth, field: retentionDaysField, rowHeight: rowHeight)
        let hotwordsRow = makeRow(labelText: "热词（逗号分隔）", labelWidth: labelWidth, field: hotwordsField, rowHeight: rowHeight)
        let enableDDCRow = makeRow(labelText: "", labelWidth: labelWidth, field: enableDDCButton, rowHeight: rowHeight)

        let formStack = NSStackView(views: [appIDRow, tokenRow, hotkeyRow, maxSecondsRow, retentionRow, hotwordsRow, enableDDCRow])
        formStack.orientation = .vertical
        formStack.alignment = .leading
        formStack.spacing = 12
        formStack.translatesAutoresizingMaskIntoConstraints = false

        keepClipboardButton.translatesAutoresizingMaskIntoConstraints = false
        launchAtLoginButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        saveButton.target = self
        saveButton.action = #selector(handleSave)

        content.addSubview(formStack)
        content.addSubview(keepClipboardButton)
        content.addSubview(launchAtLoginButton)
        content.addSubview(saveButton)

        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            formStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            formStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),

            keepClipboardButton.topAnchor.constraint(equalTo: formStack.bottomAnchor, constant: 20),
            keepClipboardButton.leadingAnchor.constraint(equalTo: formStack.leadingAnchor),

            launchAtLoginButton.topAnchor.constraint(equalTo: keepClipboardButton.bottomAnchor, constant: 10),
            launchAtLoginButton.leadingAnchor.constraint(equalTo: formStack.leadingAnchor),

            saveButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            saveButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            saveButton.widthAnchor.constraint(equalToConstant: 100),
            saveButton.heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    private func makeRow(labelText: String, labelWidth: CGFloat, field: NSView, rowHeight: CGFloat) -> NSStackView {
        let label = NSTextField(labelWithString: labelText)
        label.alignment = .right
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true

        field.translatesAutoresizingMaskIntoConstraints = false
        if let control = field as? NSControl {
            control.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true
        }

        let row = NSStackView(views: [label, field])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.distribution = .fill
        row.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        return row
    }

    private func configureHotkeyPopup() {
        hotkeyPopup.removeAllItems()
        hotkeyPopup.addItem(withTitle: "右 Cmd")
        hotkeyPopup.lastItem?.representedObject = HotkeySide.right.rawValue
        hotkeyPopup.addItem(withTitle: "左 Cmd")
        hotkeyPopup.lastItem?.representedObject = HotkeySide.left.rawValue
        hotkeyPopup.addItem(withTitle: "左右 Cmd")
        hotkeyPopup.lastItem?.representedObject = HotkeySide.both.rawValue
    }

    private func loadCurrentSettings() {
        let settings = getSettings()
        appIDField.stringValue = settings.appID
        accessTokenField.stringValue = settings.accessToken
        selectHotkey(side: settings.hotkeySide)
        maxSecondsField.stringValue = String(settings.maxRecordSeconds)
        retentionDaysField.stringValue = String(settings.logRetentionDays)
        keepClipboardButton.state = settings.keepTranscriptionInClipboard ? .on : .off
        launchAtLoginButton.state = settings.launchAtLogin ? .on : .off
        enableDDCButton.state = settings.enableDDC ? .on : .off
        hotwordsField.stringValue = settings.hotwords.joined(separator: ", ")
    }

    private func selectHotkey(side: HotkeySide) {
        for item in hotkeyPopup.itemArray {
            if let value = item.representedObject as? String, value == side.rawValue {
                hotkeyPopup.select(item)
                return
            }
        }
        hotkeyPopup.selectItem(at: 0)
    }

    @objc private func handleSave() {
        let old = getSettings()
        let appID = appIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessToken = accessTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        let rawSide = (hotkeyPopup.selectedItem?.representedObject as? String) ?? HotkeySide.right.rawValue
        let hotkeySide = HotkeySide(rawValue: rawSide) ?? .right

        let maxSeconds = max(30, Int(maxSecondsField.stringValue) ?? old.maxRecordSeconds)
        let retentionDays = max(1, Int(retentionDaysField.stringValue) ?? old.logRetentionDays)
        let keepClipboard = keepClipboardButton.state == .on
        let launchAtLogin = launchAtLoginButton.state == .on
        let enableDDC = enableDDCButton.state == .on
        let hotwords = parseHotwords(hotwordsField.stringValue)

        let settings = AppSettings(
            appID: appID,
            accessToken: accessToken,
            hotkeySide: hotkeySide,
            maxRecordSeconds: maxSeconds,
            keepTranscriptionInClipboard: keepClipboard,
            launchAtLogin: launchAtLogin,
            logRetentionDays: retentionDays,
            enableDDC: enableDDC,
            hotwords: hotwords
        )

        onSave(settings)
        close()
    }

    private func parseHotwords(_ raw: String) -> [String] {
        raw
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
