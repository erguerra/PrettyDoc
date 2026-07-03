import SwiftUI
import AppKit

@main
struct PrettyDocApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let workspace = WorkspaceModel.shared

    var body: some Scene {
        Window("Pretty Doc", id: "main") {
            WorkspaceView()
                .environment(workspace)
                .environmentObject(workspace.settings)
                .frame(minWidth: 700, minHeight: 480)
        }
        .commands {
            AppCommands(workspace: workspace)
        }

        Settings {
            TypographyControls()
                .environmentObject(workspace.settings)
                .frame(width: 380, height: 520)
        }
    }
}

/// Receives file and `prettydoc://` URL opens from Finder, the CLI, and other apps.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.isFileURL {
                WorkspaceModel.shared.open(url: url)
            } else if url.scheme == "prettydoc" {
                WorkspaceModel.shared.handleURL(url)
            }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}

/// App menus: file/folder/tab management plus reading controls and CLI install.
struct AppCommands: Commands {
    let workspace: WorkspaceModel
    @ObservedObject private var settings: ReaderSettings

    init(workspace: WorkspaceModel) {
        self.workspace = workspace
        self._settings = ObservedObject(wrappedValue: workspace.settings)
    }

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Install Command-Line Tool…") {
                CLIInstaller.installAndReport()
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("Open File…") {
                for url in FilePanels.chooseFiles() { workspace.open(url: url, mode: .newTab) }
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Open Folder…") {
                if let url = FilePanels.chooseFolder() { workspace.openFolder(url) }
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            Button("Reveal in Finder") {
                workspace.revealSelectedInFinder()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(workspace.selectedTab?.fileURL == nil)

            Button("Open in Editor") {
                workspace.openSelectedInEditor()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(workspace.selectedTab?.fileURL == nil)

            Divider()

            Button("Close Tab") {
                workspace.closeSelectedTab()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(workspace.selectedTab == nil)
        }

        CommandMenu("Tabs") {
            Button("Next Tab") { workspace.selectNext() }
                .keyboardShortcut("]", modifiers: [.command, .shift])
            Button("Previous Tab") { workspace.selectPrevious() }
                .keyboardShortcut("[", modifiers: [.command, .shift])

            Divider()

            Button("Toggle Follow Mode") { workspace.toggleFollowOnSelected() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(workspace.selectedTab == nil)
        }

        CommandGroup(after: .toolbar) {
            Menu("Theme") {
                Picker("Theme", selection: $settings.themeMode) {
                    ForEach(ThemeMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
            }

            Divider()

            Button("Larger Text") { settings.bumpFontScale(0.1) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Smaller Text") { settings.bumpFontScale(-0.1) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Actual Size") { settings.resetTypography() }
                .keyboardShortcut("0", modifiers: .command)
        }
    }
}
