import Foundation

/// Reading, composing and writing /etc/hosts.
///
/// HostsWitch owns exactly one region of the file, fenced by `beginMarker`
/// and `endMarker`. Everything outside it is the user's (or the system's)
/// and is passed through untouched.
enum HostsFile {
    static let path = "/etc/hosts"
    static let url = URL(fileURLWithPath: path)
    static let beginMarker = "# ==== HostsWitch begin (managed by HostsWitch.app — edits inside this block are overwritten) ===="
    static let endMarker   = "# ==== HostsWitch end ===="

    enum WriteError: LocalizedError {
        case cancelled
        case failed(String)
        var errorDescription: String? {
            switch self {
            case .cancelled: return "Authentication was cancelled; /etc/hosts was not changed."
            case .failed(let s): return s
            }
        }
    }

    static func read() throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    /// The file without the HostsWitch block (and without the blank lines
    /// that separated it from the rest).
    static func strippingManaged(_ text: String) -> String {
        // An untouched file stays byte-identical.
        guard let b = text.range(of: beginMarker),
              let e = text.range(of: endMarker, range: b.upperBound..<text.endIndex) else { return text }
        var start = b.lowerBound
        var end = e.upperBound
        if end < text.endIndex, text[end] == "\n" { end = text.index(after: end) }
        // compose() puts one blank line before the block; take that back too.
        if start > text.startIndex {
            let nl = text.index(before: start)
            if text[nl] == "\n", nl > text.startIndex, text[text.index(before: nl)] == "\n" { start = nl }
        }
        return String(text[..<start]) + String(text[end...])
    }

    /// Whether a line falls inside the managed block, for highlighting.
    static func managedLineRanges(in text: String) -> [NSRange] {
        var ranges: [NSRange] = []
        var inside = false
        let ns = text as NSString
        var location = 0
        for line in text.components(separatedBy: "\n") {
            let len = (line as NSString).length
            let r = NSRange(location: location, length: min(len + 1, ns.length - location))
            if line == beginMarker { inside = true; ranges.append(r) }
            else if line == endMarker { inside = false; ranges.append(r) }
            else if inside { ranges.append(r) }
            location += len + 1
        }
        return ranges
    }

    /// The block for the current active nodes; empty when nothing is active.
    static func managedBlock(for items: [HostItem]) -> String {
        var sections: [String] = []
        for item in items {
            switch item {
            case .node(let n) where n.isActive:
                sections.append(section(title: n.name, body: n.content))
            case .group(let g):
                for n in g.nodes where n.isActive {
                    sections.append(section(title: "\(g.name) / \(n.name)", body: n.content))
                }
            default: break
            }
        }
        guard !sections.isEmpty else { return "" }
        return ([beginMarker] + sections + [endMarker]).joined(separator: "\n") + "\n"
    }

    private static func section(title: String, body: String) -> String {
        var b = body
        while b.hasSuffix("\n") { b.removeLast() }
        return "# ---- \(title) ----\n" + b
    }

    static func compose(base: String, items: [HostItem]) -> String {
        var clean = strippingManaged(base)
        let block = managedBlock(for: items)
        guard !block.isEmpty else { return clean }
        if clean.isEmpty { return block }
        if !clean.hasSuffix("\n") { clean += "\n" }
        return clean + "\n" + block
    }

    static var isWritableDirectly: Bool {
        FileManager.default.isWritableFile(atPath: path)
    }

    /// Writes the file: in place when we own it, otherwise through the
    /// standard macOS administrator prompt.
    static func write(_ text: String) throws {
        if isWritableDirectly {
            // Truncate-and-write rather than an atomic replace, so the file
            // keeps its inode, owner and mode.
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.truncate(atOffset: 0)
            try handle.write(contentsOf: Data(text.utf8))
            _ = try? run("/usr/bin/dscacheutil", ["-flushcache"])
            return
        }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("hostswitch-\(UUID().uuidString).hosts")
        try text.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try runPrivileged(
            "/bin/cp '\(tmp.path)' /etc/hosts && /bin/chmod 644 /etc/hosts && " +
            "/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder 2>/dev/null; true")
    }

    /// Hands ownership of /etc/hosts to the current user (or back to root),
    /// after one administrator prompt, so later writes need no password.
    static func setOwnership(toCurrentUser: Bool) throws {
        let owner = toCurrentUser ? "\(getuid())" : "root"
        try runPrivileged("/usr/sbin/chown \(owner):wheel /etc/hosts && /bin/chmod 644 /etc/hosts")
    }

    // MARK: - process helpers

    @discardableResult
    private static func run(_ tool: String, _ args: [String]) throws -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let err = Pipe()
        p.standardError = err
        p.standardOutput = Pipe()
        try p.run()
        p.waitUntilExit()
        let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (p.terminationStatus, msg)
    }

    private static func runPrivileged(_ shell: String) throws {
        let escaped = shell.replacingOccurrences(of: "\\", with: "\\\\")
                           .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        let (status, msg) = try run("/usr/bin/osascript", ["-e", script])
        guard status == 0 else {
            if msg.contains("-128") { throw WriteError.cancelled }
            throw WriteError.failed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
