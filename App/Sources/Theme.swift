import SwiftUI

// 色・書体・形を 1 か所で決める（app-quality-bar の look.md §0・§2〜4）。
// アプリの色は mint の 1 系統。差し色は peach のテープだけ（1 画面に 1〜2 枚）。
// 濃い色（deep）は白い文字を載せるボタンと小さな文字だけに使う。

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Palette {
    /// 主な色（L0.76）。帯・今日の部屋・グラフ
    static let mint = Color(hex: 0xA8DCCB)
    /// 淡い地（L0.92）。選択中・札の地
    static let mintSoft = Color(hex: 0xE2F2EC)
    /// 白い文字を載せるボタン・小さな文字（L0.43・S0.28）
    static let mintDeep = Color(hex: 0x4F8C7A)
    /// 紙（間取り図の地）
    static let paper = Color(hex: 0xF9FBFA)
    /// 画面の地（ほぼ白、わずかに緑）
    static let ground = Color(hex: 0xF2F6F4)
    /// 文字（真っ黒にしない）
    static let ink = Color(hex: 0x2E3A40)
    /// 補助の文字
    static let sub = Color(hex: 0x84948F)
    /// 線（間取りの壁・区切り）
    static let line = Color(hex: 0xD9E4E0)
    /// 曇り（ほこりの点）
    static let haze = Color(hex: 0xA7B2AE)
    /// 差し色のテープ（peach、L0.80）
    static let tape = Color(hex: 0xF4BBA4)
    /// 札の地（白に近い、少しだけ温かい）
    static let tag = Color(hex: 0xFBFAF6)
}

enum Typo {
    /// 大きな数字・見出し（セリフ）
    static func display(_ style: Font.TextStyle = .largeTitle) -> Font { .system(style, design: .serif) }
    static func title(_ style: Font.TextStyle = .title2) -> Font { .system(style, design: .serif).weight(.medium) }
    static func number(size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    /// 小さなラベル（字間を開けて使う）
    static let label = Font.caption.weight(.medium)
}

enum Radius {
    static let small: CGFloat = 6
    static let chip: CGFloat = 12
    static let card: CGFloat = 14
    static let sheet: CGFloat = 18
}

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

extension View {
    /// 普段の弱い影（opacity 0.06・radius 10・y 4）
    func softShadow() -> some View { shadow(color: Palette.ink.opacity(0.06), radius: 10, y: 4) }
    /// 浮いた物（札）だけ少し強く
    func liftShadow() -> some View { shadow(color: Palette.ink.opacity(0.12), radius: 8, y: 6) }

    /// 小さなラベルの組み方（字間を開ける）
    func smallLabel() -> some View {
        font(Typo.label).kerning(0.6).foregroundStyle(Palette.sub)
    }
}

/// 主なボタン（deep の地に白い文字、高さ 52）
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Palette.mintDeep, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 控えめなボタン（細い線の枠）
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Palette.mintDeep)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 1)
                    .background(Palette.paper, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
