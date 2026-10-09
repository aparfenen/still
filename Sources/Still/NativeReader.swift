import SwiftUI
import AppKit
import StillCore

/// Native selectable text, UTF-16 highlight anchors, and persisted scroll position.
struct NativeReader: NSViewRepresentable {
    let item: StillCore.LibraryItem
    @AppStorage("readerFont") private var font = ReaderDefaults.font
    @AppStorage("readerSize") private var fontSize = ReaderDefaults.size
    @AppStorage("readerSpacing") private var lineSpacing = ReaderDefaults.spacing
    @AppStorage("readerInset") private var inset = ReaderDefaults.inset
    @Binding var selection: NSRange
    var onPosition: (Double) -> Void

    private var readingFont: NSFont {
        let size = max(12, min(32, fontSize))
        switch font {
        case "serif": return NSFont(name: "Georgia", size: size) ?? .systemFont(ofSize: size)
        case "rounded": return NSFont.systemFont(ofSize: size).fontDescriptor.withDesign(.rounded)
            .flatMap { NSFont(descriptor: $0, size: size) } ?? .systemFont(ofSize: size)
        case "mono": return .monospacedSystemFont(ofSize: size, weight: .regular)
        default: return .systemFont(ofSize: size)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.contentView.postsBoundsChangedNotifications = true
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.isRichText = false
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.minSize = NSSize(width: 0, height: 0)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.textContainer?.containerSize = NSSize(width: 500, height: CGFloat.greatestFiniteMagnitude)
        text.textContainerInset = NSSize(width: 28, height: 24)
        text.delegate = context.coordinator
        scroll.documentView = text
        context.coordinator.scroll = scroll
        NotificationCenter.default.addObserver(context.coordinator,
            selector: #selector(Coordinator.scrolled(_:)),
            name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let text = scroll.documentView as? NSTextView else { return }
        let contentChanged = coordinator.itemID != item.id || text.string != item.readingText
        let annotationsChanged = coordinator.annotations != item.annotations
        let styleKey = "\(font):\(fontSize):\(lineSpacing):\(inset)"
        guard contentChanged || annotationsChanged || coordinator.styleKey != styleKey else { return }
        coordinator.styleKey = styleKey
        text.textContainerInset = NSSize(width: max(12, min(96, inset)), height: 24)
        coordinator.styling = true
        let selected = text.selectedRange()
        let style = NSMutableParagraphStyle()
        style.lineSpacing = max(0, min(20, lineSpacing))
        style.paragraphSpacing = 14
        let attributed = NSMutableAttributedString(string: item.readingText, attributes: [
            .font: readingFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: style
        ])
        for note in item.annotations {
            if let range = note.resolvedRange(in: item.readingText) {
                attributed.addAttribute(.backgroundColor,
                    value: NSColor.systemYellow.withAlphaComponent(0.22), range: range)
            }
        }
        text.textStorage?.setAttributedString(attributed)
        coordinator.annotations = item.annotations
        coordinator.itemID = item.id
        if !contentChanged, selected.location != NSNotFound,
           NSMaxRange(selected) <= attributed.length {
            text.setSelectedRange(selected)
        } else {
            text.setSelectedRange(NSRange(location: 0, length: 0))
        }
        coordinator.styling = false
        if contentChanged {
            let desiredOffset = item.readingOffset
            DispatchQueue.main.async {
                if let container = text.textContainer { text.layoutManager?.ensureLayout(for: container) }
                let maximum = max(0, text.frame.height - scroll.contentView.bounds.height)
                scroll.contentView.scroll(to: NSPoint(x: 0, y: min(CGFloat(desiredOffset), maximum)))
                scroll.reflectScrolledClipView(scroll.contentView)
            }
        }
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.pending?.cancel()
        NotificationCenter.default.removeObserver(coordinator)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeReader
        weak var scroll: NSScrollView?
        var itemID: UUID?
        var annotations: [Annotation] = []
        var styleKey = ""
        var styling = false
        var pending: DispatchWorkItem?

        init(_ parent: NativeReader) { self.parent = parent }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !styling, let text = notification.object as? NSTextView else { return }
            let range = text.selectedRange()
            DispatchQueue.main.async { [weak self] in self?.parent.selection = range }
        }

        @objc func scrolled(_ notification: Notification) {
            guard !styling, let scroll else { return }
            pending?.cancel()
            let offset = Double(scroll.contentView.bounds.origin.y)
            let callback = parent.onPosition
            let work = DispatchWorkItem { callback(offset) }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
        }
    }
}
