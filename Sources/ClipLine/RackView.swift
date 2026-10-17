import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum Palette {
    static let ink = Color(red: 0.10, green: 0.17, blue: 0.29)
    static let muted = Color(red: 0.46, green: 0.53, blue: 0.64)
    static let blue = Color(red: 0.19, green: 0.42, blue: 0.92)
    static let paper = Color(red: 0.98, green: 0.99, blue: 1.00)
}

struct RackView: View {
    @EnvironmentObject private var store: ClipStore
    @State private var selectedIDs = Set<UUID>()
    @State private var allSelected = true
    @State private var noteDraft = ""
    @State private var showingNoteEditor = false
    @State private var showingClearConfirmation = false
    @State private var hoveringDropZone = false

    private var selectedRecords: [ClipRecord] {
        let chosen = allSelected ? store.records : store.records.filter { selectedIDs.contains($0.id) }
        return Array(chosen.reversed())  // oldest first, for sending/exporting
    }
    private var selectedImages: [URL] { store.selectedImageURLs(selectedRecords) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.90, green: 0.94, blue: 1.0),
                    Color(red: 0.97, green: 0.98, blue: 1.0),
                    Color(red: 1.0, green: 0.95, blue: 0.91)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.56))
                .frame(width: 500, height: 500)
                .blur(radius: 40)
                .offset(x: 440, y: -260)

            VStack(spacing: 17) {
                topBar
                infoBanner
                mainShelf
                actionBar
                footer
            }
            .padding(.horizontal, 29)
            .padding(.top, 23)
            .padding(.bottom, 20)
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showingNoteEditor) { noteEditor }
        .alert("清空晾衣绳？", isPresented: $showingClearConfirmation) {
            Button("清空", role: .destructive) {
                store.clearAll()
                selectedIDs.removeAll()
                allSelected = true
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会删除 ClipLine 本地暂存的截图和文字，不会删除原始截图文件。")
        }
    }

    private var topBar: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 17)
                    .fill(LinearGradient(colors: [
                        Color(red: 0.38, green: 0.70, blue: 1.0),
                        Palette.blue
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 55, height: 55)
                    .shadow(color: Palette.blue.opacity(0.25), radius: 10, y: 6)
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("晾图架")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text("ClipLine · 先晾起来，需要时再一起收下")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.muted)
            }

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(store.isCollecting ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(store.isCollecting ? "正在收集" : "已暂停")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.trailing, 8)

            Button {
                store.isCollecting.toggle()
            } label: {
                Label(store.isCollecting ? "暂停收集" : "开始收集",
                      systemImage: store.isCollecting ? "pause.fill" : "play.fill")
            }
            .buttonStyle(SoftActionStyle(tinted: true))

            Button {
                store.importImages()
            } label: {
                Label("添加图片", systemImage: "photo.badge.plus")
            }
            .buttonStyle(SoftActionStyle())

            Button {
                noteDraft = ""
                showingNoteEditor = true
            } label: {
                Label("文字便签", systemImage: "note.text.badge.plus")
            }
            .buttonStyle(SoftActionStyle())
        }
    }

    private var infoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .foregroundStyle(Palette.blue)
            Text(store.notice)
                .lineLimit(2)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.muted)
            Spacer(minLength: 12)
            Label("仅保存在本机", systemImage: "lock.shield")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.9)))
    }

    private var mainShelf: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("你的灵感晾衣绳")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("收集完再切换窗口。点击卡片选择，拖动下方蓝色区域可一次投递多张图片。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Text("\(store.records.count) 项 · \(store.imageCount) 图 / \(store.textCount) 文")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.85), in: Capsule())
            }

            if store.records.isEmpty {
                emptyShelf
            } else {
                hangingShelf
            }

            HStack {
                Label("可直接把图片或文字拖到晾衣绳中", systemImage: "arrow.down.to.line.compact")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                Spacer()
                Button(allSelected ? "取消全选" : "选择全部") {
                    if allSelected {
                        allSelected = false
                        selectedIDs.removeAll()
                    } else {
                        allSelected = true
                        selectedIDs.removeAll()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.blue)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 25)
                .fill(.white.opacity(0.69))
                .overlay {
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(.white.opacity(0.94), lineWidth: 1.4)
                }
        }
        .shadow(color: Color(red: 0.45, green: 0.53, blue: 0.69).opacity(0.12),
                radius: 22, y: 10)
    }

    private var hangingShelf: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.67, green: 0.45, blue: 0.28).opacity(0.72))
                    .frame(height: 3)
                    .padding(.top, 21)
                    .padding(.horizontal, 2)

                HStack(alignment: .top, spacing: 18) {
                    ForEach(store.records) { record in
                        HangingCard(
                            record: record,
                            fileURL: store.imageURL(for: record),
                            isSelected: allSelected || selectedIDs.contains(record.id),
                            onSelect: { toggle(record.id) },
                            onRemove: { store.remove(record.id); selectedIDs.remove(record.id) },
                            onCopy: { record.kind == .text
                                ? store.copyText([record])
                                : store.copyImageFiles([record]) }
                        )
                    }
                }
                .padding(.horizontal, 11)
            }
            .padding(.top, 1)
            .padding(.bottom, 20)
        }
        .frame(maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL, UTType.png, UTType.plainText],
                isTargeted: $hoveringDropZone) { providers in
            store.importProviders(providers)
        }
        .background(hoveringDropZone ? Palette.blue.opacity(0.06) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyShelf: some View {
        VStack(spacing: 12) {
            ZStack {
                Capsule()
                    .fill(Color(red: 0.74, green: 0.58, blue: 0.46))
                    .frame(width: 260, height: 3)
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill([Color(red: 0.94, green: 0.78, blue: 0.55),
                               Color(red: 0.99, green: 0.74, blue: 0.77),
                               Color(red: 0.65, green: 0.80, blue: 0.98)][index])
                        .frame(width: 66, height: 78)
                        .rotationEffect(.degrees(Double(index - 1) * 5))
                        .offset(x: CGFloat(index - 1) * 89, y: 45)
                }
            }
            .frame(height: 143)
            Text("晾衣绳还是空的")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("用 ⇧⌘4 截图，或点击“添加图片”开始吧")
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
            Text("如果你设置了其他截图保存位置，可以在设置中更换监听文件夹。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionBar: some View {
        HStack(spacing: 13) {
            VStack(alignment: .leading, spacing: 3) {
                Text("准备收衣服了？")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text("已选择 \(selectedRecords.count) 项 · \(selectedImages.count) 张图片")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }
            .frame(width: 188, alignment: .leading)

            BatchDragHandle(urls: selectedImages)
                .frame(width: 216, height: 49)
                .help("按住这个蓝色区域拖到网页上传区，可一次拖出已选的多张截图")

            Button {
                store.copyImageFiles(selectedRecords)
            } label: {
                Label("复制图片文件", systemImage: "doc.on.doc")
            }
            .buttonStyle(SoftActionStyle())
            .disabled(selectedImages.isEmpty)

            Button {
                store.copyText(selectedRecords)
            } label: {
                Label("复制文字", systemImage: "text.alignleft")
            }
            .buttonStyle(SoftActionStyle())
            .disabled(!selectedRecords.contains { $0.kind == .text })

            Button {
                store.export(selectedRecords)
            } label: {
                Label("导出全部", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(SoftActionStyle())
            .disabled(selectedRecords.isEmpty)

            Spacer(minLength: 0)

            Button {
                showingClearConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(SoftActionStyle())
            .help("清空晾衣绳")
            .disabled(store.records.isEmpty)
        }
        .padding(14)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
    }

    private var footer: some View {
        HStack {
            Label("图片：拖入上传区更通用；文字：复制后在输入框 ⌘V", systemImage: "info.circle")
            Spacer()
            Text("ClipLine 0.1 · macOS · 本地优先")
        }
        .font(.system(size: 11))
        .foregroundStyle(Palette.muted)
        .padding(.horizontal, 7)
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("挂一张文字便签")
                .font(.title2.bold())
            TextEditor(text: $noteDraft)
                .font(.system(size: 14))
                .frame(width: 420, height: 210)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.gray.opacity(0.2)))
            HStack {
                Button("取消") { showingNoteEditor = false }
                Spacer()
                Button("挂上去") {
                    store.addText(noteDraft, title: "手动便签")
                    showingNoteEditor = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
    }

    private func toggle(_ id: UUID) {
        if allSelected {
            allSelected = false
            selectedIDs = store.allIDs
        }
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}

private struct HangingCard: View {
    let record: ClipRecord
    let fileURL: URL?
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    let onCopy: () -> Void

    @State private var hovered = false

    private var baseColor: Color {
        if record.kind == .image { return .white }
        let choices: [Color] = [
            Color(red: 1.0, green: 0.95, blue: 0.72),
            Color(red: 1.0, green: 0.86, blue: 0.90),
            Color(red: 0.87, green: 0.94, blue: 1.0),
            Color(red: 0.88, green: 0.96, blue: 0.89)
        ]
        return choices[abs(record.id.hashValue % choices.count)]
    }

    var body: some View {
        VStack(spacing: -6) {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.80, green: 0.55, blue: 0.32))
                    .frame(width: 16, height: 35)
                    .rotationEffect(.degrees(4))
                    .shadow(color: .brown.opacity(0.2), radius: 3, y: 2)
                Rectangle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 2, height: 16)
                    .rotationEffect(.degrees(4))
            }
            .zIndex(1)

            VStack(alignment: .leading, spacing: 9) {
                ZStack(alignment: .topTrailing) {
                    if record.kind == .image, let fileURL,
                       let picture = NSImage(contentsOf: fileURL) {
                        Image(nsImage: picture)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 192, height: 128)
                            .clipped()
                            .background(Color.gray.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                    } else {
                        VStack(alignment: .leading, spacing: 9) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 20))
                                .foregroundStyle(Palette.ink.opacity(0.65))
                            Text(record.text ?? "")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(5)
                            Spacer(minLength: 0)
                        }
                        .frame(width: 174, height: 109, alignment: .topLeading)
                        .padding(9)
                    }

                    Text(record.kind == .image ? "截图" : "文字")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(record.kind == .image ? Palette.blue : Palette.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.88), in: Capsule())
                        .padding(8)
                }

                HStack(spacing: 6) {
                    Text(record.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 1)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Palette.blue : Palette.muted)
                        .font(.system(size: 16))
                }
                Text(record.createdAt, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)

                HStack {
                    Button("复制") { onCopy() }
                        .buttonStyle(.plain)
                    Spacer()
                    Button("取下") { onRemove() }
                        .buttonStyle(.plain)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.muted)
            }
            .padding(10)
            .frame(width: 212)
            .background(baseColor, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Palette.blue.opacity(0.74) : Color.white,
                            lineWidth: isSelected ? 2 : 1)
            }
            .shadow(color: Palette.ink.opacity(hovered ? 0.16 : 0.09),
                    radius: hovered ? 16 : 9, y: 7)
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture(perform: onSelect)
        }
        .rotationEffect(.degrees(hovered ? 0 : (record.id.hashValue.isMultiple(of: 2) ? 2 : -2)))
        .animation(.easeInOut(duration: 0.18), value: hovered)
        .onHover { hovered = $0 }
    }
}

private struct SoftActionStyle: ButtonStyle {
    var tinted = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(tinted ? Color.white : Palette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                tinted ? Palette.blue : Color.white.opacity(0.9),
                in: RoundedRectangle(cornerRadius: 13)
            )
            .shadow(color: tinted ? Palette.blue.opacity(0.21) : .clear, radius: 8, y: 4)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var store: ClipStore

    var body: some View {
        Form {
            Section("收集方式") {
                Toggle("监控新截图文件（默认桌面）", isOn: $store.watchScreenshotFiles)
                Toggle("自动收集剪贴板图片", isOn: $store.collectCopiedImages)
                Toggle("自动收集复制的文字（需要主动开启）", isOn: $store.collectCopiedText)
                HStack {
                    Text("截图目录")
                    Text(store.screenshotFolderPath)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("更改…") { store.chooseScreenshotFolder() }
                }
            }
            Section("隐私") {
                Text("图片和文字只保存在本机的 Application Support/ClipLine，不上传服务器。")
                Text("自动收集文字可能包含密码或个人信息，因此默认关闭；请在收集敏感信息前暂停。")
                Text("清空晾衣绳只会删除 ClipLine 的本地副本。")
            }
        }
        .formStyle(.grouped)
        .frame(width: 570, height: 320)
    }
}
