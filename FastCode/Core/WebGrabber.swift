import SwiftUI
import WebKit

// 内嵌 WebView 抓取器。
// 思路：登录由页面的正规 JS 完成，签名（拼多多的 anti_content 之类）也由页面自己算，
// 我们只在 documentStart 注入钩子，把 XHR / fetch 的响应捞出来，再读一遍渲染后的 DOM。
final class WebGrabber: NSObject, ObservableObject {

    @Published var progress: String = ""
    @Published var ready: Bool = false
    @Published var caught: [CaughtResponse] = []
    @Published var items: [PackageItem] = []
    @Published var rawDump: String = ""

    struct CaughtResponse: Identifiable {
        let id = UUID()
        let url: String
        let bytes: Int
        let preview: String
    }

    let webView: WKWebView
    private let platform: GrabPlatform
    private let userContentController: WKUserContentController
    private var pendingGrab: ((String) -> Void)?

    init(platform: GrabPlatform) {
        self.platform = platform

        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()

        let uc = WKUserContentController()
        uc.addUserScript(WKUserScript(
            source: WebGrabber.hookScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        cfg.userContentController = uc
        userContentController = uc

        webView = WKWebView(frame: .zero, configuration: cfg)
        // 用 Safari 的 UA，避免被各平台识别成 App 内 WebView 而砍掉功能
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.2 Mobile/15E148 Safari/604.1"
        webView.allowsBackForwardNavigationGestures = true

        super.init()

        uc.add(self, name: "fc")
        webView.navigationDelegate = self
    }

    deinit {
        // 这里只解绑消息处理器，不碰 webView 本身，避免释放顺序问题
        userContentController.removeScriptMessageHandler(forName: "fc")
    }

    // WKUserContentController 会强引用 handler，不主动断开就会把整个 grabber 留住
    func teardown() {
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "fc")
        webView.navigationDelegate = nil
    }

    // MARK: - 加载

    func load() {
        guard let url = platform.entryURL else { return }
        progress = "加载 \(url.host ?? "")"
        var req = URLRequest(url: url)
        req.setValue("https://m.pinduoduo.com/", forHTTPHeaderField: "Referer")
        webView.load(req)
    }

    func reload() {
        caught.removeAll()
        items.removeAll()
        rawDump = ""
        load()
    }

    // MARK: - 抓取

    func grab() {
        progress = "读取页面…"
        webView.evaluateJavaScript(WebGrabber.dumpScript) { [weak self] result, error in
            guard let self else { return }
            if let err = error {
                self.progress = "抓取失败：\(err.localizedDescription)"
                return
            }
            guard let json = result as? String else {
                self.progress = "页面没有返回数据"
                return
            }
            self.rawDump = json
            self.parse(json)
        }
    }

    private func parse(_ json: String) {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            progress = "返回格式异常"
            return
        }

        let text = obj["text"] as? String ?? ""
        let images = obj["images"] as? [String] ?? []

        var found: [PackageItem] = []
        // 取件码：页面上一般写作「取件码：1234」「取件码 1234-5-6」这类
        let patterns = [
            "取件码[:：\\s]*([A-Za-z0-9\\-]{3,12})",
            "取货码[:：\\s]*([A-Za-z0-9\\-]{3,12})",
            "提货码[:：\\s]*([A-Za-z0-9\\-]{3,12})"
        ]
        var codes: [String] = []
        for p in patterns {
            if let re = try? NSRegularExpression(pattern: p) {
                let ns = text as NSString
                for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                    if m.numberOfRanges > 1 {
                        let c = ns.substring(with: m.range(at: 1))
                        if !codes.contains(c) { codes.append(c) }
                    }
                }
            }
        }

        // 先把每个取件码当一条记录，缩略图按顺序配
        for (i, code) in codes.enumerated() {
            found.append(PackageItem(
                platform: platform.title,
                title: "包裹 \(i + 1)",
                thumbnail: i < images.count ? images[i] : images.first,
                pickupCode: code,
                station: nil,
                status: "待取件"
            ))
        }

        items = found
        progress = codes.isEmpty
            ? "没识别到取件码，看下面的原文"
            : "识别到 \(codes.count) 个取件码"
    }

    // MARK: - 注入脚本

    // documentStart 注入：把 XHR / fetch 的响应捞出来
    static let hookScript = """
    (function(){
      if (window.__fcHooked) return;
      window.__fcHooked = true;

      function post(url, body) {
        try {
          var s = String(body || '');
          window.webkit.messageHandlers.fc.postMessage({
            kind: 'xhr', url: String(url || ''), len: s.length, body: s.slice(0, 400000)
          });
        } catch (e) {}
      }

      var XO = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function(m, u) {
        this.__fcUrl = u;
        return XO.apply(this, arguments);
      };
      var XS = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.send = function() {
        var self = this;
        this.addEventListener('load', function() {
          try { post(self.__fcUrl, self.responseText); } catch (e) {}
        });
        return XS.apply(this, arguments);
      };

      var F = window.fetch;
      if (F) {
        window.fetch = function() {
          var a = arguments[0];
          var url = (typeof a === 'string') ? a : (a && a.url) || '';
          return F.apply(this, arguments).then(function(resp) {
            try {
              resp.clone().text().then(function(t){ post(url, t); }).catch(function(){});
            } catch (e) {}
            return resp;
          });
        };
      }
    })();
    """

    // 抓取时执行：把页面可见文本和图片捞出来
    static let dumpScript = """
    (function(){
      var text = document.body ? document.body.innerText : '';
      var imgs = [];
      var all = document.images || [];
      for (var i = 0; i < all.length && imgs.length < 40; i++) {
        var s = all[i].currentSrc || all[i].src || '';
        if (s && s.indexOf('data:') !== 0 && imgs.indexOf(s) < 0) imgs.push(s);
      }
      return JSON.stringify({
        url: location.href,
        title: document.title || '',
        text: text.slice(0, 30000),
        images: imgs
      });
    })();
    """
}

// MARK: - 消息与导航

extension WebGrabber: WKScriptMessageHandler, WKNavigationDelegate {

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "fc",
              let dict = message.body as? [String: Any],
              let url = dict["url"] as? String,
              let body = dict["body"] as? String
        else { return }

        // 只留看起来像数据接口的
        let lower = url.lowercased()
        let interesting = lower.contains("/api/") || lower.contains("vodka") || lower.contains("mtop")
            || lower.contains("package") || lower.contains("order") || lower.contains("logistics")
        guard interesting else { return }

        DispatchQueue.main.async {
            if self.caught.count >= 40 { self.caught.removeFirst() }
            self.caught.append(CaughtResponse(
                url: url,
                bytes: body.count,
                preview: String(body.prefix(400))
            ))
            self.progress = "已捕获 \(self.caught.count) 个接口响应"
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        progress = "页面已加载，登录后点「抓取」"
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        progress = "加载失败：\(error.localizedDescription)"
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        progress = "加载失败：\(error.localizedDescription)"
    }

    // 拦掉 pinduoduo:// 这类外部 scheme，别让页面把 App 踢出去
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        if let scheme = url.scheme?.lowercased(),
           scheme != "http", scheme != "https", scheme != "about", scheme != "file" {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

// MARK: - SwiftUI 包装

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
