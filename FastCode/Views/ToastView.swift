import SwiftUI

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Capsule().fill(Color.black.opacity(0.82))
            )
            .padding(.horizontal, 32)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// 底部浮出，2 秒自动消失，可被新提示打断
struct ToastModifier: ViewModifier {
    @Binding var text: String?
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let text {
                ToastView(text: text)
                    .padding(.bottom, 34)
                    .onAppear { scheduleDismiss() }
                    .onChange(of: text) { _ in scheduleDismiss() }
            }
        }
        .animation(.easeOut(duration: 0.22), value: text)
    }

    private func scheduleDismiss() {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            text = nil
        }
    }
}

extension View {
    func toast(_ text: Binding<String?>) -> some View {
        modifier(ToastModifier(text: text))
    }
}
