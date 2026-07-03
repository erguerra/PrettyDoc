import Foundation

/// Watches a single file for on-disk changes and reports its new contents.
///
/// Handles the common "atomic save" pattern used by most editors and AI tools
/// (write to a temp file, then rename over the original). That invalidates the
/// original file descriptor, so on delete/rename we re-arm the watch against the
/// path after a short debounce and re-read.
/// All mutable state is confined to the private serial `queue`, so this type is
/// safe to treat as `Sendable` despite holding mutable members.
final class FileWatcher: @unchecked Sendable {
    private let url: URL
    private let onChange: @Sendable (String) -> Void
    private let queue = DispatchQueue(label: "com.eduardoguerra.prettydoc.filewatcher")

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private var debounceWork: DispatchWorkItem?

    init(url: URL, onChange: @escaping @Sendable (String) -> Void) {
        self.url = url
        self.onChange = onChange
        start()
    }

    deinit {
        stop()
    }

    private func start() {
        queue.async { [weak self] in
            self?.arm()
        }
    }

    private func arm() {
        stopSource()

        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            // File may be temporarily gone during an atomic replace; retry shortly.
            scheduleReArm()
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .delete, .rename, .link, .revoke],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
                // Original file was replaced/removed. Re-arm against the path.
                self.scheduleReArm()
            } else {
                self.emitChange()
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        self.source = source
        source.resume()
    }

    private func scheduleReArm() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.arm()
            self.emitChange()
        }
        debounceWork = work
        queue.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func emitChange() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard let text = try? String(contentsOf: self.url, encoding: .utf8) else { return }
            // The callback is responsible for hopping to the right actor.
            self.onChange(text)
        }
        debounceWork = work
        // Small debounce so multiple rapid writes coalesce into one reload.
        queue.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    private func stopSource() {
        source?.cancel()
        source = nil
    }

    func stop() {
        queue.async { [weak self] in
            self?.debounceWork?.cancel()
            self?.stopSource()
        }
    }
}
