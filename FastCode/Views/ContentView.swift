import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var prefs: Prefs
    @State private var toast: String?
    @State private var showSettings = false
    @State private var showAggregate = false
    @State private var draggingKey: String?

    // 身份码 2 格铺满，查件入口 6 格 3 列
    private let codeColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    private let pendingColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private func columns(for group: EntryGroup) -> [GridItem] {
        group == .code ? codeColumns : pendingColumns
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    aggregateEntry
                    section(.code)
                    section(.pending)
                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .toast($toast)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(prefs)
        }
        .sheet(isPresented: $showAggregate) {
            AggregateView()
                .environmentObject(prefs)
        }
    }

    // MARK: - 聚合入口

    private var aggregateEntry: some View {
        Button {
            showAggregate = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(prefs.theme.tileFill)
                        .frame(width: 42, height: 42)
                    Image(systemName: "shippingbox.and.arrow.backward")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(prefs.theme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("全部待取")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(prefs.theme.inkPrimary)
                    Text("拼多多 · 淘宝 · 京东 · 抖音 合到一屏")
                        .font(.system(size: 11.5))
                        .foregroundStyle(prefs.theme.inkSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text("拼多多")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(prefs.theme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(prefs.theme.pillFill))

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(prefs.theme.inkSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(prefs.theme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(prefs.theme.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 背景

    @ViewBuilder
    private var background: some View {
        switch prefs.theme.fill {
        case .solid(let color):
            color
        case .gradient(let colors):
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(spacing: 10) {
            Image("ic_launcher")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(prefs.theme.logoPlateStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 12, y: 4)

            Text("快递取件")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(prefs.theme.inkPrimary)

            Text("两个身份码 · 六个查件入口")
                .font(.system(size: 12.5))
                .foregroundStyle(prefs.theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(prefs.theme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(prefs.theme.cardStroke, lineWidth: 1)
        )
        .padding(.top, 12)
    }

    // MARK: - 分组

    private func section(_ group: EntryGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(prefs.theme.sectionBar)
                    .frame(width: 3, height: 14)

                Text(group.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(prefs.theme.inkPrimary)

                Spacer(minLength: 4)

                Text(group.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(prefs.theme.inkSecondary)
            }

            LazyVGrid(columns: columns(for: group), spacing: 10) {
                ForEach(prefs.entries(in: group)) { entry in
                    EntryTile(
                        entry: entry,
                        theme: prefs.theme,
                        size: group == .code ? .large : .regular
                    ) {
                        Task { await jump(entry) }
                    }
                    .onDrag {
                        draggingKey = entry.key
                        return NSItemProvider(object: entry.key as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: EntryDropDelegate(
                            target: entry,
                            group: group,
                            prefs: prefs,
                            dragging: $draggingKey
                        )
                    )
                    .opacity(draggingKey == entry.key ? 0.35 : 1)
                }
            }
        }
    }

    // MARK: - 底部

    private var footer: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                Text("设置")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(prefs.theme.pillText)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(prefs.theme.pillFill))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    // MARK: - 跳转

    private func jump(_ entry: JumpEntry) async {
        let outcome = await JumpManager.shared.open(entry)
        if let text = JumpManager.shared.toastText(for: outcome, entry: entry) {
            toast = text
        }
    }
}

// 拖拽交换：拖到目标格上就直接换位
struct EntryDropDelegate: DropDelegate {
    let target: JumpEntry
    let group: EntryGroup
    let prefs: Prefs
    @Binding var dragging: String?

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging,
              dragging != target.key,
              let from = prefs.entries(in: group).firstIndex(where: { $0.key == dragging }),
              let to = prefs.entries(in: group).firstIndex(where: { $0.key == target.key })
        else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            prefs.move(from: IndexSet(integer: from), to: to > from ? to + 1 : to, in: group)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
