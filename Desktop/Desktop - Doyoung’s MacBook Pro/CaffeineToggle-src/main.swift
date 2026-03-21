import SwiftUI
import AppKit
import ServiceManagement

// MARK: - Icon Style

enum IconStyle: String, CaseIterable {
    case coffeeMoon = "coffeeMoon"
    case sunMoon    = "sunMoon"
    case boltSlash  = "boltSlash"

    var activeSymbol: String {
        switch self {
        case .coffeeMoon: "cup.and.saucer.fill"
        case .sunMoon:    "sun.max.fill"
        case .boltSlash:  "bolt.fill"
        }
    }
    var inactiveSymbol: String {
        switch self {
        case .coffeeMoon: "moon.zzz.fill"
        case .sunMoon:    "moon.fill"
        case .boltSlash:  "bolt.slash.fill"
        }
    }
    var label: String {
        switch self {
        case .coffeeMoon: "커피 / 달 (기본)"
        case .sunMoon:    "태양 / 달"
        case .boltSlash:  "번개"
        }
    }
}

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable {
    case status     = "상태"
    case appearance = "외관"
    case general    = "일반"
    case about      = "정보"

    var icon: String {
        switch self {
        case .status:     "bolt.fill"
        case .appearance: "eye.fill"
        case .general:    "gearshape.fill"
        case .about:      "info.circle.fill"
        }
    }
}

// MARK: - Caffeine Manager

@MainActor
class CaffeineManager: ObservableObject {
    static let shared = CaffeineManager()
    @Published var isActive = false
    @Published var isLoading = false
    private let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/com.user.caffeinate.plist"

    private init() { refresh() }

    func toggle() {
        isLoading = true
        run(isActive ? "launchctl unload '\(plistPath)'" : "launchctl load '\(plistPath)'")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.refresh()
            self.isLoading = false
        }
    }

    func refresh() {
        let out = run("launchctl list 2>/dev/null | grep com.user.caffeinate")
        isActive = !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    func run(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", command]
        try? task.run()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}

// MARK: - Window State

@MainActor
class WindowState: ObservableObject {
    static let shared = WindowState()
    @Published var selectedTab: SettingsTab = .status
    private init() {}
}

// MARK: - AppDelegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var windowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        ProcessInfo.processInfo.disableAutomaticTermination("menu bar app")

        // NSStatusItem 직접 생성 — MenuBarExtra 없이
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        updateIcon()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Dock 아이콘 숨김 (1초 딜레이)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showWindow()
        return true
    }

    // MARK: NSMenuDelegate — 메뉴 열릴 때마다 재빌드

    func menuWillOpen(_ menu: NSMenu) {
        CaffeineManager.shared.refresh()
        menu.removeAllItems()
        buildMenu(into: menu)
    }

    func buildMenu(into menu: NSMenu) {
        let manager = CaffeineManager.shared

        let headerItem = NSMenuItem(title: manager.isActive ? "슬립 방지 켜짐" : "슬립 방지 꺼짐",
                                    action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: manager.isActive ? "끄기" : "켜기",
            action: #selector(toggleCaffeine),
            keyEquivalent: "t"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "열기", action: #selector(openWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: "설정...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "CaffeineToggle 종료", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    func menuDidClose(_ menu: NSMenu) {
        updateIcon()
    }

    // MARK: Actions

    @objc func toggleCaffeine() { CaffeineManager.shared.toggle() }
    @objc func openWindow()     { showWindow(tab: .status) }
    @objc func openSettings()   { showWindow(tab: .general) }
    @objc func quitApp()        { NSApp.terminate(nil) }

    func updateIcon() {
        let manager = CaffeineManager.shared
        let iconStyleRaw = UserDefaults.standard.string(forKey: "iconStyle") ?? IconStyle.coffeeMoon.rawValue
        let style = IconStyle(rawValue: iconStyleRaw) ?? .coffeeMoon
        let symbolName = manager.isActive ? style.activeSymbol : style.inactiveSymbol
        statusItem?.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "CaffeineToggle")
    }

    func showWindow(tab: SettingsTab = .status) {
        WindowState.shared.selectedTab = tab
        if let wc = windowController, let w = wc.window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = UnifiedWindowView(manager: CaffeineManager.shared, windowState: WindowState.shared)
        let hc = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hc)
        window.title = "CaffeineToggle"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        windowController = NSWindowController(window: window)
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Unified Window

private let contentHeight: CGFloat = 380

struct UnifiedWindowView: View {
    @ObservedObject var manager: CaffeineManager
    @ObservedObject var windowState: WindowState

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            ZStack {
                StatusTabView(manager: manager)
                    .opacity(windowState.selectedTab == .status ? 1 : 0)
                AppearanceTabView()
                    .opacity(windowState.selectedTab == .appearance ? 1 : 0)
                GeneralTabView()
                    .opacity(windowState.selectedTab == .general ? 1 : 0)
                AboutTabView()
                    .opacity(windowState.selectedTab == .about ? 1 : 0)
            }
            .frame(width: 480, height: contentHeight)
        }
        .frame(width: 480)
    }

    var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tabButton($0) }
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    func tabButton(_ tab: SettingsTab) -> some View {
        let sel = windowState.selectedTab == tab
        return Button { windowState.selectedTab = tab } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: sel ? .semibold : .regular))
                    .frame(height: 26)
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: sel ? .medium : .regular))
            }
            .foregroundStyle(sel ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(sel ? Color.accentColor.opacity(0.12) : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status Tab

struct StatusTabView: View {
    @ObservedObject var manager: CaffeineManager
    @AppStorage("iconStyle") private var iconStyleRaw = IconStyle.coffeeMoon.rawValue
    private var iconStyle: IconStyle { IconStyle(rawValue: iconStyleRaw) ?? .coffeeMoon }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(manager.isActive ? Color.orange.opacity(0.15) : Color.indigo.opacity(0.12))
                        .frame(width: 100, height: 100)
                    if manager.isLoading {
                        ProgressView().scaleEffect(1.3)
                    } else {
                        Image(systemName: manager.isActive ? iconStyle.activeSymbol : iconStyle.inactiveSymbol)
                            .font(.system(size: 44))
                            .foregroundStyle(manager.isActive ? .orange : .indigo)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                VStack(spacing: 4) {
                    Text(manager.isActive ? "슬립 방지 켜짐" : "슬립 방지 꺼짐")
                        .font(.title3.weight(.semibold))
                    Text(manager.isActive ? "덮개를 닫아도 Mac이 깨어 있습니다" : "Mac이 정상적으로 절전됩니다")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 22)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            VStack(spacing: 0) {
                RowView(icon: "bolt.fill", color: .yellow, title: "슬립 방지",
                    sub: manager.isLoading ? "적용 중..." : (manager.isActive ? "현재 활성화됨" : "현재 비활성화됨")) {
                    Toggle("", isOn: Binding(get: { manager.isActive }, set: { _ in manager.toggle() }))
                        .labelsHidden().disabled(manager.isLoading)
                }
                Divider().padding(.leading, 52)
                RowView(icon: "gearshape.fill", color: .gray, title: "LaunchAgent", sub: "재시작 후에도 자동 실행") {
                    StatusBadge(active: manager.isActive, on: "활성화됨", off: "비활성화됨")
                }
                Divider().padding(.leading, 52)
                RowView(icon: "cpu", color: .blue, title: "caffeinate 프로세스", sub: "절전 방지 데몬") {
                    StatusBadge(active: manager.isActive, on: "실행 중", off: "중지됨")
                }
            }
            .padding(.vertical, 6)
        }
        .frame(width: 480, height: contentHeight)
    }
}

// MARK: - Appearance Tab

struct AppearanceTabView: View {
    @AppStorage("iconStyle") private var iconStyleRaw = IconStyle.coffeeMoon.rawValue
    @AppStorage("showMenuBarText") private var showMenuBarText = false
    private var iconStyle: IconStyle {
        get { IconStyle(rawValue: iconStyleRaw) ?? .coffeeMoon }
        nonmutating set { iconStyleRaw = newValue.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("메뉴바 아이콘")
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(IconStyle.allCases, id: \.self) { style in
                        Button { iconStyleRaw = style.rawValue } label: {
                            HStack(spacing: 10) {
                                Image(systemName: iconStyle == style ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(iconStyle == style ? Color.accentColor : .secondary)
                                Image(systemName: style.activeSymbol).frame(width: 20)
                                Image(systemName: style.inactiveSymbol).frame(width: 20)
                                Text(style.label)
                                Spacer()
                            }
                        }.buttonStyle(.plain)
                    }
                    Divider()
                    Toggle("상태 텍스트 표시 (ON / OFF)", isOn: $showMenuBarText)
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)

                SectionHeader("미리보기")
                HStack(spacing: 28) {
                    VStack(spacing: 6) {
                        Image(systemName: iconStyle.activeSymbol).font(.title).foregroundStyle(.orange)
                        Text("활성화").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 6) {
                        Image(systemName: iconStyle.inactiveSymbol).font(.title).foregroundStyle(.indigo)
                        Text("비활성화").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16).padding(.bottom, 16)
            }
            .padding(.top, 4)
        }
        .frame(width: 480, height: contentHeight)
    }
}

// MARK: - General Tab

struct GeneralTabView: View {
    @State private var launchAtLogin = isLoginItemEnabled()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("시작")
                Toggle("로그인 시 CaffeineToggle 실행", isOn: $launchAtLogin)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)
                    .onChange(of: launchAtLogin) { _, v in setLoginItem(enabled: v) }

                SectionHeader("동작")
                VStack(spacing: 0) {
                    InfoRow("슬립 방지 방식", "caffeinate -is")
                    Divider().padding(.leading, 16)
                    InfoRow("효과", "시스템 슬립 방지 (AC 전원)")
                    Divider().padding(.leading, 16)
                    InfoRow("화면 절전", "정상 동작 (덮개 닫으면 꺼짐)")
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16).padding(.bottom, 16)
            }
            .padding(.top, 4)
        }
        .frame(width: 480, height: contentHeight)
    }
}

// MARK: - About Tab

struct AboutTabView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 60)).foregroundStyle(.orange)
                .shadow(color: .orange.opacity(0.3), radius: 12, y: 4)
            VStack(spacing: 6) {
                Text("CaffeineToggle").font(.title2.weight(.bold))
                Text("버전 1.0").font(.callout).foregroundStyle(.secondary)
            }
            Text("맥북 덮개를 닫아도 Mac이 슬립되지 않도록\ncaffeinate LaunchAgent를 관리합니다.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(3)
            Spacer()
        }
        .frame(width: 480, height: contentHeight)
    }
}

// MARK: - Shared Components

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 4)
    }
}

struct InfoRow: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            Text(value).font(.callout).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

struct RowView<T: View>: View {
    let icon: String; let color: Color; let title: String; let sub: String
    @ViewBuilder let trailing: () -> T
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(color).frame(width: 30, height: 30)
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(sub).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

struct StatusBadge: View {
    let active: Bool; let on: String; let off: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(active ? Color.green : Color.secondary.opacity(0.5)).frame(width: 7, height: 7)
            Text(active ? on : off).foregroundStyle(active ? .green : .secondary).font(.subheadline)
        }
    }
}

private func isLoginItemEnabled() -> Bool {
    if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
    return false
}
private func setLoginItem(enabled: Bool) {
    guard #available(macOS 13.0, *) else { return }
    do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
    catch { print("Login item error: \(error)") }
}

// MARK: - App Entry Point
// MenuBarExtra 제거 → NSStatusItem 직접 사용 (macOS Tahoe 호환)
// Settings { EmptyView() } — 앱 프로토콜 만족용 빈 씬

@main
struct CaffeineToggleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}
