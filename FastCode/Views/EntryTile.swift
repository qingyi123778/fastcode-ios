import SwiftUI

// 身份码组只有 2 格，用大号铺开；查件组 6 格 3 列，用标准号
enum TileSize {
    case regular
    case large

    var iconSide: CGFloat {
        switch self {
        case .regular: return 40
        case .large:   return 68
        }
    }

    var iconCorner: CGFloat {
        switch self {
        case .regular: return 10
        case .large:   return 16
        }
    }

    var titleSize: CGFloat {
        switch self {
        case .regular: return 12
        case .large:   return 15
        }
    }

    var vPadding: CGFloat {
        switch self {
        case .regular: return 14
        case .large:   return 24
        }
    }

    var corner: CGFloat {
        switch self {
        case .regular: return 18
        case .large:   return 22
        }
    }

    var spacing: CGFloat {
        switch self {
        case .regular: return 8
        case .large:   return 12
        }
    }

    var titleWeight: Font.Weight {
        switch self {
        case .regular: return .medium
        case .large:   return .semibold
        }
    }
}

struct EntryTile: View {
    let entry: JumpEntry
    let theme: Theme
    var size: TileSize = .regular
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: size.spacing) {
                Image(entry.iconAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.iconSide, height: size.iconSide)
                    .clipShape(RoundedRectangle(cornerRadius: size.iconCorner, style: .continuous))

                Text(entry.title)
                    .font(.system(size: size.titleSize, weight: size.titleWeight))
                    .foregroundStyle(theme.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, size.vPadding)
            .background(
                RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                    .fill(theme.tileFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                    .stroke(theme.tileStroke, lineWidth: 1)
            )
            .scaleEffect(pressed ? 0.955 : 1)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.14), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}
