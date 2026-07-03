import AppKit

/// Installs a `prettydoc` command-line helper so terminals and AI tools
/// (Claude Code, Cursor, ...) can open documents with `prettydoc file.md`.
///
/// The helper is a tiny shell script that shells out to `open -a "Pretty Doc"`.
/// We try to write it into `/usr/local/bin`; if that isn't writable (common on
/// stock macOS), we fall back to `~/.local/bin` and tell the user how to put it
/// on their PATH.
enum CLIInstaller {
    static let scriptBody = """
    #!/bin/sh
    # Pretty Doc command-line launcher.
    exec open -a "Pretty Doc" "$@"
    """

    enum InstallResult {
        case installed(path: URL, onPath: Bool)
        case failed(String)
    }

    static func install() -> InstallResult {
        let fm = FileManager.default
        let candidates: [URL] = [
            URL(fileURLWithPath: "/usr/local/bin"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin")
        ]

        var lastError = "No writable install location found."
        for dir in candidates {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                let target = dir.appendingPathComponent("prettydoc")
                if fm.fileExists(atPath: target.path) {
                    try? fm.removeItem(at: target)
                }
                try scriptBody.write(to: target, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
                let onPath = pathEntries().contains(dir.standardizedFileURL.path)
                return .installed(path: target, onPath: onPath)
            } catch {
                lastError = error.localizedDescription
                continue
            }
        }
        return .failed(lastError)
    }

    private static func pathEntries() -> [String] {
        (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).standardizedFileURL.path }
    }

    /// Runs the install and shows a native alert describing the outcome.
    @MainActor
    static func installAndReport() {
        let alert = NSAlert()
        switch install() {
        case let .installed(path, onPath):
            alert.messageText = "Command-Line Tool Installed"
            if onPath {
                alert.informativeText = "Installed to \(path.path).\n\nYou can now run:\n    prettydoc file.md"
            } else {
                let dir = path.deletingLastPathComponent().path
                alert.informativeText = """
                Installed to \(path.path).

                This folder isn't on your PATH yet. Add it, e.g.:
                    echo 'export PATH="\(dir):$PATH"' >> ~/.zshrc

                Then run:  prettydoc file.md
                """
            }
            alert.alertStyle = .informational
        case let .failed(message):
            alert.messageText = "Couldn't Install Command-Line Tool"
            alert.informativeText = """
            \(message)

            You can install it manually:
                sudo tee /usr/local/bin/prettydoc >/dev/null <<'EOF'
            \(scriptBody)
            EOF
                sudo chmod +x /usr/local/bin/prettydoc
            """
            alert.alertStyle = .warning
        }
        alert.runModal()
    }
}
