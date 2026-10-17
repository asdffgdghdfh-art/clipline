import SwiftUI
import AppKit

@main
struct ClipLineApp: App {
    @StateObject private var store = ClipStore()

    var body: some Scene {
        Window("晾图架 · ClipLine", id: "rack") {
            RackView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1140, height: 745)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra("ClipLine", systemImage: "photo.stack") {
            MenuBarControls()
                .environmentObject(store)
        }

        Settings {
            PreferencesView()
                .environmentObject(store)
        }
    }
}

private struct MenuBarControls: View {
    @EnvironmentObject private var store: ClipStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("打开晾图架") {
            openWindow(id: "rack")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button(store.isCollecting ? "暂停收集" : "继续收集") {
            store.isCollecting.toggle()
        }
        Text("已晾起 \(store.records.count) 项")
        Divider()
        Button("退出 ClipLine") { NSApp.terminate(nil) }
    }
}
