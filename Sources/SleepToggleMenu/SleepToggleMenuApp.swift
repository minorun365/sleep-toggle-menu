import AppKit
import Foundation
import SleepToggleCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var refreshTimer: Timer?
    private var currentPermission: SleepPermission = .unknown
    private var isChanging = false

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
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
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
        let status = NSMenuItem(
            title: statusDescription,
            action: nil,
            keyEquivalent: ""
        )
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let toggle = NSMenuItem(
            title: toggleActionTitle,
            action: #selector(toggleFromMenu),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.isEnabled = !isChanging && currentPermission != .unknown
        menu.addItem(toggle)
        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "終了",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    @objc private func toggleFromMenu() {
        toggleSleepPermission()
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    private func toggleSleepPermission() {
        guard !isChanging else { return }

        let shouldProhibit: Bool
        switch currentPermission {
        case .prohibited:
            shouldProhibit = false
        case .allowed:
            shouldProhibit = true
        case .unknown:
            showError("現在のスリープ設定を取得できません。")
            return
        }

        isChanging = true
        updateAppearance()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<Void, Error>
            do {
                try PowerManagement.setSleepProhibited(shouldProhibit)
                result = .success(())
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.isChanging = false
                self.refreshState()

                if case let .failure(error) = result {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    @objc private func refreshState() {
        guard !isChanging else { return }
        currentPermission = PowerManagement.currentPermission()
        updateAppearance()
    }

    private func updateAppearance() {
        if isChanging {
            showText("… 切替中", tooltip: "スリープ設定を変更しています")
            return
        }

        switch currentPermission {
        case .prohibited:
            showText("🔥", tooltip: "スリープ禁止中。左クリックで通常へ戻します")
        case .allowed:
            showSymbol("flame.fill", fallback: "○", tooltip: "スリープ可能。左クリックで起動維持へ切り替えます")
        case .unknown:
            showText("? スリープ", tooltip: "スリープ設定を取得できません")
        }
    }

    private func showText(_ text: String, tooltip: String) {
        guard let button = statusItem.button else { return }

        button.image = nil
        button.title = text
        button.toolTip = tooltip
    }

    private func showSymbol(_ name: String, fallback: String, tooltip: String) {
        guard let button = statusItem.button else { return }

        let configuration = NSImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else {
            showText(fallback, tooltip: tooltip)
            return
        }

        image.isTemplate = true
        button.image = image
        button.title = ""
        button.toolTip = tooltip
    }

    private var statusDescription: String {
        switch currentPermission {
        case .prohibited:
            return "現在：スリープ禁止"
        case .allowed:
            return "現在：スリープ可能"
        case .unknown:
            return "現在：状態を取得できません"
        }
    }

    private var toggleActionTitle: String {
        switch currentPermission {
        case .prohibited:
            return "通常へ戻す"
        case .allowed:
            return "起動維持にする"
        case .unknown:
            return "切り替え不可"
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
