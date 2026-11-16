import SwiftUI

// 聚合页：内嵌 WebView 登录 → 抓取 → 统一展示
struct AggregateView: View {
    @EnvironmentObject private var prefs: Prefs
    @Environment(\.dismiss) private var dismiss

    @StateObject private var grabber = WebGrabber(platform: .pdd)
    @State private var showResult = false
    @State private var firstLoad = true

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                background.ignoresSafeArea()

                WebViewContainer(webView: grabber.webView)
                    .ignoresSafeArea(edges: .bottom)

                toolbar
            }
            .navigationTitle("全部待取 · 拼多多")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(prefs.theme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("抓取") {
                        grabber.grab()
                        showResult = true
                    }
                    .foregroundStyle(prefs.theme.accent)
                }
            }
            .sheet(isPresented: $showResult) {
                GrabResultView(grabber: grabber, platform: .pdd)
                    .environmentObject(prefs)
            }
            .onAppear {
                if firstLoad {
                    firstLoad = false
                    grabber.load()
                }
            }
            .onDisappear {
                grabber.teardown()
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        switch prefs.theme.fill {
        case .solid(let color):
            color
        case .gradient(let colors):
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text(grabber.progress.isEmpty ? "登录后点右上角抓取" : grabber.progress)
                .font(.system(size: 12))
                .foregroundStyle(prefs.theme.inkSecondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                grabber.reload()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text("重载")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(prefs.theme.pillText)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(prefs.theme.pillFill))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - 抓取结果

struct GrabResultView: View {
    @ObservedObject var grabber: WebGrabber
    let platform: GrabPlatform

    @EnvironmentObject private var prefs: Prefs
    @Environment(\.dismiss) private var dismiss
    @State private var showRaw = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    summary

                    if grabber.items.isEmpty {
                        emptyHint
                    } else {
                        ForEach(grabber.items) { item in
                            itemCard(item)
                        }
                    }

                    if showRaw {
                        rawSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(themeBackground.ignoresSafeArea())
            .navigationTitle("抓取结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(prefs.theme.accent)
                }
            }
        }
    }

    private var themeBackground: some View {
        Group {
            switch prefs.theme.fill {
            case .solid(let color):
                color
            case .gradient(let colors):
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("识别到 \(grabber.items.count) 个包裹")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(prefs.theme.inkPrimary)
                Spacer()
                Button(showRaw ? "收起原始数据" : "看原始数据") {
                    withAnimation(.easeInOut(duration: 0.18)) { showRaw.toggle() }
                }
                .font(.system(size: 12))
                .foregroundStyle(prefs.theme.accent)
            }

            Text("接口响应 \(grabber.caught.count) 条")
                .font(.system(size: 12))
                .foregroundStyle(prefs.theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(prefs.theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(prefs.theme.cardStroke, lineWidth: 1))
    }

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("没从页面里认出取件码")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(prefs.theme.inkPrimary)
            Text("可能原因：还没登录、包裹列表没加载出来、或者取件码在详情页里。把「原始数据」里的页面文本截图发我，我按真实结构改解析。")
                .font(.system(size: 12))
                .foregroundStyle(prefs.theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(prefs.theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(prefs.theme.cardStroke, lineWidth: 1))
    }

    private func itemCard(_ item: PackageItem) -> some View {
        HStack(spacing: 12) {
            Group {
                if let s = item.thumbnail, let url = URL(string: s) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            placeholderThumb
                        }
                    }
                } else {
                    placeholderThumb
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(platform.iconAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Text(platform.title)
                        .font(.system(size: 11))
                        .foregroundStyle(prefs.theme.inkSecondary)
                    Spacer()
                    Text(item.status)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(prefs.theme.accent)
                }

                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(prefs.theme.inkPrimary)
                    .lineLimit(1)

                if let code = item.pickupCode {
                    Text("取件码 \(code)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(prefs.theme.accent)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(prefs.theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(prefs.theme.cardStroke, lineWidth: 1))
    }

    private var placeholderThumb: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(prefs.theme.tileFill)
            .overlay(
                Image(systemName: "shippingbox")
                    .font(.system(size: 18))
                    .foregroundStyle(prefs.theme.inkSecondary)
            )
    }

    private var rawSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("页面文本")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(prefs.theme.inkPrimary)

            Text(rawText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(prefs.theme.inkSecondary)
                .textSelection(.enabled)

            if !grabber.caught.isEmpty {
                Divider().overlay(prefs.theme.divider)
                Text("捕获的接口")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(prefs.theme.inkPrimary)

                ForEach(grabber.caught) { c in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(c.url.prefix(120)))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(prefs.theme.accent)
                        Text("\(c.bytes) 字符 · \(String(c.preview.prefix(160)))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(prefs.theme.inkSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(prefs.theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(prefs.theme.cardStroke, lineWidth: 1))
    }

    private var rawText: String {
        guard let data = grabber.rawDump.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = obj["text"] as? String
        else { return "（无）" }
        return text.isEmpty ? "（页面文本为空）" : String(text.prefix(4000))
    }
}
