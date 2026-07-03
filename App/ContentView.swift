import SwiftUI
import AppKit

/// The main workspace window: a file/outline sidebar, a tab strip, and the
/// document canvas.
struct WorkspaceView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @EnvironmentObject private var settings: ReaderSettings
    @State private var showInspector = false

    var body: some View {
        @Bindable var workspace = workspace

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
        } detail: {
            VStack(spacing: 0) {
                if !workspace.tabs.isEmpty {
                    TabStrip()
                    Divider()
                }
                if let tab = workspace.selectedTab {
                    WorkspaceCanvas(webView: tab.controller.webView)
                } else {
                    EmptyWorkspace()
                }
            }
        }
        .navigationTitle(workspace.selectedTab?.title ?? "Pretty Doc")
        .toolbar { toolbarContent }
        .inspector(isPresented: $showInspector) {
            TypographyControls()
                .inspectorColumnWidth(min: 260, ideal: 300, max: 380)
        }
        .onChange(of: settings.payloadJSON) { _, json in
            workspace.applySettingsToAll(json)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            if let tab = workspace.selectedTab {
                Button {
                    tab.setFollow(!tab.isFollowing)
                } label: {
                    Label("Follow", systemImage: tab.isFollowing ? "arrow.down.to.line.circle.fill" : "arrow.down.to.line.circle")
                }
                .help("Follow mode: auto-scroll to the bottom as the file grows")
            }

            Menu {
                Picker("Theme", selection: $settings.themeMode) {
                    ForEach(ThemeMode.allCases) { mode in
                        Label(mode.label, systemImage: mode.symbolName).tag(mode)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Theme", systemImage: settings.themeMode.symbolName)
            }

            Button { settings.bumpFontScale(-0.1) } label: {
                Label("Smaller Text", systemImage: "textformat.size.smaller")
            }
            Button { settings.bumpFontScale(0.1) } label: {
                Label("Larger Text", systemImage: "textformat.size.larger")
            }

            Button { showInspector.toggle() } label: {
                Label("Reading Settings", systemImage: "sidebar.trailing")
            }
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        @Bindable var workspace = workspace

        VStack(spacing: 0) {
            Picker("", selection: $workspace.sidebarMode) {
                ForEach(SidebarMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)

            Divider()

            switch workspace.sidebarMode {
            case .files:
                FilesSidebar()
            case .outline:
                OutlineSidebar()
            }
        }
    }
}

struct FilesSidebar: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        if let root = workspace.rootFolder {
            List {
                Section(root.lastPathComponent) {
                    ForEach(listMarkdownDirectory(root), id: \.self) { url in
                        if url.hasDirectoryPath {
                            DirectoryRow(url: url)
                        } else {
                            FileRow(url: url)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No folder open")
                    .foregroundStyle(.secondary)
                Button("Open Folder…") {
                    if let url = FilePanels.chooseFolder() { workspace.openFolder(url) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}

struct DirectoryRow: View {
    let url: URL
    @State private var expanded = false
    @State private var children: [URL] = []

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(children, id: \.self) { child in
                if child.hasDirectoryPath {
                    DirectoryRow(url: child)
                } else {
                    FileRow(url: child)
                }
            }
        } label: {
            Label(url.lastPathComponent, systemImage: "folder")
        }
        .onChange(of: expanded) { _, isOpen in
            if isOpen && children.isEmpty {
                children = listMarkdownDirectory(url)
            }
        }
    }
}

struct FileRow: View {
    let url: URL
    @Environment(WorkspaceModel.self) private var workspace

    private var isOpen: Bool { workspace.selectedTab?.fileURL == url }

    var body: some View {
        Button {
            workspace.open(url: url, mode: .newTab)
        } label: {
            Label(url.lastPathComponent, systemImage: "doc.text")
                .foregroundStyle(isOpen ? Color.accentColor : Color.primary)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
    }
}

struct OutlineSidebar: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        if let tab = workspace.selectedTab, !tab.outline.isEmpty {
            List(tab.outline) { heading in
                Button {
                    tab.controller.scrollToAnchor(heading.id)
                } label: {
                    Text(heading.text)
                        .lineLimit(1)
                        .padding(.leading, CGFloat(max(0, heading.level - 1)) * 12)
                        .font(heading.level <= 1 ? .body.weight(.semibold) : .body)
                        .foregroundStyle(heading.level <= 2 ? Color.primary : Color.secondary)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.sidebar)
        } else {
            ContentUnavailableViewCompat(
                title: "No Outline",
                systemImage: "list.bullet.indent",
                message: "Headings from the current document appear here."
            )
        }
    }
}

// MARK: - Tab strip

struct TabStrip: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(workspace.tabs) { tab in
                    TabChip(tab: tab)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }
}

struct TabChip: View {
    let tab: OpenTab
    @Environment(WorkspaceModel.self) private var workspace
    @State private var isTargeted = false

    private var isSelected: Bool { workspace.selectedTabID == tab.id }

    var body: some View {
        HStack(spacing: 6) {
            if tab.isFollowing {
                Image(systemName: "arrow.down.to.line").font(.caption2)
            }
            Text(tab.title)
                .lineLimit(1)
                .font(.callout)
            Button {
                workspace.closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .padding(2)
            }
            .buttonStyle(.plain)
            .help("Close Tab")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(isTargeted ? Color.accentColor : .clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { workspace.select(tab.id) }
        .draggable(tab.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let dropped = items.first, let droppedID = UUID(uuidString: dropped) else { return false }
            workspace.moveTab(id: droppedID, before: tab.id)
            return true
        } isTargeted: { isTargeted = $0 }
    }
}

// MARK: - Empty state

struct EmptyWorkspace: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Pretty Doc")
                .font(.title2.weight(.semibold))
            Text("Open a Markdown file or a folder to start reading.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Open File…") {
                    for url in FilePanels.chooseFiles() { workspace.open(url: url, mode: .newTab) }
                }
                Button("Open Folder…") {
                    if let url = FilePanels.chooseFolder() { workspace.openFolder(url) }
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Minimal stand-in so we don't depend on ContentUnavailableView specifics.
struct ContentUnavailableViewCompat: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Open panels

@MainActor
enum FilePanels {
    static func chooseFiles() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.markdownDocument, .plainText, .text]
        return panel.runModal() == .OK ? panel.urls : []
    }

    static func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.urls.first : nil
    }
}

// MARK: - Reusable reading controls (inspector + Preferences)

struct TypographyControls: View {
    @EnvironmentObject private var settings: ReaderSettings

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $settings.themeMode) {
                    ForEach(ThemeMode.allCases) { Text($0.label).tag($0) }
                }
                Picker("Font", selection: $settings.fontFamily) {
                    ForEach(ReaderFont.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Layout") {
                Picker("Reading Width", selection: $settings.readingWidth) {
                    ForEach(ReadingWidth.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Toggle("Scale text with window", isOn: $settings.fluidScaling)

                if settings.readingWidth == .comfortable {
                    LabeledSlider(
                        title: "Column Width",
                        value: $settings.maxWidthCh,
                        range: 50...110,
                        step: 1,
                        format: { "\(Int($0)) ch" }
                    )
                }
            }

            Section("Typography") {
                LabeledSlider(
                    title: "Text Size",
                    value: $settings.fontScale,
                    range: 0.7...2.0,
                    step: 0.05,
                    format: { String(format: "%.0f%%", $0 * 100) }
                )
                LabeledSlider(
                    title: "Line Height",
                    value: $settings.lineHeight,
                    range: 1.2...2.2,
                    step: 0.05,
                    format: { String(format: "%.2f", $0) }
                )
                LabeledSlider(
                    title: "Letter Spacing",
                    value: $settings.letterSpacing,
                    range: -0.02...0.12,
                    step: 0.005,
                    format: { String(format: "%.3f em", $0) }
                )
            }

            Section {
                Button("Reset Typography") { settings.resetTypography() }
            }
        }
        .formStyle(.grouped)
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}
