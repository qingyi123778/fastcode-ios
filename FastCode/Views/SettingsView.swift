import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var prefs: Prefs
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        themeSection
                        skinSection
                        aboutSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(prefs.theme.accent)
                }
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

    // MARK: - 深色模式

    private var themeSection: some View {
        card {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("深色模式")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(prefs.theme.inkPrimary)
                    Text("跟随你的选择，不跟随系统")
                        .font(.system(size: 11.5))
                        .foregroundStyle(prefs.theme.inkSecondary)
                }
                Spacer()
                Toggle("", isOn: $prefs.darkMode)
                    .labelsHidden()
                    .tint(prefs.theme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - 界面风格

    private var skinSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("界面风格")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(prefs.theme.inkPrimary)
                    Text("青简 · 雾青 · 素白，随你挑")
                        .font(.system(size: 11.5))
                        .foregroundStyle(prefs.theme.inkSecondary)
                }

                HStack(spacing: 8) {
                    ForEach(SkinStyle.allCases) { skin in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                prefs.skin = skin
                            }
                        } label: {
                            Text(skin.title)
                                .font(.system(size: 13, weight: prefs.skin == skin ? .semibold : .regular))
                                .foregroundStyle(prefs.skin == skin ? Color.white : prefs.theme.pillText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule().fill(
                                        prefs.skin == skin
                                        ? prefs.theme.accent
                                        : prefs.theme.pillFill
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("版本")
                        .font(.system(size: 13))
                        .foregroundStyle(prefs.theme.inkSecondary)
                    Spacer()
                    Text("1.17")
                        .font(.system(size: 13))
                        .foregroundStyle(prefs.theme.inkPrimary)
                }
                Divider().overlay(prefs.theme.divider)
                Button {
                    prefs.resetOrder()
                } label: {
                    HStack {
                        Text("恢复默认排序")
                            .font(.system(size: 13))
                            .foregroundStyle(prefs.theme.accent)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - 卡片容器

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(prefs.theme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(prefs.theme.cardStroke, lineWidth: 1)
            )
    }
}
