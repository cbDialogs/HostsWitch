import Foundation

/// One block of hosts entries. Its `content` is plain text in /etc/hosts
/// syntax: `IP  hostname [hostname…]`, `#` comments, blank lines.
struct HostNode: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var content = ""
    var isActive = false

    /// Lines that will actually be written (non-blank, non-comment).
    var entryCount: Int {
        content.split(separator: "\n").filter {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty && !t.hasPrefix("#")
        }.count
    }
}

/// A named set of nodes. When `exclusive`, activating one node deactivates
/// the others — the dev / staging / production switch.
struct HostGroup: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var nodes: [HostNode]
    var exclusive = true
}

/// The sidebar is a flat list of top-level nodes and groups, in user order.
enum HostItem: Identifiable, Codable, Hashable {
    case node(HostNode)
    case group(HostGroup)

    var id: UUID {
        switch self {
        case .node(let n): return n.id
        case .group(let g): return g.id
        }
    }
    var name: String {
        switch self {
        case .node(let n): return n.name
        case .group(let g): return g.name
        }
    }
}

struct Library: Codable {
    var items: [HostItem]
    var paused = false

    static let starter = Library(items: [
        .node(HostNode(name: "Default",
                       content: "# Entries in Default are applied whenever it is switched on.\n127.0.0.1    mysite.test\n")),
        .group(HostGroup(name: "Example", nodes: [
            HostNode(name: "Development", content: "# Point the site at the local stack\n127.0.0.1    example.test\n127.0.0.1    api.example.test\n"),
            HostNode(name: "Staging", content: "192.168.1.80    example.test\n192.168.1.80    api.example.test\n"),
            HostNode(name: "Production", content: "# Nothing here: production resolves through real DNS.\n"),
        ])),
    ])
}
