import AppKit
import SwiftUI

/// AppKit drag source, because SwiftUI's .onDrag can only return a single
/// NSItemProvider and cannot start one session with several file attachments.
struct BatchDragHandle: NSViewRepresentable {
    var urls: [URL]

    func makeNSView(context: Context) -> BatchDragView {
        BatchDragView()
    }

    func updateNSView(_ view: BatchDragView, context: Context) {
        view.urls = urls
        view.needsDisplay = true
    }
}

final class BatchDragView: NSView, NSDraggingSource {
    var urls: [URL] = []
    private var started = false

    override var intrinsicContentSize: NSSize { NSSize(width: 216, height: 49) }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                xRadius: 14, yRadius: 14)
        (urls.isEmpty
         ? NSColor.systemGray.withAlphaComponent(0.45)
         : NSColor(calibratedRed: 0.19, green: 0.42, blue: 0.92, alpha: 1)).setFill()
        path.fill()

        let title = urls.isEmpty ? "先添加截图" : "⠿  拖出 \(urls.count) 张图片"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        (title as NSString).draw(in: bounds.insetBy(dx: 10, dy: 15), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        started = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !started, !urls.isEmpty else { return }
        started = true
        let icon = NSImage(systemSymbolName: "photo.on.rectangle.angled",
                           accessibilityDescription: "所选截图") ?? NSImage(size: NSSize(width: 36, height: 36))

        let items: [NSDraggingItem] = urls.enumerated().map { index, url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let rect = NSRect(x: 20 + CGFloat(index % 4) * 3,
                              y: 6 + CGFloat(index % 4) * 3,
                              width: 36, height: 36)
            item.setDraggingFrame(rect, contents: icon)
            return item
        }
        beginDraggingSession(with: items, event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        started = false
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        started = false
    }
}
