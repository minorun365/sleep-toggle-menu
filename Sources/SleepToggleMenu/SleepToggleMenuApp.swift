import AppKit
import Foundation
import SleepToggleCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let deadlineKey = "keepAwakeDeadline"

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var refreshTimer: Timer?
    private var currentPermission: SleepPermission = .unknown
    private var isChanging = false
    private var autoRevertErrorShown = false

    /// 自動で戻す時刻。アプリやMacを再起動しても引き継ぐため UserDefaults に置く。
    private var deadline: Date? {
        get { UserDefaults.standard.object(forKey: Self.deadlineKey) as? Date }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: Self.deadlineKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.deadlineKey)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        refreshState()

        refreshTimer = Timer.scheduledTimer(
            timeInterval: 3,
            target: self,
            selector: #selector(refreshState),
            userInfo: nil,
            repeats: true
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refreshState),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)

        // 期限を見張る者がいなくなるので、起動維持のまま終わらせない。
        if PowerManagement.currentPermission() == .prohibited {
            try? PowerManagement.setSleepProhibited(false)
        }
        if PowerManagement.currentPermission() == .allowed {
            deadline = nil
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu(for: event)
        } else {
            toggleSleepPermission()
        }
    }

    private func showContextMenu(for event: NSEvent) {
        guard let button = statusItem.button else { return }

        let menu = NSMenu()
        for line in statusLines {
            let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let canChange = !isChanging && currentPermission != .unknown

        if currentPermission == .prohibited {
            let revert = NSMenuItem(
                title: "通常へ戻す",
                action: #selector(revertFromMenu),
                keyEquivalent: ""
            )
            revert.target = self
            revert.isEnabled = canChange
            menu.addItem(revert)
        }

        for duration in KeepAwakeDuration.choices {
            let label = RemainingTimeFormatter.duration(duration)
            let title = currentPermission == .prohibited
                ? "いまから\(label)に延長"
                : "\(label)だけ起動維持にする"
            let item = NSMenuItem(
                title: title,
                action: #selector(keepAwakeFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = duration
            item.isEnabled = canChange
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "終了（スリープ可能に戻します）",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    @objc private func revertFromMenu() {
        changeSleepPermission(prohibit: false, deadline: nil)
    }

    @objc private func keepAwakeFromMenu(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? TimeInterval else { return }
        keepAwake(for: duration)
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    private func toggleSleepPermission() {
        switch currentPermission {
        case .prohibited:
            changeSleepPermission(prohibit: false, deadline: nil)
        case .allowed:
            keepAwake(for: KeepAwakeDuration.defaultDuration)
        case .unknown:
            showError("現在のスリープ設定を取得できません。")
        }
    }

    private func keepAwake(for duration: TimeInterval) {
        let newDeadline = Date().addingTimeInterval(duration)

        // すでに起動維持中なら、期限を付け替えるだけでよい。
        if currentPermission == .prohibited {
            deadline = newDeadline
            updateAppearance()
            return
        }

        changeSleepPermission(prohibit: true, deadline: newDeadline)
    }

    private func changeSleepPermission(
        prohibit: Bool,
        deadline newDeadline: Date?,
        showsError: Bool = true
    ) {
        guard !isChanging else { return }

        isChanging = true
        updateAppearance()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<Void, Error>
            do {
                try PowerManagement.setSleepProhibited(prohibit)
                result = .success(())
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.isChanging = false

                switch result {
                case .success:
                    self.deadline = newDeadline
                    self.autoRevertErrorShown = false
                case let .failure(error):
                    if showsError {
                        self.showError(error.localizedDescription)
                    }
                }
                self.refreshState()
            }
        }
    }

    @objc private func refreshState() {
        guard !isChanging else { return }
        currentPermission = PowerManagement.currentPermission()

        switch AutoRevertPolicy.action(
            permission: currentPermission,
            deadline: deadline,
            now: Date()
        ) {
        case .none:
            break
        case let .assignDeadline(newDeadline):
            deadline = newDeadline
        case .clearDeadline:
            deadline = nil
        case .revert:
            // 失敗しても3秒ごとに再試行する。警告は1回だけ出し、毎回は出さない。
            let showsError = !autoRevertErrorShown
            autoRevertErrorShown = true
            changeSleepPermission(prohibit: false, deadline: nil, showsError: showsError)
            return
        }

        updateAppearance()
    }

    private var remaining: TimeInterval? {
        deadline.map { $0.timeIntervalSinceNow }
    }

    private func updateAppearance() {
        if isChanging {
            showText("… 切替中", tooltip: "スリープ設定を変更しています")
            return
        }

        switch currentPermission {
        case .prohibited:
            let countdown = remaining.map { " " + RemainingTimeFormatter.short($0) } ?? ""
            showText("🔥" + countdown, tooltip: "スリープ禁止中。時間が来ると自動で通常へ戻ります。左クリックですぐ戻します")
        case .allowed:
            showSymbol("flame.fill", fallback: "○", tooltip: "スリープ可能。左クリックで1時間だけ起動維持にします")
        case .unknown:
            showText("? スリープ", tooltip: "スリープ設定を取得できません")
        }
    }

    private func showText(_ text: String, tooltip: String) {
        guard let button = statusItem.button else { return }

        // 3秒ごとの再描画で同じ値を入れ直すと、ツールチップが出し直されてカーソルに付いて回る。
        // 変わったときだけ書き換える。
        if button.image != nil { button.image = nil }
        shownSymbolName = nil
        if button.title != text { button.title = text }
        setToolTip(tooltip, on: button)
    }

    private func setToolTip(_ tooltip: String, on button: NSStatusBarButton) {
        if button.toolTip != tooltip { button.toolTip = tooltip }
    }

    private func showSymbol(_ name: String, fallback: String, tooltip: String) {
        guard let button = statusItem.button else { return }
        if shownSymbolName == name, button.image != nil {
            setToolTip(tooltip, on: button)
            return
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else {
            showText(fallback, tooltip: tooltip)
            return
        }

        image.isTemplate = true
        button.image = image
        button.title = ""
        shownSymbolName = name
        setToolTip(tooltip, on: button)
    }

    private var shownSymbolName: String?

    private var statusLines: [String] {
        switch currentPermission {
        case .prohibited:
            guard let deadline else { return ["現在：スリープ禁止"] }
            let time = deadline.formatted(date: .omitted, time: .shortened)
            let left = RemainingTimeFormatter.duration(max(0, deadline.timeIntervalSinceNow))
            return ["現在：スリープ禁止", "\(time)に自動で戻します（あと\(left)）"]
        case .allowed:
            return ["現在：スリープ可能"]
        case .unknown:
            return ["現在：状態を取得できません"]
        }
    }

    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "スリープ設定を変更できませんでした"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

@main
struct SleepToggleMenuApplication {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
