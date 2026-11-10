# 快递取件 iOS

从 `快递取件-1.17.apk`（`com.takegai.fastcode`，MD5 `dd151f1f494382490f95130608cb893c`）逆向重写的 iOS 原生版本。

- 最低系统：**iOS 16.2**
- 语言：Swift 5 + SwiftUI
- Bundle ID：`com.takegai.fastcode`

---

## 逆向结论

原包是个纯跳转壳，206 KB，无 native 库、无 assets，逻辑全在 42 KB 的 `classes.dex` 里。

它自己不查快递，也不联网。9 个入口全部靠 URI scheme 拉起第三方 App 的指定页面：

| key | 标题 | scheme（按尝试顺序） |
|---|---|---|
| `taobao_code` | 淘宝身份码 | `tbopen://` → `taobao://` |
| `taobao_pending` | 淘宝待取 | `tbopen://`（3 个 h5Url 变体） |
| `pdd_code` | 拼多多身份码 | `pinduoduo://…?tab=ID_CODE` |
| `pdd_pending` | 拼多多待取 | `pinduoduo://…/mdkd/package` |
| `jd_code` | 京东身份码 | `openjd://virtual?des=myJd` → `openapp.jdmobile://` |
| `jd_pending` | 京东待取 | `openjd://virtual?des=orderlist` |
| `douyin_pending` | 抖音待取 | `snssdk1128://ecom_order_list` → `snssdk2329://` |
| `kuaishou_pending` | 快手待取 | `kwai://webview?url=…` → `ksnebula://` |
| `dewu_pending` | 得物待取 | `dewuapp://m.dewu.com/router/order/buyer/orderList` |

微信小程序兜底（`weixin://dl/business/?appid=…`）：

- 拼多多 `wx32540bd863b27570`
- 京东 `wx91d27dbf599dff74`

配色、文案、三套皮肤全部取自 `resources.arsc`，不是估的：

| 项 | 值 |
|---|---|
| 主色 | `#009688` |
| 卡片底 | `#12009688` |
| 卡片描边 | `#1F009688` |
| 青简底 | `#F7F8FA` |
| 雾青渐变 | `#E7F8F1 → #E6F4FA → #F3FBF6` |
| 暗色底 | `#121212` / 卡片 `#1E1E1E` |

---

## 目录结构

```
ios/FastCode/
├── project.yml                     XcodeGen 工程描述
├── build_ipa.sh                    macOS 一键出未签名 ipa
├── .github/workflows/build-ipa.yml GitHub Actions 云端出包
├── Shared/
│   └── EntryCatalog.swift          9 个入口 + 全部 URI（App 与 Widget 共用）
├── FastCode/
│   ├── App/FastCodeApp.swift
│   ├── Core/
│   │   ├── JumpManager.swift       三段回退跳转
│   │   ├── Prefs.swift             设置持久化 + 拖拽重排
│   │   └── Theme.swift             三套皮肤 + 暗色
│   ├── Views/
│   │   ├── ContentView.swift       主界面
│   │   ├── SettingsView.swift      设置页
│   │   ├── EntryTile.swift         入口方块
│   │   └── ToastView.swift         底部提示
│   ├── Resources/Assets.xcassets/  图标（菜鸟 pingu）
│   └── Info.plist                  LSApplicationQueriesSchemes 白名单
├── FastCodeWidget/
│   └── FastCodeWidget.swift        桌面小组件（medium / large）
└── tools/
    ├── build_assets.py             从 APK 资源生成 xcassets
    └── src/mascot_final.png        处理过的图标源图
```

---

## 编译

### macOS（推荐）

```bash
brew install xcodegen
cd ios/FastCode
xcodegen generate
open FastCode.xcodeproj
# 连真机 → 选 Team → Run
```

出未签名 ipa：

```bash
cd ios/FastCode
chmod +x build_ipa.sh
./build_ipa.sh
# 产物：build/FastCode-1.17-unsigned.ipa
```

### 没有 Mac

推 GitHub 仓库，`.github/workflows/build-ipa.yml` 会在 `macos-14` 上跑，产物在 Actions 的 Artifacts 里（`FastCode-ipa`）。

### 手工建工程（不想用 XcodeGen）

新建 iOS App 工程，把 `Shared/` 和 `FastCode/` 下所有 `.swift` 拖进去，再建一个 Widget Extension target（把 `FastCodeWidget/` 拖进去），`Info.plist` 用本目录的，Deployment Target 设 16.2。

---

## 安装到 iOS 16.2

未签名 ipa 三条路：

1. **TrollStore 2** — iOS 15.0–16.6.1 的 arm64e 设备直接点开 ipa 安装，永久签名，不掉签。16.2 在支持范围内。
2. **Sideloadly / AltStore** — 用你自己的 Apple ID 自签，7 天有效期，到期重签。
3. **Xcode 真机 Run** — 有 Mac 的话最省事，不用 ipa。

---

## iOS 与 Android 的能力差异

| 功能 | Android 原版 | iOS 版 | 说明 |
|---|---|---|---|
| 拉起第三方 App | `startActivity` + `resolveActivity` | `UIApplication.open` 回调 | 等价。scheme 必须写进 `LSApplicationQueriesSchemes` |
| 安装检测 | `PackageManager` 查包名 | 无对应 API | iOS 不给查别人装没装，只能靠 open 成功/失败判断 |
| 微信小程序 | `weixin://dl/business` | 同 | 一致 |
| 桌面小组件 | `AppWidgetProvider` | WidgetKit | 一致，9 格可点 |
| 换桌面图标 | `activity-alias` 热切换 | `setAlternateIconName` | iOS 需要预置图标集，且会弹系统确认框。当前版本已按你的要求只保留一套图标 |
| 主题切换 | 三套 UI + 深色 | 同 | 一致 |

**唯一的硬限制**：iOS 上判断某个 App 是否安装，没有 Android 那种同步 API。`JumpManager` 用 `open` 的 completion 回调 + 1.5 秒超时来做回退，行为上等价，但会有一次可能的界面切换闪动。

`LSApplicationQueriesSchemes` 上限 50 条，当前用了 10 条，加新入口时注意别超。

---

## 加新入口

改 `Shared/EntryCatalog.swift`，加一个 `JumpEntry`，再塞进 `codeEntries` 或 `pendingEntries`。图标丢进两个 `Assets.xcassets`。`defaultOrder` 会自动包含它。

`Prefs` 里做了顺序校验：老的 `order` 数组对不上新目录时会自动回默认顺序，不会丢入口。
