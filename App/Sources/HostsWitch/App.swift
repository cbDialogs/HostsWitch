import SwiftUI

/// Keeps the window closed when the system launched us as a login item;
/// the menu-bar hat is all that's wanted then.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let launchedAtLogin = event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if launchedAtLogin {
            for w in NSApp.windows where w.identifier?.rawValue == "main" { w.close() }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { true }
}

@main
struct HostsWitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store: HostsStore
    @Environment(\.openWindow) private var openWindow

    init() {
        Theme.registerFonts()
        // The app paints one moonlit theme; keep AppKit's own chrome
        // (menus, find bar, alerts) dark to match.
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        _store = StateObject(wrappedValue: HostsStore())
    }

    var body: some Scene {
        Window("HostsWitch", id: "main") {
            ContentView().environmentObject(store)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1216, height: 764)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Node") { store.addNode() }.keyboardShortcut("n")
                Button("New Group") { store.addGroup() }.keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button("Cast (Apply to /etc/hosts)") { store.cast() }.keyboardShortcut("s")
                Button("Revert Edits") { store.revertDraft() }
                    .keyboardShortcut("r", modifiers: [.command, .shift]).disabled(!store.isDirty)
            }
            CommandGroup(after: .textEditing) {
                Button("Find & Replace…") {
                    show(.edit)
                    store.findVisible = true
                }.keyboardShortcut("f", modifiers: [.command, .option])
            }
            CommandGroup(after: .sidebar) {
                Button("Edit Hosts") { show(.edit) }.keyboardShortcut("e")
                Button("View Hosts") { show(.view) }.keyboardShortcut("v", modifiers: [.command, .shift])
                Divider()
            }
            CommandMenu("Hosts") {
                Toggle("Pause HostsWitch", isOn: Binding(get: { store.paused }, set: { store.setPaused($0) }))
                Divider()
                Button("Reveal /etc/hosts in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([HostsFile.url])
                }
                Button("Show Backup in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([store.backupURL])
                }
            }
        }

        Settings {
            SettingsView().environmentObject(store)
        }

        MenuBarExtra {
            MenuBarMenu(show: show).environmentObject(store)
        } label: {
            Image(nsImage: Theme.menuBarIcon)
        }
    }

    private func show(_ mode: ViewMode) {
        store.mode = mode
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// The dropdown: every node as a checkmarked item, groups as sections.
struct MenuBarMenu: View {
    @EnvironmentObject var store: HostsStore
    let show: (ViewMode) -> Void

    var body: some View {
        ForEach(store.items) { item in
            switch item {
            case .node(let n): toggle(n)
            case .group(let g):
                Section(g.name) { ForEach(g.nodes) { toggle($0) } }
            }
        }
        Divider()
        Button("View Hosts") { show(.view) }.keyboardShortcut("v", modifiers: [.command, .shift])
        Button("Edit Hosts…") { show(.edit) }.keyboardShortcut("e")
        Divider()
        Toggle("Pause HostsWitch", isOn: Binding(get: { store.paused }, set: { store.setPaused($0) }))
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit HostsWitch") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }

    private func toggle(_ n: HostNode) -> some View {
        Toggle(n.name, isOn: Binding(get: { n.isActive }, set: { store.setActive(n.id, $0) }))
    }
}
