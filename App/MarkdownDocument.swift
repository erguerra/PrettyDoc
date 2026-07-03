import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// The system-recognized Markdown type (Daring Fireball's identifier),
    /// declared as an imported type in Info.plist.
    static let markdownDocument = UTType(importedAs: "net.daringfireball.markdown")
}

/// A read-only Markdown document. Pretty Doc is a viewer, so we only ever read.
struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.markdownDocument, .plainText, .text]
    }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = String(decoding: data, as: UTF8.self)
    }

    // Required by FileDocument, but never used by a viewing-only DocumentGroup.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
