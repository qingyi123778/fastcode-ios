import Foundation

// 入口分组。顺序与 Android 原版一致：3 个身份码 + 6 个查件入口。
enum EntryGroup: String, CaseIterable, Identifiable, Hashable {
    case code
    case pending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .code: return "身份码"
        case .pending: return "查看待取包裹"
        }
    }

    var subtitle: String {
        switch self {
        case .code: return "驿站扫码出示"
        case .pending: return "订单内查看"
        }
    }
}

struct WeChatMiniProgram: Hashable {
    let appID: String
    let path: String

    // weixin://dl/business/?appid=&path= 是微信开放平台通用的小程序跳转入口。
    // 未安装微信时 open 回调 false，由 JumpManager 继续往下走 web 兜底。
    var url: URL? {
        var c = URLComponents()
        c.scheme = "weixin"
        c.host = "dl"
        c.path = "/business/"
        c.queryItems = [
            URLQueryItem(name: "appid", value: appID),
            URLQueryItem(name: "path", value: path)
        ]
        return c.url
    }
}

struct JumpEntry: Identifiable, Hashable {
    let key: String
    let title: String
    let group: EntryGroup
    let iconAsset: String
    // 按优先级排列，逐个尝试，失败自动降级到下一个
    let appURLs: [String]
    // 兜底 H5，App 与小程序都拉不起来时用 Safari 打开
    let webURL: String?
    let miniProgram: WeChatMiniProgram?
    let successToast: String

    var id: String { key }

    static func == (lhs: JumpEntry, rhs: JumpEntry) -> Bool { lhs.key == rhs.key }
    func hash(into hasher: inout Hasher) { hasher.combine(key) }
}

enum EntryCatalog {

    // MARK: - 身份码（3）

    static let taobaoCode = JumpEntry(
        key: "taobao_code",
        title: "淘宝身份码",
        group: .code,
        iconAsset: "ic_taobao",
        appURLs: [
            "tbopen://m.taobao.com/tbopen/index.html?h5Url=https%3A%2F%2Fmarket.m.taobao.com%2Fapp%2Fcn-yz%2Fmulti-activity%2FauthCode.html",
            "taobao://m.taobao.com/tbopen/index.html?h5Url=https%3A%2F%2Fmarket.m.taobao.com%2Fapp%2Fcn-yz%2Fmulti-activity%2FauthCode.html"
        ],
        webURL: "https://market.m.taobao.com/app/cn-yz/multi-activity/authCode.html",
        miniProgram: nil,
        successToast: "已打开淘宝身份码，向驿站出示即可"
    )

    static let pddCode = JumpEntry(
        key: "pdd_code",
        title: "拼多多身份码",
        group: .code,
        iconAsset: "ic_pinduoduo",
        appURLs: [
            "pinduoduo://com.xunmeng.pinduoduo/mdkd/package?tab=ID_CODE&entry_source=11",
            "pinduoduo://com.xunmeng.pinduoduo/mdkd/package?tab=ID_CODE&entry_source=11&refer_page_name=login&refer_page_sn=10169"
        ],
        webURL: "https://m.pinduoduo.net/mdkd/package?entry_source=18&extra_params=from_wx_jump%3D1&p_channel=0",
        miniProgram: WeChatMiniProgram(appID: "wx32540bd863b27570", path: "pages/index/index"),
        successToast: "已打开多多驿站身份码"
    )

    static let jdCode = JumpEntry(
        key: "jd_code",
        title: "京东身份码",
        group: .code,
        iconAsset: "ic_jd",
        appURLs: [
            "openjd://virtual?params=%7B%22category%22%3A%22jump%22%2C%22des%22%3A%22myJd%22%7D",
            "openapp.jdmobile://"
        ],
        webURL: "https://order.jd.com/center/list.action",
        miniProgram: WeChatMiniProgram(appID: "wx91d27dbf599dff74", path: "pages/index/index"),
        successToast: "已打开京东订单，点开对应订单即可看到取件码"
    )

    // MARK: - 查看待取包裹（6）

    static let taobaoPending = JumpEntry(
        key: "taobao_pending",
        title: "淘宝待取",
        group: .pending,
        iconAsset: "ic_taobao",
        appURLs: [
            "tbopen://m.taobao.com/tbopen/index.html?h5Url=https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F1011717%2Flast-mile-fe%2Fend-collect-platform%2Fidentity-code%3Fx-ssr%3Dtrue",
            "taobao://m.taobao.com/tbopen/index.html?h5Url=https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F1011717%2Flast-mile-fe%2Fend-collect-platform%2Fidentity-code%3Fx-ssr%3Dtrue",
            "tbopen://m.taobao.com/tbopen/index.html?h5Url=https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F1100333%2Flast-mile-fe%2Fm-end-school-tab%2Fhome"
        ],
        webURL: "https://pages-fast.m.taobao.com/wow/z/uniapp/1011717/last-mile-fe/end-collect-platform/identity-code?x-ssr=true",
        miniProgram: nil,
        successToast: "已打开淘宝待取列表，下拉可刷新"
    )

    static let pddPending = JumpEntry(
        key: "pdd_pending",
        title: "拼多多待取",
        group: .pending,
        iconAsset: "ic_pinduoduo",
        appURLs: [
            "pinduoduo://com.xunmeng.pinduoduo/mdkd/package"
        ],
        webURL: "https://m.pinduoduo.net/mdkd/package?entry_source=18&extra_params=from_wx_jump%3D1&p_channel=0",
        miniProgram: WeChatMiniProgram(appID: "wx32540bd863b27570", path: "pages/index/index"),
        successToast: "已打开多多驿站包裹列表"
    )

    static let jdPending = JumpEntry(
        key: "jd_pending",
        title: "京东待取",
        group: .pending,
        iconAsset: "ic_jd",
        appURLs: [
            "openjd://virtual?params=%7B%22category%22%3A%22jump%22%2C%22des%22%3A%22orderlist%22%7D",
            "openapp.jdmobile://"
        ],
        webURL: "https://order.jd.com/center/list.action",
        miniProgram: WeChatMiniProgram(appID: "wx91d27dbf599dff74", path: "pages/index/index"),
        successToast: "已打开京东订单列表，点开订单查看物流"
    )

    static let douyinPending = JumpEntry(
        key: "douyin_pending",
        title: "抖音待取",
        group: .pending,
        iconAsset: "ic_douyin",
        // snssdk1128 = 抖音，snssdk2329 = 抖音极速版
        appURLs: [
            "snssdk1128://ecom_order_list",
            "snssdk2329://ecom_order_list"
        ],
        webURL: nil,
        miniProgram: nil,
        successToast: "已打开抖音订单列表，可看待收货与物流"
    )

    static let kuaishouPending = JumpEntry(
        key: "kuaishou_pending",
        title: "快手待取",
        group: .pending,
        iconAsset: "ic_kuaishou",
        // kwai = 快手，ksnebula = 快手极速版
        appURLs: [
            "kwai://webview?url=https%3A%2F%2Fapp.kwaixiaodian.com%2Fpage%2Fkwaishop-trade-order-list-app%3FlayoutType%3D4%26hyId%3DkwaishopOrder",
            "ksnebula://webview?url=https%3A%2F%2Fapp.kwaixiaodian.com%2Fpage%2Fkwaishop-trade-order-list-app%3FlayoutType%3D4%26hyId%3DkwaishopOrder"
        ],
        webURL: "https://app.kwaixiaodian.com/page/kwaishop-trade-order-list-app?layoutType=4&hyId=kwaishopOrder",
        miniProgram: nil,
        successToast: "已打开快手小店订单列表"
    )

    static let dewuPending = JumpEntry(
        key: "dewu_pending",
        title: "得物待取",
        group: .pending,
        iconAsset: "ic_dewu",
        appURLs: [
            "dewuapp://m.dewu.com/router/order/buyer/orderList?tabId=0"
        ],
        webURL: "https://m.dewu.com/",
        miniProgram: nil,
        successToast: "已打开得物订单列表"
    )

    static let codeEntries: [JumpEntry] = [taobaoCode, pddCode, jdCode]
    static let pendingEntries: [JumpEntry] = [
        taobaoPending, pddPending, jdPending, douyinPending, kuaishouPending, dewuPending
    ]

    static let all: [JumpEntry] = codeEntries + pendingEntries

    static func entries(in group: EntryGroup) -> [JumpEntry] {
        all.filter { $0.group == group }
    }

    static func entry(forKey key: String) -> JumpEntry? {
        all.first { $0.key == key }
    }

    static let defaultOrder: [String] = all.map(\.key)
}
