# Security Policy

## Supported versions

Pretty Doc is pre-1.0. Security fixes are applied to the latest release only.

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Instead, use GitHub's private vulnerability reporting:
**Security -> Report a vulnerability** on the
[repository](https://github.com/erguerra/PrettyDoc/security/advisories/new).

Include steps to reproduce and the impact you observed. We aim to acknowledge
reports within a few days.

## Notes on the rendering sandbox

Documents are rendered in a `WKWebView` with raw HTML disabled in the Markdown
parser and JavaScript execution limited to the app's own bundled scripts.
External links are opened in the user's browser rather than inside the canvas.
