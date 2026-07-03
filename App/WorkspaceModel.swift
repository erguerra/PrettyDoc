import SwiftUI
import WebKit
import AppKit

enum OpenMode {
    case newTab
    case reuseCurrent
    case newWindow
}

enum SidebarMode: String, CaseIterable, Identifiable {
    case files
    case outline
    var id: String { rawValue }
    var label: String { self == .files ? "Files" : "Outline" }
    var symbol: String { self == .files ? "folder" : "list.bullet.indent" }
}

let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn", "mdtext"]

/// A single open document: its own web view/controller, live-reload watcher,
/// and extracted outline.
@MainActor
@Observable
final class OpenTab: Identifiable {
    let id = UUID()
    var title: String
    var fileURL: URL?
    var outline: [Heading] = []
    var isFollowing: Bool = false

    @ObservationIgnored let controller = MarkdownWebController()
    @ObservationIgnored private var watcher: FileWatcher?

    init(fileURL: URL?, title: String) {
        self.fileURL = fileURL
        self.title = title

        controller.onOutline = { [weak self] headings in self?.outline = headings }
        controller.onOpenExternal = { url in NSWorkspace.shared.open(url) }
        controller.onOpenRelativeHref = { [weak self] href in self?.openRelative(href) }
    }

    func present(text: String, settingsJSON: String, baseDir: URL?, anchor: String?, follow: Bool) {
        controller.baseDirectory = baseDir
        controller.applySettings(settingsJSON)
        controller.render(markdown: text)
        if follow {
            isFollowing = true
            controller.setFollow(true)
        }
        if let anchor, !anchor.isEmpty {
            controller.scrollToAnchor(anchor)
        }
    }

    func updateText(_ text: String) {
        controller.render(markdown: text)
        if isFollowing { controller.setFollow(true) }
    }

    func startWatching() {
        guard let fileURL else { return }
        watcher = FileWatcher(url: fileURL) { text in
            Task { @MainActor in self.updateText(text) }
        }
    }

    func setFollow(_ on: Bool) {
        isFollowing = on
        controller.setFollow(on)
    }

    func stop() {
        watcher?.stop()
        watcher = nil
    }

    private func openRelative(_ href: String) {
        guard let base = controller.baseDirectory else { return }
        let cleaned = href.removingPercentEncoding ?? href
        let target = cleaned.hasPrefix("/")
            ? URL(fileURLWithPath: cleaned)
            : base.appendingPathComponent(cleaned).standardizedFileURL
        if markdownExtensions.contains(target.pathExtension.lowercased()) {
            WorkspaceModel.shared.open(url: target, mode: .newTab)
        } else {
            NSWorkspace.shared.open(target)
        }
    }
}

/// The single source of truth for the workspace window: open tabs, selection,
/// and the current root folder. Also the entry point for file/URL opens routed
/// from `AppDelegate`.
@MainActor
@Observable
final class WorkspaceModel {
    static let shared = WorkspaceModel()

    var tabs: [OpenTab] = []
    var selectedTabID: OpenTab.ID?
    var rootFolder: URL?
    var sidebarMode: SidebarMode = .files

    @ObservationIgnored let settings = ReaderSettings()

    var selectedTab: OpenTab? { tabs.first { $0.id == selectedTabID } }

    // MARK: - Opening

    func open(url: URL,
              mode: OpenMode = .newTab,
              anchor: String? = nil,
              follow: Bool = false,
              theme: ThemeMode? = nil) {
        if let theme { settings.themeMode = theme }

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            openFolder(url)
            return
        }

        if let existing = tabs.first(where: { $0.fileURL == url }) {
            selectedTabID = existing.id
            if let anchor, !anchor.isEmpty { existing.controller.scrollToAnchor(anchor) }
            if follow { existing.setFollow(true) }
            activate()
            return
        }

        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let tab = OpenTab(fileURL: url, title: url.lastPathComponent)

        switch mode {
        case .reuseCurrent:
            if let sel = selectedTab, let idx = tabs.firstIndex(where: { $0.id == sel.id }) {
                sel.stop()
                tabs[idx] = tab
            } else {
                tabs.append(tab)
            }
        case .newTab, .newWindow:
            tabs.append(tab)
        }

        selectedTabID = tab.id
        tab.present(text: text,
                    settingsJSON: settings.payloadJSON,
                    baseDir: url.deletingLastPathComponent(),
                    anchor: anchor,
                    follow: follow)
        tab.startWatching()
        if rootFolder == nil { rootFolder = url.deletingLastPathComponent() }
        activate()
    }

    func openFolder(_ url: URL) {
        rootFolder = url
        sidebarMode = .files
        activate()
    }

    // MARK: - Tab management

    func closeTab(_ id: OpenTab.ID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[idx].stop()
        tabs.remove(at: idx)
        if selectedTabID == id {
            let next = idx < tabs.count ? tabs[idx] : tabs.last
            selectedTabID = next?.id
        }
    }

    func closeSelectedTab() {
        if let id = selectedTabID { closeTab(id) }
    }

    func select(_ id: OpenTab.ID) { selectedTabID = id }

    func selectNext() {
        guard let i = indexOfSelected(), !tabs.isEmpty else { return }
        selectedTabID = tabs[(i + 1) % tabs.count].id
    }

    func selectPrevious() {
        guard let i = indexOfSelected(), !tabs.isEmpty else { return }
        selectedTabID = tabs[(i - 1 + tabs.count) % tabs.count].id
    }

    func moveTab(id: OpenTab.ID, before targetID: OpenTab.ID) {
        guard id != targetID,
              let from = tabs.firstIndex(where: { $0.id == id }),
              let to = tabs.firstIndex(where: { $0.id == targetID }) else { return }
        let tab = tabs.remove(at: from)
        let insertAt = to > from ? to - 1 : to
        tabs.insert(tab, at: min(max(insertAt, 0), tabs.count))
    }

    func applySettingsToAll(_ json: String) {
        for tab in tabs { tab.controller.applySettings(json) }
    }

    func toggleFollowOnSelected() {
        guard let tab = selectedTab else { return }
        tab.setFollow(!tab.isFollowing)
    }

    // MARK: - Document actions

    func revealSelectedInFinder() {
        guard let url = selectedTab?.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Opens the current file in the system's default text editor (view here,
    /// edit there - handy for round-tripping AI docs back into Cursor/VS Code).
    func openSelectedInEditor() {
        guard let url = selectedTab?.fileURL else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-t", url.path]
        try? process.run()
    }

    // MARK: - URL scheme

    func handleURL(_ url: URL) {
        guard url.scheme == "prettydoc" else { return }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let items = comps.queryItems ?? []

        var paths: [String] = []
        var anchor: String?
        var themeStr: String?
        var mode: OpenMode = .newTab
        var follow = false

        for item in items {
            switch item.name {
            case "path": if let v = item.value { paths.append(v) }
            case "anchor": anchor = item.value
            case "theme": themeStr = item.value
            case "tab": if item.value == "reuse" { mode = .reuseCurrent }
            case "window": if item.value == "new" { mode = .newWindow }
            case "follow": if item.value == "1" || item.value == "true" { follow = true }
            case "line": break // reserved; source-line mapping is approximate for rendered Markdown
            default: break
            }
        }

        let theme = themeStr.flatMap { ThemeMode(rawValue: $0) }
        if paths.isEmpty { activate(); return }

        for (i, path) in paths.enumerated() {
            let fileURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            open(url: fileURL,
                 mode: i == 0 ? mode : .newTab,
                 anchor: i == 0 ? anchor : nil,
                 follow: follow,
                 theme: i == 0 ? theme : nil)
        }
    }

    // MARK: - Helpers

    private func indexOfSelected() -> Int? {
        guard let id = selectedTabID else { return nil }
        return tabs.firstIndex { $0.id == id }
    }

    private func activate() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Lists a directory's immediate markdown files and subdirectories, sorted with
/// folders first. Skips hidden entries and common heavy/noise directories.
@MainActor
func listMarkdownDirectory(_ url: URL) -> [URL] {
    let skip: Set<String> = ["node_modules", ".git", ".build", "DerivedData", ".svn", "Pods"]
    let fm = FileManager.default
    guard let entries = try? fm.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }

    var dirs: [URL] = []
    var files: [URL] = []
    for entry in entries {
        let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        if isDir {
            if skip.contains(entry.lastPathComponent) { continue }
            dirs.append(entry)
        } else if markdownExtensions.contains(entry.pathExtension.lowercased()) {
            files.append(entry)
        }
    }
    let byName: (URL, URL) -> Bool = { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    return dirs.sorted(by: byName) + files.sorted(by: byName)
}
