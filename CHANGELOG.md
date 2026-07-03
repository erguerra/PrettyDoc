# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-07-03

### Changed

- Release builds are now **signed with a Developer ID and notarized by Apple**,
  so downloads open without Gatekeeper warnings.

## [0.1.0] - 2026-07-03

Initial public release.

### Added

- Native macOS Markdown reader built with SwiftUI + a `WKWebView` canvas (no
  Electron; uses the OS's built-in WebKit).
- **Responsive typography** that scales the base font with the window width,
  plus manual text size, line-height, and letter-spacing controls.
- Reading-width modes (Fluid / Comfortable) and Light / Dark / Sepia themes.
- Rendering for headings, emphasis, links, images, tables, task lists,
  blockquotes, fenced code with syntax highlighting, **Mermaid** diagrams, and
  **KaTeX** math.
- **Workspace**: open a folder, browse Markdown in a sidebar, open documents as
  tabs, and navigate via an auto-generated outline.
- **Live reload** and **Follow mode** (auto-scroll to the bottom as a file grows).
- **Terminal / AI-tool integration**: the `prettydoc` CLI (flags, `#anchor`
  deep-links, stdin streaming) and a `prettydoc://` URL scheme.
- Copy buttons on code blocks; Reveal in Finder and Open in Editor actions.

[Unreleased]: https://github.com/erguerra/PrettyDoc/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/erguerra/PrettyDoc/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/erguerra/PrettyDoc/releases/tag/v0.1.0
