import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: HostsStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            Rule()
            HStack(spacing: 0) {
                Sidebar().frame(width: 240)
                Rule(vertical: true)
                if store.mode == .edit { EditorPane() } else { ViewPane() }
            }
            Rule()
            StatusBar()
        }
        .background(Theme.window)
        .ignoresSafeArea()
        .frame(minWidth: 960, minHeight: 600)
        .preferredColorScheme(.dark)
    }
}

// MARK: - chrome

struct Rule: View {
    var vertical = false
    var body: some View {
        Rectangle().fill(Theme.border)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}

struct TopBar: View {
    @EnvironmentObject var store: HostsStore

    var body: some View {
        HStack(spacing: 14) {
            Spacer().frame(width: 62)   // traffic lights
            HStack(spacing: 9) {
                HatShape().stroke(Theme.accent, style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
                    .frame(width: 20, height: 20)
                FadingTitle()
            }
            .frame(width: 220, alignment: .leading)
            Spacer()
            ModeSwitch()
            Spacer()
            SearchField().frame(width: 200)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Theme.side)
    }
}

/// The name, which every fifteen seconds slowly becomes its own anagram:
/// HostsWitch ⇄ HostSwitch.
struct FadingTitle: View {
    @State private var witch = true
    private let tick = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .leading) {
            Text("HostsWitch").opacity(witch ? 1 : 0)
            Text("HostSwitch").opacity(witch ? 0 : 1)
        }
        .font(Theme.serif(22)).foregroundStyle(Theme.text)
        .accessibilityLabel("HostsWitch")
        .onReceive(tick) { _ in
            withAnimation(.easeInOut(duration: 2.5)) { witch.toggle() }
        }
    }
}

struct ModeSwitch: View {
    @EnvironmentObject var store: HostsStore
    var body: some View {
        HStack(spacing: 2) {
            segment("Edit Hosts", "pencil", .edit)
            segment("View Hosts", "eye", .view)
        }
        .padding(2)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: 7))
    }
    private func segment(_ label: String, _ icon: String, _ mode: ViewMode) -> some View {
        let on = store.mode == mode
        return Button { withAnimation(.easeOut(duration: 0.12)) { store.mode = mode } } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(Theme.ui(12, weight: .medium))
            }
            .foregroundStyle(on ? Theme.text : Theme.muted)
            .padding(.horizontal, 10).frame(height: 24)
            .background(on ? Theme.selected : .clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @EnvironmentObject var store: HostsStore
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.faint)
            TextField("Search hosts", text: $store.searchText)
                .textFieldStyle(.plain).font(Theme.ui(12)).foregroundStyle(Theme.text)
            if !store.searchText.isEmpty {
                Button { store.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(Theme.faint)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9).frame(height: 26)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
    }
}

struct StatusBar: View {
    @EnvironmentObject var store: HostsStore
    var body: some View {
        HStack {
            if store.mode == .edit {
                Text("\(store.activeCount) active · \(store.allNodes.count) nodes")
                if store.paused {
                    Text("· paused").foregroundStyle(Theme.accent)
                }
            } else {
                Text("watching /etc/hosts")
            }
            Spacer()
            if let err = store.lastError {
                Text(err).foregroundStyle(Theme.accent).lineLimit(1).truncationMode(.middle)
            } else if store.mode == .edit {
                Text(store.lastApplied.map { "last cast \($0.formatted(date: .omitted, time: .shortened))" } ?? "nothing cast yet")
                if !store.canWriteDirectly {
                    Text("· asks for your password").foregroundStyle(Theme.faint)
                }
            } else {
                Text("changes outside HostsWitch appear live")
            }
        }
        .font(Theme.mono(11)).foregroundStyle(Theme.muted)
        .padding(.horizontal, 14).frame(height: 26)
        .background(Theme.side)
    }
}

// MARK: - sidebar

struct Sidebar: View {
    @EnvironmentObject var store: HostsStore
    @State private var collapsed: Set<UUID> = []
    @State private var renamingID: UUID?
    @State private var renameText = ""
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your hosts").font(Theme.serifItalic(17)).foregroundStyle(Theme.muted)
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(store.items) { item in
                        switch item {
                        case .node(let n):
                            if store.matches(n) { nodeRow(n, indent: false) }
                        case .group(let g):
                            let visible = g.nodes.filter(store.matches)
                            if !visible.isEmpty || store.searchText.isEmpty {
                                groupHeader(g)
                                if !collapsed.contains(g.id) {
                                    ForEach(visible) { nodeRow($0, indent: true) }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
            }
            Rule()
            footer
        }
        .background(Theme.side)
        .alert("Delete “\(store.locate(store.selectedID)?.0.name ?? "")”?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { if let id = store.selectedID { store.delete(id) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Its entries are removed from /etc/hosts if it is active. This cannot be undone.") }
    }

    private func groupHeader(_ g: HostGroup) -> some View {
        HStack(spacing: 6) {
            Image(systemName: collapsed.contains(g.id) ? "chevron.right" : "chevron.down")
                .font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.faint).frame(width: 10)
            if renamingID == g.id {
                renameField(g.id)
            } else {
                Text(g.name.uppercased()).font(Theme.ui(11, weight: .semibold)).tracking(0.9)
                    .foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer()
            if !g.exclusive {
                Text("multi").font(Theme.ui(9, weight: .semibold)).foregroundStyle(Theme.faint)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.border))
            }
        }
        .padding(.leading, 4).padding(.trailing, 8).padding(.top, 12).padding(.bottom, 4)
        .contentShape(Rectangle())
        .onTapGesture { if collapsed.contains(g.id) { collapsed.remove(g.id) } else { collapsed.insert(g.id) } }
        .contextMenu {
            Button("Rename Group…") { beginRename(g.id, g.name) }
            Button("New Node in Group") { store.addNode(inGroup: g.id) }
            Toggle("One Active Node at a Time", isOn: Binding(
                get: { g.exclusive }, set: { store.setExclusive(g.id, $0) }))
            Divider()
            Button("Move Up") { store.move(g.id, by: -1) }
            Button("Move Down") { store.move(g.id, by: 1) }
            Divider()
            Button("Delete Group", role: .destructive) { store.select(g.nodes.first?.id ?? store.selectedID); deleteGroup(g) }
        }
    }

    private func deleteGroup(_ g: HostGroup) {
        store.delete(g.id)
    }

    private func nodeRow(_ n: HostNode, indent: Bool) -> some View {
        let selected = store.selectedID == n.id
        return HStack(spacing: 10) {
            if renamingID == n.id {
                renameField(n.id)
            } else {
                Text(n.name).font(Theme.ui(13, weight: n.isActive ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.white : Theme.text).lineLimit(1)
            }
            Spacer(minLength: 4)
            GlowToggle(isOn: Binding(get: { n.isActive }, set: { store.setActive(n.id, $0) }))
        }
        .padding(.vertical, 5).padding(.leading, indent ? 18 : 10).padding(.trailing, 8)
        .background(selected ? Theme.selected : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { beginRename(n.id, n.name) }
        .onTapGesture { store.select(n.id) }
        .contextMenu {
            Button("Rename…") { beginRename(n.id, n.name) }
            Button(n.isActive ? "Switch Off" : "Switch On") { store.setActive(n.id, !n.isActive) }
            Divider()
            Button("Move Up") { store.move(n.id, by: -1) }
            Button("Move Down") { store.move(n.id, by: 1) }
            Divider()
            Button("Delete", role: .destructive) { store.select(n.id); confirmDelete = true }
        }
    }

    private func beginRename(_ id: UUID, _ name: String) {
        renameText = name
        renamingID = id
    }

    private func renameField(_ id: UUID) -> some View {
        TextField("Name", text: $renameText)
            .textFieldStyle(.plain).font(Theme.ui(13)).foregroundStyle(Theme.text)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 4))
            .onSubmit { store.rename(id, to: renameText); renamingID = nil }
            .onExitCommand { renamingID = nil }
    }

    private var footer: some View {
        HStack(spacing: 2) {
            Menu {
                Button("New Node") { store.addNode() }
                if store.selectedGroup != nil {
                    Button("New Node at Top Level") { store.addNode(inGroup: nil); }
                }
                Button("New Group") { store.addGroup() }
            } label: {
                Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28)
            Button { if store.selectedID != nil { confirmDelete = true } } label: {
                Image(systemName: "minus").font(.system(size: 12, weight: .semibold)).frame(width: 28, height: 26)
            }
            .buttonStyle(.plain).disabled(store.selectedID == nil)
            Spacer()
            Menu {
                if let n = store.selectedNode {
                    Button("Rename “\(n.name)”…") { beginRename(n.id, n.name) }
                    if let g = store.selectedGroup {
                        Toggle("One Active Node in “\(g.name)”", isOn: Binding(
                            get: { g.exclusive }, set: { store.setExclusive(g.id, $0) }))
                    }
                    Divider()
                }
                Toggle("Pause HostsWitch", isOn: Binding(get: { store.paused }, set: { store.setPaused($0) }))
                Divider()
                SettingsLink { Text("Settings…") }
            } label: {
                Image(systemName: "gearshape").font(.system(size: 12, weight: .semibold))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28)
        }
        .foregroundStyle(Theme.muted)
        .padding(.horizontal, 6).frame(height: 34)
    }
}

/// The ember switch from the mockup: glows when on.
struct GlowToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button { isOn.toggle() } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Theme.accent : Theme.offTrack).frame(width: 30, height: 17)
                Circle().fill(.white).frame(width: 13, height: 13).padding(2)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
            }
            .shadow(color: isOn ? Theme.accent.opacity(0.6) : .clear, radius: 6)
            .animation(.easeOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "On" : "Off")
    }
}

// MARK: - editor

struct EditorPane: View {
    @EnvironmentObject var store: HostsStore

    var body: some View {
        if let node = store.selectedNode {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if let g = store.selectedGroup {
                            Text(g.name).font(Theme.serif(22, weight: .regular)).foregroundStyle(Theme.muted)
                            Text("›").font(Theme.serif(22, weight: .regular)).foregroundStyle(Theme.faint)
                        }
                        Text(node.name).font(Theme.serif(22)).foregroundStyle(Theme.text)
                    }
                    Pill(node.isActive ? "Active" : "Off", dot: node.isActive ? Theme.accent : Theme.faint,
                         color: node.isActive ? Theme.accent : Theme.muted, glow: node.isActive)
                    Spacer()
                    Text("\(node.entryCount) \(node.entryCount == 1 ? "entry" : "entries") · \(store.isDirty ? "edited" : "saved")")
                        .font(Theme.ui(12)).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 10)

                VStack(spacing: 0) {
                    if store.findVisible {
                        FindReplaceBar()
                        Rule()
                    }
                    HostsTextView(text: $store.draft,
                                  pendingSelection: $store.pendingSelection,
                                  onSelectionChange: { store.editorSelection = $0 })
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                .padding(.horizontal, 22)

                HStack(spacing: 10) {
                    (Text("One entry per line: IP, then hostnames. ")
                     + Text("#").font(Theme.mono(12)) + Text(" starts a comment."))
                        .font(Theme.ui(12)).foregroundStyle(Theme.faint)
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { store.findVisible.toggle() }
                    } label: {
                        Label("Find & Replace", systemImage: "text.magnifyingglass")
                            .font(Theme.ui(12, weight: .medium))
                            .foregroundStyle(store.findVisible ? Theme.accent : Theme.muted)
                    }
                    .buttonStyle(.plain)
                    .help("Find & Replace (⌥⌘F)")
                    Spacer()
                    if let flash = store.castFlash {
                        CastBadge(flash: flash)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                    Button("Revert") { store.revertDraft() }
                        .buttonStyle(CovenButton()).disabled(!store.isDirty)
                    Button("Cast") { store.cast() }
                        .buttonStyle(CovenButton(primary: true)).keyboardShortcut("s")
                }
                .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 18)
            }
            .background(Theme.window)
        } else {
            VStack(spacing: 12) {
                HatShape().stroke(Theme.faint, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 44, height: 44)
                Text("No hosts yet").font(Theme.serif(24)).foregroundStyle(Theme.muted)
                Text("Add a node or a group with the + button.").font(Theme.ui(13)).foregroundStyle(Theme.faint)
                Button("New Node") { store.addNode() }.buttonStyle(CovenButton(primary: true))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.window)
        }
    }
}

/// Feedback after Cast: a pill that lingers a few seconds then fades.
struct CastBadge: View {
    let flash: CastFlash
    var body: some View {
        switch flash {
        case .cast:
            Pill("Cast · /etc/hosts written", icon: "sparkles", color: Theme.accent, glow: true)
        case .unchanged:
            Pill("Nothing to cast · file already matches", icon: "checkmark", color: Theme.muted)
        case .failed:
            Pill("Cast failed", icon: "exclamationmark.triangle", color: Theme.accent)
        }
    }
}

/// Find & replace, sitting above the editor.
struct FindReplaceBar: View {
    @EnvironmentObject var store: HostsStore
    @FocusState private var focused: Field?
    enum Field { case find, replace }

    var body: some View {
        let matches = store.findMatches
        HStack(spacing: 8) {
            field("Find", text: $store.findText, icon: "magnifyingglass", field: .find)
                .onSubmit { store.findNext(from: store.editorSelection, backwards: NSEvent.modifierFlags.contains(.shift)) }
            Text(store.findText.isEmpty ? "" : (matches.isEmpty ? "no matches" : "\(matches.count) \(matches.count == 1 ? "match" : "matches")"))
                .font(Theme.mono(11)).foregroundStyle(matches.isEmpty && !store.findText.isEmpty ? Theme.accent : Theme.faint)
                .frame(width: 84, alignment: .leading)
            HStack(spacing: 1) {
                small("chevron.up") { store.findNext(from: store.editorSelection, backwards: true) }
                small("chevron.down") { store.findNext(from: store.editorSelection) }
            }
            .disabled(matches.isEmpty)
            field("Replace", text: $store.replaceText, icon: "arrow.right", field: .replace)
                .onSubmit { store.replaceOne(at: store.editorSelection) }
            Button("Replace") { store.replaceOne(at: store.editorSelection) }
                .buttonStyle(SmallCovenButton()).disabled(matches.isEmpty)
            Button("All") { store.replaceAll() }
                .buttonStyle(SmallCovenButton()).disabled(matches.isEmpty)
            small("xmark") { withAnimation(.easeOut(duration: 0.15)) { store.findVisible = false } }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 10).frame(height: 38)
        .background(Theme.side)
        .onAppear { focused = .find }
    }

    private func field(_ placeholder: String, text: Binding<String>, icon: String, field: Field) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.faint)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain).font(Theme.mono(12)).foregroundStyle(Theme.text)
                .focused($focused, equals: field)
        }
        .padding(.horizontal, 8).frame(height: 26).frame(maxWidth: .infinity)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(focused == field ? Theme.accent.opacity(0.7) : Theme.border))
    }

    private func small(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.muted).frame(width: 24, height: 24)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}

struct SmallCovenButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(12, weight: .medium)).foregroundStyle(Theme.text)
            .padding(.horizontal, 10).frame(height: 24)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.border))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

// MARK: - live file

struct ViewPane: View {
    @EnvironmentObject var store: HostsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("/etc/hosts").font(Theme.mono(20)).foregroundStyle(Theme.text)
                Pill("Read-only", icon: "lock", color: Theme.muted)
                Spacer()
                Text("\(store.liveHosts.split(separator: "\n", omittingEmptySubsequences: false).count) lines"
                     + (store.lastApplied.map { " · written by HostsWitch at \($0.formatted(date: .omitted, time: .shortened))" } ?? ""))
                    .font(Theme.ui(12)).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 10)

            HostsTextView(text: .constant(store.liveHosts), isEditable: false, showManaged: true)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                .padding(.horizontal, 22)

            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3).fill(Theme.highlight)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.border)).frame(width: 12, height: 12)
                Text("The block HostsWitch manages · everything else is left untouched")
                    .font(Theme.ui(12)).foregroundStyle(Theme.muted)
                Spacer()
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([HostsFile.url])
                }.buttonStyle(CovenButton())
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.liveHosts, forType: .string)
                }.buttonStyle(CovenButton())
            }
            .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 18)
        }
        .background(Theme.window)
        .onAppear { store.reloadLive() }
    }
}

// MARK: - bits

struct Pill: View {
    let label: String
    var icon: String? = nil
    var dot: Color? = nil
    var color: Color
    var glow = false

    init(_ label: String, icon: String? = nil, dot: Color? = nil, color: Color, glow: Bool = false) {
        self.label = label; self.icon = icon; self.dot = dot; self.color = color; self.glow = glow
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.system(size: 9, weight: .bold)) }
            if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
            Text(label).font(Theme.ui(11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9).padding(.vertical, 3)
        .overlay(Capsule().stroke(glow ? color : Theme.border))
        .shadow(color: glow ? color.opacity(0.4) : .clear, radius: 6)
    }
}

struct CovenButton: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(13, weight: primary ? .semibold : .medium))
            .foregroundStyle(primary ? Theme.onAccent : Theme.text)
            .padding(.horizontal, 16).frame(height: 30).frame(minWidth: 84)
            .background(primary ? Theme.accent : Theme.field, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(primary ? Theme.accent : Theme.border))
            .shadow(color: primary ? Theme.accent.opacity(0.4) : .clear, radius: 8)
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
    }
}

// MARK: - settings

struct SettingsView: View {
    @EnvironmentObject var store: HostsStore

    var body: some View {
        Form {
            Section("Writing /etc/hosts") {
                if store.canWriteDirectly {
                    Text("HostsWitch owns /etc/hosts and writes it without a password.")
                    Button("Give /etc/hosts back to root") { store.takeOwnership(false) }
                } else {
                    Text("Each cast asks for your administrator password. Let HostsWitch own the file to skip that — a single prompt, now.")
                    Button("Let HostsWitch own /etc/hosts…") { store.takeOwnership(true) }
                }
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { store.launchesAtLogin }, set: { store.setLaunchAtLogin($0) }))
                Text("When launched at login, HostsWitch stays in the menu bar and does not open its window.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Safety") {
                Text("The first cast saved a copy of the untouched file.")
                HStack {
                    Button("Show Backup in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.backupURL])
                    }
                    Button("Restore Original…") { restore = true }
                }
                Toggle("Pause HostsWitch (leave /etc/hosts as the system had it)", isOn: Binding(
                    get: { store.paused }, set: { store.setPaused($0) }))
            }
            if let err = store.lastError {
                Section("Last error") { Text(err).foregroundStyle(Theme.accent) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .alert("Restore the original /etc/hosts?", isPresented: $restore) {
            Button("Restore", role: .destructive) { store.restoreOriginal() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Every node is switched off and the file goes back to the copy taken before the first cast.") }
    }
    @State private var restore = false
}
