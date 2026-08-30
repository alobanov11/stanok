import SwiftUI
import WebKit

struct WebContentView: NSViewRepresentable {

    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }

        webView.load(URLRequest(url: url))
    }
}
