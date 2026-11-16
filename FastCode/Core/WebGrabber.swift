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
    // 登录态诊断：cookie 键名 / localStorage 键名 / 被重写的请求数
    @Published var authNote: String = ""

    struct CaughtResponse: Identifiable {
        let id = UUID()
        let url: String
        let bytes: Int
        let preview: String
        // 完整响应体，用来从接口 JSON 里抽包裹；preview 只给界面看
        let body: String
    }

    let webView: WKWebView
    private let platform: GrabPlatform
    private let userContentController: WKUserContentController
    private var lastGrabTime: Date = .distantPast

    init(platform: GrabPlatform) {
        self.platform = platform

        let cfg = WKWebViewConfiguration()
        // 必须是 default()：cookie 和 localStorage 都要落盘，重进才有登录态
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
        // 用 Safari 的 UA。不伪装成拼多多 App —— 伪装了页面会去找 JSBridge，
        // 找不到反而更容易被判异常。真实浏览器身份 + 同站代理才是正路。
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.2 Mobile/15E148 Safari/604.1"
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsInlineMediaPlayback = true

        super.init()

        // WKUserContentController 强引用 handler，直接 add(self) 会形成
        // webView → config → uc → self → webView 的循环，deinit 永远不触发。
        uc.add(WeakScriptMessageHandler(self), name: "fc")
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    deinit {
        userContentController.removeScriptMessageHandler(forName: "fc")
    }

    // WKUserContentController 会强引用 handler，不主动断开就会把整个 grabber 留住
    func teardown() {
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "fc")
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    // MARK: - 加载

    func load() {
        guard let url = platform.entryURL else { return }
        progress = "加载 \(url.host ?? "")"
        var req = URLRequest(url: url)
        req.setValue("https://m.pinduoduo.net/", forHTTPHeaderField: "Referer")
        webView.load(req)
    }

    /// 重新加载当前页而不是回首页 —— 用户可能已经点进包裹详情，
    /// 重置到首页会把刚建立的登录上下文和页面状态一起丢掉。
    func reload() {
        caught.removeAll()
        items.removeAll()
        rawDump = ""
        if webView.url == nil {
            load()
        } else {
            progress = "重新加载当前页…"
            webView.reload()
        }
    }

    // MARK: - 抓取

    func grab() {
        progress = "读取页面…"
        lastGrabTime = Date()
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

        // 登录态诊断
        let cookieKeys = obj["cookieKeys"] as? [String] ?? []
        let lsKeys = obj["lsKeys"] as? [String] ?? []
        let rewrites = obj["rewrites"] as? Int ?? 0
        let hasToken = cookieKeys.contains("PDDAccessToken")
        let hasUid = cookieKeys.contains("pdd_user_id")
        authNote = "重写 \(rewrites) 个请求 · cookie: \(cookieKeys.isEmpty ? "无" : cookieKeys.prefix(6).joined(separator: ","))"
            + " · 登录态: \(hasToken ? "有 token" : "无 token")\(hasUid ? " / 有 uid" : "")"

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

        // 再从捕获的接口 JSON 里抽一遍 —— 比 DOM 正则准，也不依赖页面渲染
        for p in extractFromCaught() {
            // 同一个包裹会被专用解析和语义扫描各产出一次，按码/图去重
            let dup = found.contains { old in
                if let a = old.pickupCode, let b = p.pickupCode, a == b { return true }
                if let a = old.thumbnail, let b = p.thumbnail, a == b { return true }
                return old.title == p.title && old.pickupCode == nil && p.pickupCode == nil
            }
            if !dup { found.append(p) }
        }

        items = found
        if found.isEmpty {
            progress = "没识别到包裹，看下面的原文"
        } else {
            progress = "识别到 \(found.count) 个包裹"
        }
    }

    // MARK: - 从接口 JSON 抽包裹

    /// 不写死字段名。各平台是 goods_name / thumb_url / pickup_code 还是别的名字，
    /// 平台一改版就废；按字段名的语义去认，改版也不影响。
    private func extractFromCaught() -> [PackageItem] {
        var out: [PackageItem] = []
        for c in caught {
            let trimmed = c.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("{") || trimmed.hasPrefix("["),
                  let data = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data)
            else { continue }
            // 先走拼多多已知结构（准），再走语义扫描兜底（防改版）
            parsePackageLists(obj, &out, station: nil, depth: 0)
            scanPackages(obj, &out, depth: 0)
        }
        return out
    }

    /// 拼多多的包裹列表字段（从 4039 chunk 里逆出来的）：
    ///   not_lighting_package_list / auto_lighting_package_list / combine_list
    /// 每个元素：
    ///   pick_code        "取件码1-2-3"，前缀要去掉
    ///   pic_url          缩略图
    ///   ship_name        快递公司
    ///   tracking_number  运单号
    ///   station_code     站点码（在外层）
    private func parsePackageLists(_ any: Any, _ out: inout [PackageItem],
                                   station: String?, depth: Int) {
        guard depth < 10, out.count < 60 else { return }

        if let dict = any as? [String: Any] {
            // 站点名/码可能在同层的兄弟字段上
            let st = (dict["station_name"] as? String)
                ?? (dict["station_code"] as? String)
                ?? station

            for (k, v) in dict {
                let key = k.lowercased()

                if key.contains("package_list"), let arr = v as? [Any] {
                    for item in arr {
                        guard let d = item as? [String: Any] else { continue }
                        var code = d["pick_code"] as? String
                        code = code?
                            .replacingOccurrences(of: "取件码", with: "")
                            .replacingOccurrences(of: "取货码", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        let pic = (d["pic_url"] as? String) ?? (d["thumb_url"] as? String)
                        let ship = d["ship_name"] as? String
                        let track = d["tracking_number"] as? String

                        // 没码没图，基本不是包裹
                        if (code ?? "").isEmpty && (pic ?? "").isEmpty { continue }

                        var title = ship ?? "包裹"
                        if let t = track, !t.isEmpty { title += " · " + t }

                        out.append(PackageItem(
                            platform: platform.title,
                            title: title,
                            thumbnail: pic,
                            pickupCode: (code ?? "").isEmpty ? nil : code,
                            station: st,
                            status: "待取件"
                        ))
                    }
                    continue
                }
                parsePackageLists(v, &out, station: st, depth: depth + 1)
            }
        } else if let arr = any as? [Any] {
            for v in arr { parsePackageLists(v, &out, station: station, depth: depth + 1) }
        }
    }

    private func scanPackages(_ any: Any, _ out: inout [PackageItem], depth: Int) {
        guard depth < 12, out.count < 60 else { return }

        if let dict = any as? [String: Any] {
            var code: String?
            var title: String?
            var thumb: String?
            var station: String?

            for (k, v) in dict {
                let key = k.lowercased()
                guard let s = v as? String, !s.isEmpty else { continue }

                if code == nil, s.count <= 16,
                   key.contains("pickup") || key.contains("take_code")
                    || key.contains("identify_code") || key.contains("pick_code") {
                    code = s
                }
                if title == nil, s.count > 1, s.count < 160, !s.hasPrefix("http"),
                   key == "goods_name" || key == "product_name" || key == "title"
                    || key == "name" || key == "ship_name"
                    || key.contains("goods_title") {
                    title = s
                }
                if thumb == nil, s.hasPrefix("http"),
                   key.contains("thumb") || key.contains("img") || key.contains("pic")
                    || key.contains("image") || key.contains("cover") {
                    thumb = s
                }
                if station == nil, s.count < 60, !s.hasPrefix("http"),
                   key.contains("station_name") || key.contains("store_name")
                    || key.contains("shop_name") {
                    station = s
                }
            }

            // 有取件码，或者「商品名 + 图」齐了，就当这是一个包裹
            if let raw = code {
                let clean = raw
                    .replacingOccurrences(of: "取件码", with: "")
                    .replacingOccurrences(of: "取货码", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if clean.count >= 3 {
                    out.append(PackageItem(
                        platform: platform.title,
                        title: title ?? "包裹",
                        thumbnail: thumb,
                        pickupCode: clean,
                        station: station,
                        status: "待取件"
                    ))
                    return   // 已经是包裹节点，别再往下钻，免得子字段被重复计一条
                }
            }
            if let title = title, let thumb = thumb {
                out.append(PackageItem(
                    platform: platform.title,
                    title: title,
                    thumbnail: thumb,
                    pickupCode: nil,
                    station: station,
                    status: "待取件"
                ))
                return
            }

            for (_, v) in dict { scanPackages(v, &out, depth: depth + 1) }
        } else if let arr = any as? [Any] {
            for v in arr { scanPackages(v, &out, depth: depth + 1) }
        }
    }

    // MARK: - 注入脚本

    // documentStart 注入。
    //
    // 核心修复：驿站页把接口打到 api.pinduoduo.com，而页面自己跑在 m.pinduoduo.net，
    // 两者跨站，cookie 过不去。所有 express_trackbox 接口全返 40001，
    // 页面拿到 40001 就调 D.kS() 清登录态并弹登录框 —— 这就是「登录后闪一下又让登录」。
    //
    // 驿站自己留了同站代理 /proxy/api（development 配置里 BACKEND_API 就是它），
    // 把绝对地址重写过去，请求变同站，cookie 自动带上，ITP 也不拦。
    static let hookScript = """
    (function(){
      if (window.__fcHooked) return;
      window.__fcHooked = true;
      window.__fcRewrites = 0;

      var API_HOST = 'https://api.pinduoduo.com';
      var PROXY    = 'https://m.pinduoduo.net/proxy/api';

      function fixUrl(u) {
        if (typeof u !== 'string' || !u) return u;
        if (u.indexOf(API_HOST) === 0) {
          window.__fcRewrites++;
          return PROXY + u.slice(API_HOST.length);
        }
        return u;
      }

      function post(url, body) {
        try {
          var s = String(body || '');
          window.webkit.messageHandlers.fc.postMessage({
            kind: 'xhr', url: String(url || ''), len: s.length, body: s.slice(0, 400000)
          });
        } catch (e) {}
      }

      // nickname/query 返 40001 会触发页面清登录态。
      // 只要本地确实有 token，就把这一条伪造成成功，别让页面自己把自己踢了。
      function patchAuthProbe(url, text) {
        try {
          if (!url || url.indexOf('nickname/query') < 0) return text;
          if (text.indexOf('40001') < 0) return text;
          if ((document.cookie || '').indexOf('PDDAccessToken') < 0) return text;
          window.__fcAuthPatched = (window.__fcAuthPatched || 0) + 1;
          return '{"error_code":0,"success":true,"result":{"nickname":"","avatar":"","user_id":"0"}}';
        } catch (e) { return text; }
      }

      var XO = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function(m, u) {
        var args = Array.prototype.slice.call(arguments);
        args[1] = fixUrl(u);
        this.__fcUrl = args[1];
        return XO.apply(this, args);
      };

      var XS = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.send = function() {
        var self = this;
        this.addEventListener('load', function() {
          try {
            var t = self.responseText || '';
            t = patchAuthProbe(self.__fcUrl, t);
            if (t !== self.responseText) {
              try {
                Object.defineProperty(self, 'responseText', { get: function(){ return t; }, configurable: true });
                Object.defineProperty(self, 'response',    { get: function(){ return t; }, configurable: true });
              } catch (e) {}
            }
            post(self.__fcUrl, t);
          } catch (e) {}
        });
        return XS.apply(this, arguments);
      };

      var F = window.fetch;
      if (F) {
        window.fetch = function() {
          var args = Array.prototype.slice.call(arguments);
          var a = args[0];
          if (typeof a === 'string') {
            args[0] = fixUrl(a);
          } else if (a && a.url) {
            var nu = fixUrl(a.url);
            if (nu !== a.url) { try { args[0] = new Request(nu, a); } catch (e) { args[0] = nu; } }
          }
          var target = typeof args[0] === 'string' ? args[0] : ((args[0] && args[0].url) || '');
          return F.apply(this, args).then(function(resp) {
            try {
              resp.clone().text().then(function(t){ post(target, t); }).catch(function(){});
            } catch (e) {}
            return resp;
          });
        };
      }
    })();
    """

    // 抓取时执行：把页面可见文本和图片捞出来，顺带汇报登录态
    static let dumpScript = """
    (function(){
      var text = document.body ? document.body.innerText : '';
      var imgs = [];
      var all = document.images || [];
      for (var i = 0; i < all.length && imgs.length < 40; i++) {
        var s = all[i].currentSrc || all[i].src || '';
        if (s && s.indexOf('data:') !== 0 && imgs.indexOf(s) < 0) imgs.push(s);
      }
      var cookieKeys = [];
      try {
        cookieKeys = (document.cookie || '').split(';')
          .map(function(x){ return (x.split('=')[0] || '').trim(); })
          .filter(function(x){ return !!x; });
      } catch (e) {}
      var lsKeys = [];
      try { lsKeys = Object.keys(localStorage || {}).slice(0, 30); } catch (e) {}
      return JSON.stringify({
        url: location.href,
        title: document.title || '',
        text: text.slice(0, 30000),
        images: imgs,
        cookieKeys: cookieKeys,
        lsKeys: lsKeys,
        rewrites: window.__fcRewrites || 0,
        authPatched: window.__fcAuthPatched || 0
      });
    })();
    """
}

// MARK: - 消息与导航

extension WebGrabber: WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {

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
            || lower.contains("express_trackbox")
        guard interesting else { return }

        DispatchQueue.main.async {
            if self.caught.count >= 40 { self.caught.removeFirst() }
            self.caught.append(CaughtResponse(
                url: url,
                bytes: body.count,
                preview: String(body.prefix(400)),
                body: body.count > 200_000 ? String(body.prefix(200_000)) : body
            ))
            self.progress = "已捕获 \(self.caught.count) 个接口响应"
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        // 页面内部路由跳转也会触发 didFinish，别把用户刚看到的状态提示冲掉
        if Date().timeIntervalSince(lastGrabTime) > 1.5 {
            progress = "页面已加载，登录后点「抓取」"
        }
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

    // 页面用 window.open / target=_blank 打开登录页时，别丢在空窗口里
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil,
           let url = navigationAction.request.url,
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

// MARK: - 弱引用 handler 包装

// WKUserContentController.add(_:name:) 对 handler 是强引用。
// 直接把自己传进去，就等于让 webView 反过来持有 self，deinit 不可能被调用。
// 中间垫一层 weak，循环就断了。
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

// MARK: - SwiftUI 包装

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
