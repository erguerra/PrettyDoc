# Contributing to Pretty Doc

Thanks for your interest in improving Pretty Doc! This document explains how to
build the project and the conventions we follow.

## Prerequisites

- macOS 14 (Sonoma) or later
- Xcode 16 or later (Swift 6)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Building

The Xcode project is generated from [`project.yml`](project.yml) and is *not*
checked into git. Generate it, then build:

```bash
xcodegen generate
open PrettyDoc.xcodeproj          # develop in Xcode
# ...or from the command line:
xcodebuild -project PrettyDoc.xcodeproj -scheme PrettyDoc \
  -configuration Debug -destination 'platform=macOS' build
```

If you add, remove, or rename source files, run `xcodegen generate` again.

## Project layout

```
project.yml                 XcodeGen spec (source of truth for the Xcode project)
App/                        SwiftUI sources
  PrettyDocApp.swift        App entry point, AppDelegate, menu commands
  WorkspaceModel.swift      Tabs, file navigation, URL-scheme routing
  ContentView.swift         Workspace UI: sidebar, tab strip, reading controls
  MarkdownWebView.swift     Per-tab WKWebView controller + canvas host
  FileWatcher.swift         Live-reload via DispatchSource
  Preferences.swift         Reader settings model
  CLIInstaller.swift        Installs the prettydoc helper
  Resources/web/            The canvas: index.html, app.js, themes.css, vendored libs
Scripts/                    prettydoc CLI + installer
docs/                       Architecture and integration docs
Samples/                    Demo Markdown
```

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for the architecture overview.

## Coding conventions

- Swift: 4-space indentation, follow the surrounding style. Prefer small, focused
  types. Keep UI concerns in views and state in `WorkspaceModel` / `ReaderSettings`.
- Web canvas (`App/Resources/web/`): tab indentation, no build step - plain ES5-ish
  JavaScript so it runs directly in `WKWebView`.
- Comments explain *why*, not *what*. Avoid narrating the code.
- Don't commit the generated `PrettyDoc.xcodeproj`.

## Vendored libraries

Third-party browser libraries live under `App/Resources/web/vendor/` and are
committed as-is (marked `linguist-vendored`). They are copied from npm:
`markdown-it`, `@highlightjs/cdn-assets`, `mermaid` (v9, single-file UMD build),
and `katex`. Please keep them pinned and note version bumps in the changelog.

## Submitting changes

1. Fork and create a topic branch.
2. Make your change; ensure `xcodebuild ... build` succeeds.
3. Update [CHANGELOG.md](CHANGELOG.md) under "Unreleased".
4. Open a pull request describing the change and how you tested it.

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
