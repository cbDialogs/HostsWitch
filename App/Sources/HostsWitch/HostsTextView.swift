import SwiftUI
import AppKit

/// A monospaced NSTextView with hosts-file colouring: IPs in ember,
/// comments dimmed and italic, HostsWitch's managed block tinted when shown.
struct HostsTextView: NSViewRepresentable {
    @Binding var text: String
    var isEditable = true
    var showManaged = false
    /// A selection to apply and scroll to, then clear (find & replace).
    var pendingSelection: Binding<NSRange?>? = nil
    var onSelectionChange: ((NSRange) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = Theme.nsWindow
        scroll.borderType = .noBorder
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true

        let tv = NSTextView()
        tv.delegate = context.coordinator
        tv.isEditable = isEditable
        tv.isSelectable = true
        tv.isRichText = false
        tv.allowsUndo = true
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.smartInsertDeleteEnabled = false
        tv.drawsBackground = true
        tv.backgroundColor = Theme.nsWindow
        tv.insertionPointColor = Theme.nsAccent
        tv.selectedTextAttributes = [.backgroundColor: Theme.nsSelection]
        tv.textContainerInset = NSSize(width: 10, height: 12)
        tv.font = Theme.nsMono(13)
        tv.textColor = Theme.nsText
        tv.typingAttributes = Coordinator.baseAttributes
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        scroll.documentView = tv
        context.coordinator.textView = tv
        tv.string = text
        context.coordinator.highlight()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = scroll.documentView as? NSTextView else { return }
        tv.isEditable = isEditable
        if tv.string != text {
            let sel = tv.selectedRange()
            tv.string = text
            let len = (text as NSString).length
            tv.setSelectedRange(NSRange(location: min(sel.location, len), length: 0))
            context.coordinator.highlight()
        }
        if let binding = pendingSelection, let r = binding.wrappedValue,
           r.location + r.length <= (tv.string as NSString).length {
            tv.setSelectedRange(r)
            tv.scrollRangeToVisible(r)
            tv.showFindIndicator(for: r)
            if r.length > 0 { tv.window?.makeFirstResponder(tv) }
            DispatchQueue.main.async { binding.wrappedValue = nil }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HostsTextView
        weak var textView: NSTextView?

        init(_ parent: HostsTextView) { self.parent = parent }

        static let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: Theme.nsMono(13),
            .foregroundColor: Theme.nsText,
        ]

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.text = tv.string
            highlight()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.onSelectionChange?(tv.selectedRange())
        }

        func highlight() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let ns = tv.string as NSString
            let all = NSRange(location: 0, length: ns.length)
            storage.beginEditing()
            storage.setAttributes(Self.baseAttributes, range: all)

            let mono = Theme.nsMono(13)
            let italic = NSFontManager.shared.convert(mono, toHaveTrait: .italicFontMask)
            let bold = Theme.nsMono(13, weight: .semibold)

            ns.enumerateSubstrings(in: all, options: [.byLines, .substringNotRequired]) { _, range, _, _ in
                let line = ns.substring(with: range)
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { return }
                if trimmed.hasPrefix("#") {
                    let isMarker = line == HostsFile.beginMarker || line == HostsFile.endMarker
                        || (self.parent.showManaged && trimmed.hasPrefix("# ---- ") && trimmed.hasSuffix(" ----"))
                    storage.addAttributes([.foregroundColor: isMarker ? Theme.nsAccent : Theme.nsComment,
                                           .font: isMarker ? bold : italic], range: range)
                    return
                }
                // first whitespace-delimited token is the address
                var ipEnd = 0
                let chars = Array(line)
                var i = 0
                while i < chars.count, chars[i] == " " || chars[i] == "\t" { i += 1 }
                let start = i
                while i < chars.count, chars[i] != " ", chars[i] != "\t" { i += 1 }
                ipEnd = i
                if ipEnd > start {
                    let s = (String(chars[0..<start]) as NSString).length
                    let e = (String(chars[0..<ipEnd]) as NSString).length
                    storage.addAttribute(.foregroundColor, value: Theme.nsAccent,
                                         range: NSRange(location: range.location + s, length: e - s))
                }
                if let hash = line.firstIndex(of: "#") {
                    let off = (String(line[..<hash]) as NSString).length
                    storage.addAttributes([.foregroundColor: Theme.nsComment, .font: italic],
                                          range: NSRange(location: range.location + off, length: range.length - off))
                }
            }

            if parent.showManaged {
                for r in HostsFile.managedLineRanges(in: tv.string) where r.location + r.length <= ns.length {
                    storage.addAttribute(.backgroundColor, value: Theme.nsHighlight, range: r)
                }
            }
            storage.endEditing()
        }
    }
}
