import SwiftUI
import WebKit

/// A heading extracted from the rendered document, used for the outline sidebar.
struct Heading: Identifiable, Hashable, Sendable {
    let id: String   // slug / element id
    let level: Int
    let text: String
}

/// Owns a single long-lived `WKWebView` that renders one document. Each open tab
/// has its own controller so switching tabs preserves scroll position and never
/// re-renders. The native shell drives it via `render`/`applySettings`/etc., and
/// receives link + outline events through the coordinator.
@MainActor
final class MarkdownWebController {
    let webView: WKWebView

    var baseDirectory: URL?
    var onOpenExternal: (URL) -> Void = { _ in }
    var onOpenRelativeHref: (String) -> Void = { _ in }
    var onOutline: ([Heading]) -> Void = { _ in }

    private let coordinator = Coordinator()
    private var isLoaded = false
    private var pending: [String] = []

    init() {
        let userContent = WKUserContentController()
        let config = WKWebViewConfiguration()
        config.userContentController = userContent
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // transparent; CSS paints the bg
        webView.allowsMagnification = true

        coordinator.owner = self
        userContent.add(coordinator, name: "bridge")
        webView.navigationDelegate = coordinator

        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web") {
            webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
        }
    }

    // MARK: - Commands into the canvas

    func render(markdown: String) {
        evaluate("window.PD && window.PD.setContent(\(Self.jsString(markdown)));")
    }

    func applySettings(_ json: String) {
        evaluate("window.PD && window.PD.setSettings(\(json));")
    }

    func scrollToAnchor(_ slug: String) {
        evaluate("window.PD && window.PD.scrollToAnchor(\(Self.jsString(slug)));")
    }

    func setFollow(_ on: Bool) {
        evaluate("window.PD && window.PD.setFollow(\(on ? "true" : "false"));")
    }

    // MARK: - Internal

    fileprivate func markLoaded() {
        isLoaded = true
        for js in pending { webView.evaluateJavaScript(js, completionHandler: nil) }
        pending.removeAll()
    }

    private func evaluate(_ js: String) {
        if isLoaded {
            webView.evaluateJavaScript(js, completionHandler: nil)
        } else {
            pending.append(js)
        }
    }

    /// Encode a Swift string as a JS string literal.
    static func jsString(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [string]),
              let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return String(json.dropFirst().dropLast())
    }

    // MARK: - Coordinator (delegate + JS bridge, runs on the main thread)

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var owner: MarkdownWebController?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            MainActor.assumeIsolated { owner?.markLoaded() }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               let scheme = url.scheme,
               ["http", "https", "mailto"].contains(scheme) {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            MainActor.assumeIsolated {
                guard let owner else { return }
                switch type {
                case "openExternal":
                    if let href = body["href"] as? String, let url = URL(string: href) {
                        owner.onOpenExternal(url)
                    }
                case "openRelative":
                    if let href = body["href"] as? String {
                        owner.onOpenRelativeHref(href)
                    }
                case "outline":
                    let items = (body["items"] as? [[String: Any]]) ?? []
                    let headings: [Heading] = items.compactMap { d in
                        guard let id = d["id"] as? String,
                              let level = d["level"] as? Int,
                              let text = d["text"] as? String else { return nil }
                        return Heading(id: id, level: level, text: text)
                    }
                    owner.onOutline(headings)
                default:
                    break
                }
            }
        }
    }
}

/// Hosts the selected tab's persistent web view. On selection change we simply
/// reparent the chosen `WKWebView` into the container, so every tab keeps its
/// own scroll position and rendered DOM.
struct WorkspaceCanvas: NSViewRepresentable {
    let webView: WKWebView?

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let webView else {
            container.subviews.forEach { $0.removeFromSuperview() }
            return
        }
        if webView.superview !== container {
            container.subviews.forEach { $0.removeFromSuperview() }
            webView.frame = container.bounds
            webView.autoresizingMask = [.width, .height]
            container.addSubview(webView)
        }
    }
}
