import UIKit

// 保证 resume 只发生一次：open 的回调和超时定时器可能同时到
private final class OnceFlag {
    private var fired = false
    private let lock = NSLock()

    func fire(_ body: () -> Void) {
        lock.lock()
        if fired { lock.unlock(); return }
        fired = true
        lock.unlock()
        body()
    }
}

// 三段回退：App scheme（可多次）→ 微信小程序 → H5 → 失败提示。
// Android 原版靠 PackageManager.resolveActivity 判断，iOS 没有等价的包可见性 API，
// 只能靠 UIApplication.open 的 completion 回调判断有没有 App 接收。
@MainActor
final class JumpManager {

    static let shared = JumpManager()
    private init() {}

    enum Outcome {
        case app
        case miniProgram
        case web
        case failed
    }

    private let openTimeout: TimeInterval = 1.5

    func open(_ entry: JumpEntry) async -> Outcome {
        // 1. 逐个尝试 App scheme，第一个成功的就用
        for raw in entry.appURLs {
            guard let url = URL(string: raw) else { continue }
            if await openWithTimeout(url) {
                return .app
            }
        }

        // 2. 微信小程序
        if let mp = entry.miniProgram, let url = mp.url {
            if await openWithTimeout(url) {
                return .miniProgram
            }
        }

        // 3. H5 兜底，Safari 一定能接
        if let raw = entry.webURL, let url = URL(string: raw) {
            if await openWithTimeout(url) {
                return .web
            }
        }

        return .failed
    }

    // 未安装的 App 有时不会立即回调，加超时避免界面卡死。
    // 用 OnceFlag 保证 continuation 只 resume 一次，否则重复 resume 直接 crash。
    private func openWithTimeout(_ url: URL) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let once = OnceFlag()

            UIApplication.shared.open(url, options: [:]) { ok in
                once.fire { cont.resume(returning: ok) }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + openTimeout) {
                once.fire { cont.resume(returning: false) }
            }
        }
    }

    func toastText(for outcome: Outcome, entry: JumpEntry) -> String? {
        switch outcome {
        case .app, .miniProgram, .web:
            return entry.successToast
        case .failed:
            return "暂时无法打开\(entry.title)"
        }
    }
}
