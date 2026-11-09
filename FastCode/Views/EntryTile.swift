import SwiftUI

struct EntryTile: View {
    let entry: JumpEntry
    let theme: Theme
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(entry.iconAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(entry.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.tileFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
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
