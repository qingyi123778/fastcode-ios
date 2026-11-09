import SwiftUI

// 三套皮肤，对应 Android 的 ui_paper / ui_glass / ui_flat。
enum SkinStyle: String, CaseIterable, Identifiable {
    case paper   // 青简
    case glass   // 雾青
    case flat    // 素白

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paper: return "青简"
        case .glass: return "雾青"
        case .flat:  return "素白"
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }

    init(argb: UInt32) {
        let a = Double((argb >> 24) & 0xFF) / 255.0
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >> 8) & 0xFF) / 255.0
        let b = Double(argb & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

enum BackgroundFill {
    case solid(Color)
    case gradient([Color])
}

struct Theme {
    let fill: BackgroundFill
    let cardFill: Color
    let cardStroke: Color
    let tileFill: Color
    let tileStroke: Color
    let inkPrimary: Color
    let inkSecondary: Color
    let accent: Color
    let divider: Color
    let sectionBar: Color
    let logoPlate: Color
    let logoPlateStroke: Color
    let pillFill: Color
    let pillText: Color

    // 取值全部来自 APK 的 resources.arsc，不是估的
    static func resolve(skin: SkinStyle, dark: Bool) -> Theme {
        switch (skin, dark) {

        case (.paper, false):
            return Theme(
                fill: .solid(Color(argb: 0xFFF7F8FA)),
                cardFill: Color(argb: 0xFFFFFFFF),
                cardStroke: Color(argb: 0xFFECF0F4),
                tileFill: Color(argb: 0x12009688),
                tileStroke: Color(argb: 0x1F009688),
                inkPrimary: Color(argb: 0xFF12211F),
                inkSecondary: Color(argb: 0xFF5C736E),
                accent: Color(argb: 0xFF009688),
                divider: Color(argb: 0xFFEFEFEF),
                sectionBar: Color(argb: 0xFF4DB6AC),
                logoPlate: Color(argb: 0x8AFFFFFF),
                logoPlateStroke: Color(argb: 0xB3FFFFFF),
                pillFill: Color(argb: 0x18009688),
                pillText: Color(argb: 0xFF009688)
            )

        case (.paper, true):
            return Theme(
                fill: .solid(Color(argb: 0xFF121212)),
                cardFill: Color(argb: 0xFF1E1E1E),
                cardStroke: Color(argb: 0xFF2A2A2A),
                tileFill: Color(argb: 0x14FFFFFF),
                tileStroke: Color(argb: 0x33FFFFFF),
                inkPrimary: Color(argb: 0xFFEAF4F1),
                inkSecondary: Color(argb: 0xFF9BB3AE),
                accent: Color(argb: 0xFF4DD0C4),
                divider: Color(argb: 0xFF2A2A2A),
                sectionBar: Color(argb: 0xFF4DB6AC),
                logoPlate: Color(argb: 0x14FFFFFF),
                logoPlateStroke: Color(argb: 0x33FFFFFF),
                pillFill: Color(argb: 0x1A38B2A6),
                pillText: Color(argb: 0xFF80DEEA)
            )

        case (.glass, false):
            return Theme(
                fill: .gradient([
                    Color(argb: 0xFFE7F8F1),
                    Color(argb: 0xFFE6F4FA),
                    Color(argb: 0xFFF3FBF6)
                ]),
                cardFill: Color(argb: 0x7AFFFFFF),
                cardStroke: Color(argb: 0xCCFFFFFF),
                tileFill: Color(argb: 0x99FFFFFF),
                tileStroke: Color(argb: 0xCCFFFFFF),
                inkPrimary: Color(argb: 0xFF12211F),
                inkSecondary: Color(argb: 0xFF5C736E),
                accent: Color(argb: 0xFF009688),
                divider: Color(argb: 0x33FFFFFF),
                sectionBar: Color(argb: 0xFF4DD0C4),
                logoPlate: Color(argb: 0x8AFFFFFF),
                logoPlateStroke: Color(argb: 0xB3FFFFFF),
                pillFill: Color(argb: 0x1A4DD0C4),
                pillText: Color(argb: 0xFF0B5B49)
            )

        case (.glass, true):
            return Theme(
                fill: .gradient([
                    Color(argb: 0xFF0F1A18),
                    Color(argb: 0xFF101F22),
                    Color(argb: 0xFF0B1514)
                ]),
                cardFill: Color(argb: 0x14FFFFFF),
                cardStroke: Color(argb: 0x33FFFFFF),
                tileFill: Color(argb: 0x14FFFFFF),
                tileStroke: Color(argb: 0x33FFFFFF),
                inkPrimary: Color(argb: 0xFFEAF4F1),
                inkSecondary: Color(argb: 0xFF9BB3AE),
                accent: Color(argb: 0xFF4DD0C4),
                divider: Color(argb: 0x33FFFFFF),
                sectionBar: Color(argb: 0xFF4DD0C4),
                logoPlate: Color(argb: 0x14FFFFFF),
                logoPlateStroke: Color(argb: 0x33FFFFFF),
                pillFill: Color(argb: 0x1A38B2A6),
                pillText: Color(argb: 0xFF80DEEA)
            )

        case (.flat, false):
            return Theme(
                fill: .solid(Color(argb: 0xFFFFFFFF)),
                cardFill: Color(argb: 0xFFFFFFFF),
                cardStroke: Color(argb: 0xFFECF0F4),
                tileFill: Color(argb: 0x0A009688),
                tileStroke: Color(argb: 0x00000000),
                inkPrimary: Color(argb: 0xFF1A1A1A),
                inkSecondary: Color(argb: 0xFF7A7A7A),
                accent: Color(argb: 0xFF009688),
                divider: Color(argb: 0xFFEFEFEF),
                sectionBar: Color(argb: 0xFF009688),
                logoPlate: Color(argb: 0x00000000),
                logoPlateStroke: Color(argb: 0x00000000),
                pillFill: Color(argb: 0x18009688),
                pillText: Color(argb: 0xFF009688)
            )

        case (.flat, true):
            return Theme(
                fill: .solid(Color(argb: 0xFF121212)),
                cardFill: Color(argb: 0xFF1E1E1E),
                cardStroke: Color(argb: 0xFF2A2A2A),
                tileFill: Color(argb: 0x14FFFFFF),
                tileStroke: Color(argb: 0x00000000),
                inkPrimary: Color(argb: 0xFFF2F2F2),
                inkSecondary: Color(argb: 0xFF9E9E9E),
                accent: Color(argb: 0xFF4DD0C4),
                divider: Color(argb: 0xFF2A2A2A),
                sectionBar: Color(argb: 0xFF4DD0C4),
                logoPlate: Color(argb: 0x00000000),
                logoPlateStroke: Color(argb: 0x00000000),
                pillFill: Color(argb: 0x1A38B2A6),
                pillText: Color(argb: 0xFF80DEEA)
            )
        }
    }
}
