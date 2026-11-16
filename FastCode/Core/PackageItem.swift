import Foundation

// 各平台统一后的包裹模型
struct PackageItem: Identifiable, Hashable {
    let id: String
    let platform: String        // 拼多多 / 淘宝 / 京东 / 抖音
    let title: String           // 商品名或包裹描述
    let thumbnail: String?      // 缩略图 URL
    let pickupCode: String?     // 取件码
    let station: String?        // 驿站 / 代收点
    let status: String          // 待取件 / 运输中 / 已签收

    init(platform: String,
         title: String,
         thumbnail: String? = nil,
         pickupCode: String? = nil,
         station: String? = nil,
         status: String = "待取件") {
        self.id = "\(platform)-\(title)-\(pickupCode ?? "")-\(title.hashValue)"
        self.platform = platform
        self.title = title
        self.thumbnail = thumbnail
        self.pickupCode = pickupCode
        self.station = station
        self.status = status
    }
}

// 平台定义
enum GrabPlatform: String, CaseIterable, Identifiable {
    case pdd
    case taobao
    case jd
    case douyin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pdd:    return "拼多多"
        case .taobao: return "淘宝"
        case .jd:     return "京东"
        case .douyin: return "抖音"
        }
    }

    var iconAsset: String {
        switch self {
        case .pdd:    return "ic_pinduoduo"
        case .taobao: return "ic_taobao"
        case .jd:     return "ic_jd"
        case .douyin: return "ic_douyin"
        }
    }

    var entryURL: URL? {
        switch self {
        case .pdd:
            return URL(string: "https://m.pinduoduo.net/mdkd/package?entry_source=18&p_channel=0")
        case .taobao:
            return URL(string: "https://pages-fast.m.taobao.com/wow/z/uniapp/1100333/last-mile-fe/m-end-school-tab/home?x-ssr=true")
        case .jd:
            return URL(string: "https://m.jd.com/order/orderList")
        case .douyin:
            return URL(string: "https://haohuo.jinritemai.com/views/order/index")
        }
    }

    var ready: Bool {
        // 只有拼多多跑通了抓取，其余先留占位
        self == .pdd
    }
}
