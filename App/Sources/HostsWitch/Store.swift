import SwiftUI
import Combine
import ServiceManagement

enum ViewMode { case edit, view }

enum CastFlash { case cast, unchanged, failed }

@MainActor
final class HostsStore: ObservableObject {
    @Published var items: [HostItem] { didSet { persist() } }
    @Published var paused: Bool { didSet { persist() } }
    @Published var selectedID: UUID?
    /// The editor's text for the selected node; committed on Cast.
    @Published var draft = ""
    @Published var mode: ViewMode = .edit
    @Published var liveHosts = ""
    @Published var lastApplied: Date?
    @Published var lastError: String?
    @Published var searchText = ""
    @Published var canWriteDirectly = HostsFile.isWritableDirectly
    /// A few seconds of feedback after Cast; cleared by a timer.
    @Published var castFlash: CastFlash?
    private var flashTask: Task<Void, Never>?

    // Find & replace in the editor.
    @Published var findVisible = false
    @Published var findText = ""
    @Published var replaceText = ""
    /// A selection the editor should apply on its next update (find results).
    @Published var pendingSelection: NSRange?
    /// Mirrors the editor's selection so find/replace knows where it is.
    var editorSelection = NSRange(location: 0, length: 0)

    private let supportDir: URL
    private let libraryURL: URL
    private var monitor: FileMonitor?
    private var suppressPersist = true

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        supportDir = base.appendingPathComponent("HostsWitch")
        libraryURL = supportDir.appendingPathComponent("library.json")
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)

        var lib = Library.starter
        if let data = try? Data(contentsOf: libraryURL),
           let saved = try? JSONDecoder().decode(Library.self, from: data) {
            lib = saved
        }
        items = lib.items
        paused = lib.paused
        lastApplied = UserDefaults.standard.object(forKey: "lastApplied") as? Date
        suppressPersist = false

        selectedID = firstNodeID
        loadDraft()
        reloadLive()
        installMonitor()
    }

    // MARK: - lookup

    var firstNodeID: UUID? {
        for item in items {
            switch item {
            case .node(let n): return n.id
            case .group(let g): if let n = g.nodes.first { return n.id }
            }
        }
        return nil
    }

    /// (node, group) for a node id; group is nil for top-level nodes.
    func locate(_ id: UUID?) -> (HostNode, HostGroup?)? {
        guard let id else { return nil }
        for item in items {
            switch item {
            case .node(let n) where n.id == id: return (n, nil)
            case .group(let g):
                if let n = g.nodes.first(where: { $0.id == id }) { return (n, g) }
            default: break
            }
        }
        return nil
    }

    var selectedNode: HostNode? { locate(selectedID)?.0 }
    var selectedGroup: HostGroup? { locate(selectedID)?.1 }
    var isDirty: Bool { (selectedNode?.content ?? "") != draft }

    var allNodes: [HostNode] {
        items.flatMap { item -> [HostNode] in
            switch item {
            case .node(let n): return [n]
            case .group(let g): return g.nodes
            }
        }
    }
    var activeCount: Int { allNodes.filter(\.isActive).count }

    /// Nodes matching the search field (by name or content).
    func matches(_ node: HostNode) -> Bool {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return node.name.localizedCaseInsensitiveContains(q)
            || node.content.localizedCaseInsensitiveContains(q)
    }

    // MARK: - mutation

    private func update(_ id: UUID, _ change: (inout HostNode) -> Void) {
        for i in items.indices {
            switch items[i] {
            case .node(var n) where n.id == id:
                change(&n); items[i] = .node(n); return
            case .group(var g):
                if let j = g.nodes.firstIndex(where: { $0.id == id }) {
                    change(&g.nodes[j]); items[i] = .group(g); return
                }
            default: break
            }
        }
    }

    func select(_ id: UUID?) {
        guard id != selectedID else { return }
        selectedID = id
        loadDraft()
    }

    private func loadDraft() {
        draft = selectedNode?.content ?? ""
    }

    func revertDraft() { loadDraft() }

    /// Switches a node on or off. In an exclusive group this also switches
    /// its siblings off. Writes /etc/hosts straight away.
    func setActive(_ id: UUID, _ on: Bool) {
        for i in items.indices {
            if case .group(var g) = items[i], g.nodes.contains(where: { $0.id == id }) {
                for j in g.nodes.indices {
                    if g.nodes[j].id == id { g.nodes[j].isActive = on }
                    else if on && g.exclusive { g.nodes[j].isActive = false }
                }
                items[i] = .group(g)
                apply(); return
            }
        }
        update(id) { $0.isActive = on }
        apply()
    }

    func isActive(_ id: UUID) -> Bool { locate(id)?.0.isActive ?? false }

    /// "Cast": commits the draft to its node and writes /etc/hosts.
    func cast() {
        if let id = selectedID { update(id) { $0.content = draft } }
        let wrote = apply()
        flash(lastError != nil ? .failed : (wrote ? .cast : .unchanged))
    }

    private func flash(_ f: CastFlash) {
        flashTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { castFlash = f }
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.6)) { self?.castFlash = nil }
        }
    }

    // MARK: - find & replace

    var findMatches: [NSRange] {
        guard !findText.isEmpty else { return [] }
        let ns = draft as NSString
        var out: [NSRange] = []
        var from = 0
        while from < ns.length {
            let r = ns.range(of: findText, options: .caseInsensitive, range: NSRange(location: from, length: ns.length - from))
            if r.location == NSNotFound { break }
            out.append(r)
            from = r.location + max(r.length, 1)
        }
        return out
    }

    /// Selects the next (or previous) match after the editor's current selection.
    func findNext(from current: NSRange, backwards: Bool = false) {
        let m = findMatches
        guard !m.isEmpty else { NSSound.beep(); return }
        let next: NSRange
        if backwards {
            next = m.last(where: { $0.location < current.location }) ?? m.last!
        } else {
            next = m.first(where: { $0.location > current.location || ($0.location == current.location && current.length == 0) }) ?? m.first!
        }
        pendingSelection = next
    }

    /// Replaces the selection if it is a match, then moves to the next one.
    func replaceOne(at current: NSRange) {
        let ns = draft as NSString
        if current.length > 0, current.location + current.length <= ns.length,
           ns.substring(with: current).caseInsensitiveCompare(findText) == .orderedSame {
            draft = ns.replacingCharacters(in: current, with: replaceText)
            let after = NSRange(location: current.location + (replaceText as NSString).length, length: 0)
            findNext(from: after)
        } else {
            findNext(from: current)
        }
    }

    func replaceAll() {
        let m = findMatches
        guard !m.isEmpty else { NSSound.beep(); return }
        let ns = NSMutableString(string: draft)
        for r in m.reversed() { ns.replaceCharacters(in: r, with: replaceText) }
        draft = ns as String
        pendingSelection = NSRange(location: 0, length: 0)
    }

    func setPaused(_ p: Bool) {
        paused = p
        apply()
    }

    func addNode(named name: String = "New Node", inGroup groupID: UUID? = nil) {
        let node = HostNode(name: name)
        let target = groupID ?? selectedGroup?.id
        if let target, let i = items.firstIndex(where: { $0.id == target }),
           case .group(var g) = items[i] {
            g.nodes.append(node); items[i] = .group(g)
        } else {
            items.append(.node(node))
        }
        select(node.id)
    }

    func addGroup(named name: String = "New Group") {
        let node = HostNode(name: "Development")
        items.append(.group(HostGroup(name: name, nodes: [node])))
        select(node.id)
    }

    func rename(_ id: UUID, to newName: String) {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if let i = items.firstIndex(where: { $0.id == id }), case .group(var g) = items[i] {
            g.name = name; items[i] = .group(g)
            if g.nodes.contains(where: \.isActive) { apply() }
        } else {
            update(id) { $0.name = name }
            if isActive(id) { apply() }   // the section title in /etc/hosts carries the name
        }
    }

    func setExclusive(_ groupID: UUID, _ on: Bool) {
        guard let i = items.firstIndex(where: { $0.id == groupID }), case .group(var g) = items[i] else { return }
        g.exclusive = on
        items[i] = .group(g)
    }

    func delete(_ id: UUID) {
        var wasActive = false
        if let i = items.firstIndex(where: { $0.id == id }) {
            if case .group(let g) = items[i] { wasActive = g.nodes.contains(where: \.isActive) }
            if case .node(let n) = items[i] { wasActive = n.isActive }
            items.remove(at: i)
        } else {
            for i in items.indices {
                if case .group(var g) = items[i], let j = g.nodes.firstIndex(where: { $0.id == id }) {
                    wasActive = g.nodes[j].isActive
                    g.nodes.remove(at: j); items[i] = .group(g); break
                }
            }
        }
        if selectedID == id || locate(selectedID) == nil { selectedID = firstNodeID; loadDraft() }
        if wasActive { apply() }
    }

    func move(_ id: UUID, by offset: Int) {
        if let i = items.firstIndex(where: { $0.id == id }) {
            let j = i + offset
            guard items.indices.contains(j) else { return }
            items.swapAt(i, j)
        } else {
            for i in items.indices {
                if case .group(var g) = items[i], let k = g.nodes.firstIndex(where: { $0.id == id }) {
                    let j = k + offset
                    guard g.nodes.indices.contains(j) else { return }
                    g.nodes.swapAt(k, j); items[i] = .group(g); break
                }
            }
        }
        apply()   // order of sections follows sidebar order
    }

    // MARK: - /etc/hosts

    /// Rewrites /etc/hosts from the current model. A no-op when the file
    /// already says what the model says.
    /// Writes /etc/hosts if the composed file differs; returns whether it wrote.
    @discardableResult
    func apply() -> Bool {
        do {
            let current = try HostsFile.read()
            backupOriginalIfNeeded(current)
            let text = HostsFile.compose(base: current, items: paused ? [] : items)
            guard text != current else { lastError = nil; return false }
            try HostsFile.write(text)
            lastApplied = Date()
            UserDefaults.standard.set(lastApplied, forKey: "lastApplied")
            lastError = nil
            canWriteDirectly = HostsFile.isWritableDirectly
            reloadLive()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - launch at login

    var launchesAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        objectWillChange.send()
    }

    func takeOwnership(_ on: Bool) {
        do {
            try HostsFile.setOwnership(toCurrentUser: on)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        canWriteDirectly = HostsFile.isWritableDirectly
    }

    /// Switches every node off and writes the pre-HostsWitch copy back.
    func restoreOriginal() {
        guard let original = try? String(contentsOf: backupURL, encoding: .utf8) else {
            lastError = "No backup found at \(backupURL.path)."
            return
        }
        for i in items.indices {
            switch items[i] {
            case .node(var n): n.isActive = false; items[i] = .node(n)
            case .group(var g):
                for j in g.nodes.indices { g.nodes[j].isActive = false }
                items[i] = .group(g)
            }
        }
        do {
            try HostsFile.write(HostsFile.strippingManaged(original))
            lastError = nil
            reloadLive()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// The first time we touch the file, keep a copy of what was there.
    private func backupOriginalIfNeeded(_ text: String) {
        guard !FileManager.default.fileExists(atPath: backupURL.path) else { return }
        try? text.write(to: backupURL, atomically: true, encoding: .utf8)
    }

    var backupURL: URL { supportDir.appendingPathComponent("hosts.original") }

    func reloadLive() {
        liveHosts = (try? HostsFile.read()) ?? "(could not read /etc/hosts)"
    }

    private func installMonitor() {
        monitor = FileMonitor(url: HostsFile.url) { [weak self] in
            Task { @MainActor in
                self?.reloadLive()
                self?.canWriteDirectly = HostsFile.isWritableDirectly
            }
        }
    }

    // MARK: - persistence

    private func persist() {
        guard !suppressPersist else { return }
        let lib = Library(items: items, paused: paused)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(lib) {
            try? data.write(to: libraryURL, options: .atomic)
        }
    }
}

/// Watches one file; re-arms itself when the file is replaced (cp, editors
/// that write a new inode) rather than modified in place.
final class FileMonitor {
    private var fd: CInt = -1
    private var source: DispatchSourceFileSystemObject?
    private let url: URL
    private let onChange: () -> Void

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        arm()
    }

    private func arm() {
        fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .rename, .delete, .attrib], queue: .main)
        src.setEventHandler { [weak self] in
            guard let self, let src = self.source else { return }
            let flags = src.data
            self.onChange()
            if flags.contains(.rename) || flags.contains(.delete) {
                src.cancel()
                self.source = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.arm() }
            }
        }
        let fd = self.fd
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    deinit { source?.cancel() }
}
