import AppKit
import Foundation
import WebKit
import AICheckerCore

/// User-initiated, first-party site viewer. No JavaScript injection, no cookie
/// reading, no interception of login flows, no quota claims or background polling.
/// Separate persistent website stores on macOS 14+; ephemeral on macOS 13.
final class ConsumerWebSession: NSObject, WKNavigationDelegate {
    let destination: ConsumerWebDestination
    private let storeID: UUID
    private let webView: WKWebView
    private var window: NSWindow?
    private var location: NSTextField?

    init(destination: ConsumerWebDestination, storeID: UUID) {
        self.destination = destination
        self.storeID = storeID
        let config = WKWebViewConfiguration()
        if #available(macOS 14.0, *) {
            config.websiteDataStore = WKWebsiteDataStore(forIdentifier: storeID)
        } else {
            config.websiteDataStore = .nonPersistent()
        }
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 950, height: 640), configuration: config)
        super.init()
        webView.navigationDelegate = self
    }

    func show() {
        guard let url = destination.url else { return }
        if window == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 950, height: 680),
                                 styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                 backing: .buffered, defer: false)
            panel.title = "AI Checker — \(destination.name)公式サイト（残量は自動取得しません）"
            panel.isReleasedWhenClosed = false
            panel.minSize = NSSize(width: 620, height: 460)
            let container = NSView(frame: NSRect(x: 0, y: 0, width: 950, height: 680))
            let label = NSTextField(labelWithString: "接続先: \(url.host ?? "") — 手動確認専用")
            label.frame = NSRect(x: 14, y: 650, width: 920, height: 20)
            label.autoresizingMask = [.width, .minYMargin]
            label.lineBreakMode = .byTruncatingMiddle
            container.addSubview(label)
            webView.frame = NSRect(x: 0, y: 0, width: 950, height: 640)
            webView.autoresizingMask = [.width, .height]
            container.addSubview(webView)
            panel.contentView = container
            panel.center()
            window = panel
            location = label
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if webView.url == nil { webView.load(URLRequest(url: url)) }
    }

    private func origin(_ url: URL?) -> String {
        guard let url, url.scheme == "https", let host = url.host else { return "読み込み中" }
        return "https://\(host)" // Never display OAuth codes or URL query parameters.
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased()
        if scheme == "https" {
            // Show the host of each new navigation, not the previous page's host.
            location?.stringValue = "現在の接続先: \(origin(navigationAction.request.url)) — 手動確認専用"
        }
        decisionHandler(scheme == "https" || scheme == "about" ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        location?.stringValue = "現在の接続先: \(origin(webView.url)) — 手動確認専用"
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        location?.stringValue = "現在の接続先: \(origin(webView.url)) — 手動確認専用"
    }

    func stop() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        window?.contentView = nil
        window?.close()
        window = nil
        location = nil
    }

    static func erase(storeID: UUID, completion: @escaping (Error?) -> Void) {
        if #available(macOS 14.0, *) {
            WKWebsiteDataStore.remove(forIdentifier: storeID, completionHandler: completion)
        } else {
            completion(nil) // macOS 13 never persists browser login data.
        }
    }
}
