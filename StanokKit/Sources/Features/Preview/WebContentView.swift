import SwiftUI
import WebKit

struct WebContentView: NSViewRepresentable {

    final class Coordinator: NSObject, WKNavigationDelegate {

        var canGoBack = Binding<Bool>.constant(false)
        var loaded: URL?
        var lastRequestedBack = 0

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            canGoBack.wrappedValue = webView.canGoBack
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation?,
            withError error: Error
        ) {
            canGoBack.wrappedValue = webView.canGoBack
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation?,
            withError error: Error
        ) {
            canGoBack.wrappedValue = webView.canGoBack
        }
    }

    let url: URL

    @Binding
    var canGoBack: Bool

    let backRequestID: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        context.coordinator.loaded = url
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.canGoBack = $canGoBack

        if context.coordinator.lastRequestedBack != backRequestID {
            context.coordinator.lastRequestedBack = backRequestID
            webView.goBack()
            return
        }

        guard context.coordinator.loaded != url else { return }

        context.coordinator.loaded = url
        webView.load(URLRequest(url: url))
    }
}
