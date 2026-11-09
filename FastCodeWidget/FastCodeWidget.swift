import WidgetKit
import SwiftUI

struct FCWidgetEntry: TimelineEntry {
    let date: Date
    let items: [JumpEntry]
}

struct FCProvider: TimelineProvider {

    // 桌面小组件固定展示 9 个入口，顺序与 App 内默认顺序一致。
    // 想跟 App 内拖拽后的顺序同步，给两个 target 开同一个 App Group，
    // 再把下面这行换成读取 UserDefaults(suiteName:) 的 order 数组。
    private var items: [JumpEntry] { EntryCatalog.all }

    func placeholder(in context: Context) -> FCWidgetEntry {
        FCWidgetEntry(date: Date(), items: Array(items.prefix(9)))
    }

    func getSnapshot(in context: Context, completion: @escaping (FCWidgetEntry) -> Void) {
        completion(FCWidgetEntry(date: Date(), items: Array(items.prefix(9))))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FCWidgetEntry>) -> Void) {
        let entry = FCWidgetEntry(date: Date(), items: Array(items.prefix(9)))
        // 入口是静态的，一天刷一次够了；要按时间变色再改成每小时
        let next = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct FCWidgetView: View {
    var entry: FCWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var columns: [GridItem] {
        let count = family == .systemLarge ? 3 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 6), count: count)
    }

    private var visibleItems: [JumpEntry] {
        family == .systemLarge ? Array(entry.items.prefix(9)) : Array(entry.items.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(red: 0.0, green: 0.59, blue: 0.53))
                    .frame(width: 2.5, height: 11)
                Text("取件快码")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(visibleItems) { item in
                    Link(destination: destination(for: item)) {
                        VStack(spacing: 3) {
                            Image(item.iconAsset)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            Text(shortTitle(item.title))
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.0, green: 0.59, blue: 0.53).opacity(0.10))
                        )
                    }
                }
            }
        }
        .padding(12)
    }

    // widget 里点开走第一个能用的 scheme，App 内才有完整的三段回退
    private func destination(for item: JumpEntry) -> URL {
        if let raw = item.appURLs.first, let url = URL(string: raw) { return url }
        if let mp = item.miniProgram?.url { return mp }
        if let raw = item.webURL, let url = URL(string: raw) { return url }
        return URL(string: "fastcode://open?key=\(item.key)")!
    }

    private func shortTitle(_ t: String) -> String {
        t.replacingOccurrences(of: "身份码", with: "码")
            .replacingOccurrences(of: "待取", with: "")
    }
}

@main
struct FastCodeWidget: Widget {
    let kind = "FastCodeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FCProvider()) { entry in
            if #available(iOS 17.0, *) {
                FCWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                // iOS 16.2 走这里：给个不透明底，避免桌面壁纸透上来糊成一片
                FCWidgetView(entry: entry)
                    .padding(0)
                    .background(Color(.systemBackground))
            }
        }
        .configurationDisplayName("取件快码")
        .description("三个身份码，六个查件入口，点一下直达。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
