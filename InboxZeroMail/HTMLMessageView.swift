import SwiftUI
import WebKit

enum HTMLNavigationDecision: Equatable {
    case allowInWebView
    case openExternally
    case cancel
}

enum HTMLContentSecurity {
    static func sanitizedBody(
        _ html: String,
        allowsRemoteContent: Bool,
        imageProxy: ImageProxyConfiguration? = nil
    ) -> String {
        var sanitized = html

        let patterns = [
            "(?is)<script\\b[^>]*>.*?</script>",
            "(?is)<meta\\b[^>]*http-equiv\\s*=\\s*([\"'])?refresh\\1?[^>]*>",
            "(?is)<base\\b[^>]*>",
            "(?is)<link\\b[^>]*>",
            "(?is)<(iframe|frame|frameset|object|embed|form|video|audio|svg)\\b[^>]*>.*?</\\1>",
            "(?is)<(input|button|select|option|textarea|source)\\b[^>]*\\/?>",
        ]

        for pattern in patterns {
            sanitized = sanitized.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        sanitized = sanitized
            .replacingOccurrences(
                of: "(?i)\\son[a-z]+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "(?i)(href|src)\\s*=\\s*([\"'])\\s*(javascript:|data:text/html)[^\"']*\\2",
                with: "$1=$2about:blank$2",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "(?i)@import\\s+(url\\()?['\"]https?://[^;'\")]+['\"]\\)?;?",
                with: "",
                options: .regularExpression
            )

        if allowsRemoteContent {
            if let imageProxy {
                sanitized = rewriteRemoteAssetURLs(in: sanitized, using: imageProxy)
            }
        } else {
            sanitized = sanitized
                .replacingOccurrences(
                    of: "(?i)(\\b(?:src|poster|background)\\s*=\\s*[\"'])https?://[^\"']*([\"'])",
                    with: "$1about:blank$2",
                    options: .regularExpression
                )
                .replacingOccurrences(
                    of: "(?i)(\\b(?:src|poster|background)\\s*=\\s*)https?://[^\\s>]+",
                    with: "$1about:blank",
                    options: .regularExpression
                )
                .replacingOccurrences(
                    of: "(?i)\\ssrcset\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)",
                    with: "",
                    options: .regularExpression
                )
                .replacingOccurrences(
                    of: "(?i)url\\((\\s*[\"']?)https?://[^)]+\\)",
                    with: "url(about:blank)",
                    options: .regularExpression
                )
        }

        return sanitized
    }

    static func securityHeaders(
        allowsRemoteContent: Bool,
        imageProxy: ImageProxyConfiguration?
    ) -> String {
        let imageSourceDirective = imageSourceDirective(
            allowsRemoteContent: allowsRemoteContent,
            imageProxy: imageProxy
        )

        return """
        <meta http-equiv="Content-Security-Policy" content="
            default-src 'none';
            style-src 'unsafe-inline';
            img-src \(imageSourceDirective);
            font-src 'none';
            media-src 'none';
            connect-src 'none';
            manifest-src 'none';
            prefetch-src 'none';
            worker-src 'none';
            child-src 'none';
            script-src 'none';
            frame-src 'none';
            object-src 'none';
            base-uri 'none';
            form-action 'none';
        ">
        <meta http-equiv="X-Content-Type-Options" content="nosniff">
        """
    }

    static func navigationDecision(url: URL?, navigationType: WKNavigationType, isMainFrame: Bool) -> HTMLNavigationDecision {
        guard let url else { return .allowInWebView }

        let scheme = url.scheme?.lowercased() ?? ""
        if navigationType == .linkActivated {
            switch scheme {
            case "http", "https", "mailto":
                return .openExternally
            default:
                return .cancel
            }
        }

        if isMainFrame, scheme.isEmpty || scheme == "about" || scheme == "data" {
            return .allowInWebView
        }

        return .cancel
    }

    private static func imageSourceDirective(
        allowsRemoteContent: Bool,
        imageProxy: ImageProxyConfiguration?
    ) -> String {
        guard allowsRemoteContent else { return "data:" }
        return "data: \(imageProxy?.origin ?? "https:")"
    }

    private static func rewriteRemoteAssetURLs(
        in html: String,
        using imageProxy: ImageProxyConfiguration
    ) -> String {
        var rewritten = html

        rewritten = replacingMatches(
            in: rewritten,
            pattern: #"(?i)(\b(?:src|poster|background)\s*=\s*["'])(https?://[^"']*)(["'])"#
        ) { groups in
            "\(groups[1])\(imageProxy.proxiedAssetURL(for: groups[2]))\(groups[3])"
        }

        rewritten = replacingMatches(
            in: rewritten,
            pattern: #"(?i)(\b(?:src|poster|background)\s*=\s*)(https?://[^\s>]+)"#
        ) { groups in
            "\(groups[1])\(imageProxy.proxiedAssetURL(for: groups[2]))"
        }

        rewritten = replacingMatches(
            in: rewritten,
            pattern: #"(?i)(\bsrcset\s*=\s*["'])([^"']*)(["'])"#
        ) { groups in
            "\(groups[1])\(rewriteSrcset(groups[2], using: imageProxy))\(groups[3])"
        }

        rewritten = replacingMatches(
            in: rewritten,
            pattern: #"(?i)(\bsrcset\s*=\s*)([^\s>]+)"#
        ) { groups in
            "\(groups[1])\(rewriteSrcset(groups[2], using: imageProxy))"
        }

        rewritten = replacingMatches(
            in: rewritten,
            pattern: #"(?i)url\((\s*["']?)(https?://[^)"']+)(["']?\s*)\)"#
        ) { groups in
            "url(\(groups[1])\(imageProxy.proxiedAssetURL(for: groups[2]))\(groups[3]))"
        }

        return rewritten
    }

    private static func rewriteSrcset(
        _ srcset: String,
        using imageProxy: ImageProxyConfiguration
    ) -> String {
        let candidates = splitSrcsetCandidates(srcset)
        guard candidates.isEmpty == false else { return srcset }

        let rewrittenCandidates = candidates.map { candidate -> String in
            let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separatorIndex = trimmedCandidate.firstIndex(where: \.isWhitespace) else {
                return imageProxy.proxiedAssetURL(for: trimmedCandidate)
            }

            let url = String(trimmedCandidate[..<separatorIndex])
            let descriptor = String(trimmedCandidate[separatorIndex...])
            return "\(imageProxy.proxiedAssetURL(for: url))\(descriptor)"
        }

        return rewrittenCandidates.joined(separator: ", ")
    }

    private static func splitSrcsetCandidates(_ srcset: String) -> [String] {
        var candidates: [String] = []
        var current = ""
        var activeQuote: Character?
        var parenthesesDepth = 0

        for character in srcset {
            if let quote = activeQuote {
                current.append(character)
                if character == quote {
                    activeQuote = nil
                }
                continue
            }

            switch character {
            case "\"", "'":
                activeQuote = character
                current.append(character)
            case "(":
                parenthesesDepth += 1
                current.append(character)
            case ")":
                parenthesesDepth = max(0, parenthesesDepth - 1)
                current.append(character)
            case "," where parenthesesDepth == 0:
                let candidate = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if candidate.isEmpty == false {
                    candidates.append(candidate)
                }
                current = ""
            default:
                current.append(character)
            }
        }

        let candidate = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.isEmpty == false {
            candidates.append(candidate)
        }

        return candidates
    }

    private static func replacingMatches(
        in input: String,
        pattern: String,
        options: NSRegularExpression.Options = [],
        transform: ([String]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return input
        }

        let searchRange = NSRange(input.startIndex..., in: input)
        let matches = regex.matches(in: input, range: searchRange)
        guard matches.isEmpty == false else { return input }

        let mutableString = NSMutableString(string: input)
        for match in matches.reversed() {
            let groups = (0..<match.numberOfRanges).map { index -> String in
                let range = match.range(at: index)
                guard range.location != NSNotFound,
                      let swiftRange = Range(range, in: input)
                else {
                    return ""
                }
                return String(input[swiftRange])
            }
            mutableString.replaceCharacters(in: match.range, with: transform(groups))
        }

        return mutableString as String
    }
}

/// WKWebView subclass that forwards scroll events to the parent ScrollView
/// instead of consuming them internally.
fileprivate final class NonScrollingWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

/// Renders HTML email content in a WKWebView with security defaults:
/// - Scripts disabled
/// - Dark mode support
/// - Auto-sizing height to content
/// - Internal scrolling disabled (parent ScrollView handles scrolling)
struct HTMLMessageView: NSViewRepresentable {
    let htmlBody: String
    let allowsRemoteContent: Bool

    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = prefs

        let webView = NonScrollingWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        // Force light appearance — the app content area is always light,
        // but WKWebView follows system dark mode which produces invisible
        // light-on-light text when the Mac is in dark mode.
        webView.appearance = NSAppearance(named: .aqua)

        // Inject height reporting script (runs after load)
        let heightScript = WKUserScript(
            source: """
                window.addEventListener('load', function() {
                    window.webkit.messageHandlers.heightChanged.postMessage(
                        document.body.scrollHeight
                    );
                });
                new ResizeObserver(function() {
                    window.webkit.messageHandlers.heightChanged.postMessage(
                        document.body.scrollHeight
                    );
                }).observe(document.body);
                """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(heightScript)
        webView.configuration.userContentController.add(context.coordinator, name: "heightChanged")

        context.coordinator.latestHTML = wrapHTML(htmlBody)
        context.coordinator.isReadyToLoad = true
        context.coordinator.loadLatestHTML(into: webView)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.latestHTML = wrapHTML(htmlBody)
        guard context.coordinator.isReadyToLoad else { return }
        context.coordinator.loadLatestHTML(into: webView)
    }

    private func wrapHTML(_ html: String) -> String {
        let imageProxy = ImageProxyConfiguration.resolve()
        let sanitized = HTMLContentSecurity.sanitizedBody(
            html,
            allowsRemoteContent: allowsRemoteContent,
            imageProxy: imageProxy
        )
        let securityHeaders = HTMLContentSecurity.securityHeaders(
            allowsRemoteContent: allowsRemoteContent,
            imageProxy: imageProxy
        )

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        \(securityHeaders)
        <style>
            :root {
                color-scheme: light dark;
            }
            html, body {
                overflow: hidden;
            }
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
                font-size: 13px;
                line-height: 1.5;
                color: #1a1b26;
                margin: 0;
                padding: 0;
                word-wrap: break-word;
                overflow-wrap: break-word;
            }
            a { color: #4085f6; text-decoration: none; }
            a:hover { text-decoration: underline; }
            img {
                max-width: 100%;
                height: auto;
            }
            blockquote {
                border-left: 3px solid #d0d4dc;
                margin: 8px 0;
                padding: 4px 12px;
                color: #72747e;
            }
            pre, code {
                font-family: "SF Mono", Menlo, monospace;
                font-size: 12px;
                background: #f4f5f7;
                border-radius: 4px;
                padding: 2px 4px;
            }
            table { border-collapse: collapse; max-width: 100%; }
            td, th { padding: 4px 8px; }
        </style>
        </head>
        <body>\(sanitized)</body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: HTMLMessageView
        var latestHTML = ""
        var lastLoadedHTML = ""
        var isReadyToLoad = false

        init(parent: HTMLMessageView) {
            self.parent = parent
        }

        func loadLatestHTML(into webView: WKWebView) {
            guard latestHTML != lastLoadedHTML else { return }
            lastLoadedHTML = latestHTML
            webView.loadHTMLString(latestHTML, baseURL: nil)
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightChanged", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    if height > 20 && height != self.parent.contentHeight {
                        self.parent.contentHeight = height
                    }
                }
            }
        }

        // Block navigation to external links — open in default browser instead
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            let decision = HTMLContentSecurity.navigationDecision(
                url: navigationAction.request.url,
                navigationType: navigationAction.navigationType,
                isMainFrame: navigationAction.targetFrame?.isMainFrame ?? false
            )

            if decision == .openExternally, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                return .cancel
            }

            switch decision {
            case .allowInWebView:
                return .allow
            case .openExternally, .cancel:
                return .cancel
            }
        }
    }
}

/// Plain text email renderer with linkification
struct PlainTextMessageView: View {
    let text: String

    var body: some View {
        Text(attributedText)
            .font(.system(size: 13, design: .default))
            .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.15))
            .textSelection(.enabled)
            .lineSpacing(4)
    }

    private var attributedText: AttributedString {
        var result = AttributedString(text)
        // Linkify URLs
        let urlPattern = try? NSRegularExpression(pattern: "https?://[^\\s<>\"]+", options: [])
        let nsRange = NSRange(text.startIndex..., in: text)
        if let matches = urlPattern?.matches(in: text, range: nsRange) {
            for match in matches {
                if let range = Range(match.range, in: text),
                   let attrRange = Range(range, in: result),
                   let url = URL(string: String(text[range])) {
                    result[attrRange].link = url
                    result[attrRange].foregroundColor = .blue
                }
            }
        }
        return result
    }
}
