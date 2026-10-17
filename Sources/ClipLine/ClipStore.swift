import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Local-only clipboard and screenshot shelf. No server, account or telemetry.
@MainActor
final class ClipStore: ObservableObject {
    @Published private(set) var records: [ClipRecord] = []
    @Published var isCollecting: Bool {
        didSet {
            UserDefaults.standard.set(isCollecting, forKey: "isCollecting")
            if isCollecting { seedScreenshotFolder() }
        }
    }
    @Published var collectCopiedText: Bool {
        didSet { UserDefaults.standard.set(collectCopiedText, forKey: "collectCopiedText") }
    }
    @Published var collectCopiedImages: Bool {
        didSet { UserDefaults.standard.set(collectCopiedImages, forKey: "collectCopiedImages") }
    }
    @Published var watchScreenshotFiles: Bool {
        didSet {
            UserDefaults.standard.set(watchScreenshotFiles, forKey: "watchScreenshotFiles")
            seedScreenshotFolder()
        }
    }
    @Published var screenshotFolderPath: String {
        didSet {
            UserDefaults.standard.set(screenshotFolderPath, forKey: "screenshotFolderPath")
            seedScreenshotFolder()
        }
    }
    @Published var notice: String = "截图后自动挂到晾衣绳。复制文字需先在设置里启用。"

    private let fm = FileManager.default
    private var timer: Timer?
    private var knownScreenshotPaths = Set<String>()
    private var pasteboardChangeCount: Int = NSPasteboard.general.changeCount
    private var ownPasteboardChangeCount = -1

    private var root: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("ClipLine", isDirectory: true)
    }
    private var imageDirectory: URL { root.appendingPathComponent("images", isDirectory: true) }
    private var indexURL: URL { root.appendingPathComponent("records.json") }

    init() {
        let defaults = UserDefaults.standard
        isCollecting = defaults.object(forKey: "isCollecting") as? Bool ?? true
        collectCopiedText = defaults.bool(forKey: "collectCopiedText") // opt-in for privacy
        collectCopiedImages = defaults.object(forKey: "collectCopiedImages") as? Bool ?? true
        watchScreenshotFiles = defaults.object(forKey: "watchScreenshotFiles") as? Bool ?? true
        screenshotFolderPath = defaults.string(forKey: "screenshotFolderPath")
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path

        do {
            try fm.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
            if let data = try? Data(contentsOf: indexURL) {
                records = try JSONDecoder().decode([ClipRecord].self, from: data)
            }
        } catch {
            notice = "无法读取本地保存目录：\(error.localizedDescription)"
        }

        seedScreenshotFolder()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkClipboard()
                self?.checkScreenshotFolder()
            }
        }
    }

    var imageCount: Int { records.filter { $0.kind == .image }.count }
    var textCount: Int { records.filter { $0.kind == .text }.count }
    var allIDs: Set<UUID> { Set(records.map(\.id)) }

    func imageURL(for record: ClipRecord) -> URL? {
        guard let name = record.imageFilename else { return nil }
        let url = imageDirectory.appendingPathComponent(name)
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    func addText(_ raw: String, title: String = "文字便签") {
        let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        // Avoid large copies, duplicates and an unbounded clipboard history.
        let safeText = String(content.prefix(20000))
        guard records.first?.kind != .text || records.first?.text != safeText else { return }
        insert(ClipRecord(kind: .text, title: title, text: safeText))
        notice = "新的文字便签已挂好"
    }

    func addImage(_ image: NSImage, title: String = "截图") {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            notice = "图片无法转换为 PNG"
            return
        }
        saveImage(png, title: title)
    }

    func addImageFile(_ url: URL) {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()),
              type.conforms(to: .image) else { return }
        guard let image = NSImage(contentsOf: url) else {
            notice = "读取图片失败；请检查文件访问权限"
            return
        }
        addImage(image, title: url.deletingPathExtension().lastPathComponent)
    }

    private func saveImage(_ data: Data, title: String) {
        let filename = UUID().uuidString + ".png"
        let destination = imageDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: destination, options: .atomic)
            insert(ClipRecord(kind: .image, title: title, imageFilename: filename))
            notice = "截图已挂上晾衣绳"
        } catch {
            notice = "保存截图失败：\(error.localizedDescription)"
        }
    }

    private func insert(_ record: ClipRecord) {
        records.insert(record, at: 0)
        if records.count > 80 {
            let excess = records.suffix(from: 80)
            for old in excess { removeImageFile(old) }
            records = Array(records.prefix(80))
        }
        persist()
    }

    func remove(_ id: UUID) {
        guard let item = records.first(where: { $0.id == id }) else { return }
        removeImageFile(item)
        records.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        for record in records { removeImageFile(record) }
        records.removeAll()
        persist()
        notice = "已清空晾衣绳"
    }

    private func removeImageFile(_ record: ClipRecord) {
        if let url = imageURL(for: record) { try? fm.removeItem(at: url) }
    }

    private func persist() {
        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            try JSONEncoder().encode(records).write(to: indexURL, options: .atomic)
        } catch {
            notice = "保存记录失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Clipboard collection

    private func checkClipboard() {
        let board = NSPasteboard.general
        let current = board.changeCount
        guard current != pasteboardChangeCount else { return }
        pasteboardChangeCount = current
        guard current != ownPasteboardChangeCount, isCollecting else { return }

        if collectCopiedImages {
            if let urls = board.readObjects(forClasses: [NSURL.self],
                                            options: [.urlReadingFileURLsOnly: true]) as? [URL],
               let first = urls.first, first.isFileURL,
               let type = UTType(filenameExtension: first.pathExtension),
               type.conforms(to: .image) {
                addImageFile(first)
                return
            }
            if let image = board.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                addImage(image)
                return
            }
        }
        if collectCopiedText, let text = board.string(forType: .string) {
            addText(text)
        }
    }

    /// Prevent our own pasteboard writes from being collected again.
    private func markInternalClipboardWrite() {
        ownPasteboardChangeCount = NSPasteboard.general.changeCount
        pasteboardChangeCount = ownPasteboardChangeCount
    }

    func copyText(_ items: [ClipRecord]) {
        let result = items.compactMap { $0.kind == .text ? $0.text : nil }.joined(separator: "\n\n")
        guard !result.isEmpty else { notice = "当前选择中没有文字"; return }
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(result, forType: .string)
        markInternalClipboardWrite()
        notice = "已复制文字，可到目标输入框按 ⌘V"
    }

    func copyImageFiles(_ items: [ClipRecord]) {
        let urls = items.compactMap { $0.kind == .image ? imageURL(for: $0) : nil }
        guard !urls.isEmpty else { notice = "当前选择中没有图片"; return }
        let board = NSPasteboard.general
        board.clearContents()
        let success = board.writeObjects(urls.map { $0 as NSURL })
        markInternalClipboardWrite()
        notice = success
            ? "已复制 \(urls.count) 个图片文件；支持文件粘贴的应用可按 ⌘V，也可以从蓝色拖拽区一次拖入。"
            : "复制图片文件失败，请尝试批量拖拽"
    }

    /// This is for macOS apps and web upload areas that accept multiple files.
    /// Copied text is separate: browsers cannot reliably paste a mixed text/image batch.
    func selectedImageURLs(_ items: [ClipRecord]) -> [URL] {
        items.compactMap { $0.kind == .image ? imageURL(for: $0) : nil }
    }

    func export(_ items: [ClipRecord]) {
        guard !items.isEmpty else { notice = "请先选择内容"; return }
        let picker = NSOpenPanel()
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.canCreateDirectories = true
        picker.prompt = "导出到这里"
        guard picker.runModal() == .OK, let directory = picker.url else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let output = directory.appendingPathComponent("ClipLine-" + formatter.string(from: Date()), isDirectory: true)
        do {
            try fm.createDirectory(at: output, withIntermediateDirectories: true)
            for (index, record) in items.enumerated() {
                let number = String(format: "%02d", index + 1)
                if record.kind == .image, let source = imageURL(for: record) {
                    try fm.copyItem(at: source, to: output.appendingPathComponent(number + "-screenshot.png"))
                } else if let text = record.text {
                    try text.write(to: output.appendingPathComponent(number + "-note.txt"), atomically: true, encoding: .utf8)
                }
            }
            NSWorkspace.shared.activateFileViewerSelecting([output])
            notice = "已导出 \(items.count) 项到 Finder"
        } catch {
            notice = "导出失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Screenshot folder polling (files created by ⇧⌘3 / ⇧⌘4)

    private func screenshotFilePaths() -> [URL] {
        let folder = URL(fileURLWithPath: screenshotFolderPath, isDirectory: true)
        return (try? fm.contentsOfDirectory(at: folder,
                                           includingPropertiesForKeys: [.contentModificationDateKey],
                                           options: [.skipsHiddenFiles]))?
            .filter { Self.isScreenshotFile($0) } ?? []
    }

    private static func isScreenshotFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        let prefixes = ["screenshot", "screen shot", "截屏", "屏幕快照", "屏幕截图"]
        return ["png", "jpg", "jpeg", "heic"].contains(url.pathExtension.lowercased())
            && prefixes.contains(where: { name.hasPrefix($0) })
    }

    private func seedScreenshotFolder() {
        knownScreenshotPaths = Set(screenshotFilePaths().map(\.path))
    }

    private func checkScreenshotFolder() {
        guard isCollecting, watchScreenshotFiles else { return }
        let files = screenshotFilePaths()
        let newFiles = files.filter { !knownScreenshotPaths.contains($0.path) }
        knownScreenshotPaths = Set(files.map(\.path))
        for url in newFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            addImageFile(url)
        }
    }

    func chooseScreenshotFolder() {
        let picker = NSOpenPanel()
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.prompt = "监听这个文件夹"
        picker.directoryURL = URL(fileURLWithPath: screenshotFolderPath)
        if picker.runModal() == .OK, let folder = picker.url {
            screenshotFolderPath = folder.path
            notice = "截图文件夹已更新；此后新截图会自动出现"
        }
    }

    func importImages() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = true
        picker.canChooseDirectories = false
        picker.allowsMultipleSelection = true
        picker.allowedContentTypes = [.image]
        if picker.runModal() == .OK {
            picker.urls.forEach { addImageFile($0) }
        }
    }

    func importProviders(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                    let url: URL?
                    if let file = item as? URL { url = file }
                    else if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                    else { url = nil }
                    guard let url else { return }
                    Task { @MainActor [weak self] in self?.addImageFile(url) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, _ in
                    guard let data, let string = String(data: data, encoding: .utf8) else { return }
                    Task { @MainActor [weak self] in self?.addText(string, title: "拖入的文字") }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { [weak self] data, _ in
                    guard let data, let image = NSImage(data: data) else { return }
                    Task { @MainActor [weak self] in self?.addImage(image, title: "拖入的图片") }
                }
            }
        }
        return true
    }
}
