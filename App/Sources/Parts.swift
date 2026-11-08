import SwiftUI

// 題材の現物を部品にする：間取り図（壁の細い線・ドアの弧）、曇り（ほこりの点）、掃除当番の札、テープ。

// MARK: - 間取り図

/// 家の間取り図。部屋ごとの曇りを点で描き、今日の部屋を淡く塗る
struct FloorPlanView: View {
    let hazes: [Room: Double]
    var today: Set<Room> = []
    var hidden: Set<Room> = []
    var selected: Room?
    var showLabels = true
    var onTap: ((Room) -> Void)?

    static let aspect: CGFloat = 1.18

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Palette.paper)
                ForEach(Room.allCases) { room in
                    roomCell(room, in: size)
                }
                // 外壁だけ少し太く
                Rectangle().strokeBorder(Palette.ink.opacity(0.55), lineWidth: 1.6)
            }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private func roomCell(_ room: Room, in size: CGSize) -> some View {
        let f = room.frame
        let rect = CGRect(x: f.x * size.width, y: f.y * size.height, width: f.w * size.width, height: f.h * size.height)
        let isHidden = hidden.contains(room)
        let isToday = today.contains(room)
        ZStack {
            Rectangle().fill(isToday ? Palette.mintSoft : Palette.paper)
            if isHidden {
                HatchView().opacity(0.5)
            } else {
                HazeView(haze: hazes[room] ?? 0, seed: Room.allCases.firstIndex(of: room) ?? 0)
            }
            Rectangle().strokeBorder(Palette.ink.opacity(0.35), lineWidth: 0.8)
            if selected == room {
                Rectangle().strokeBorder(Palette.mintDeep, style: StrokeStyle(lineWidth: 1.6, dash: [4, 3]))
            }
            DoorArc(corner: room.doorCorner)
                .stroke(Palette.ink.opacity(0.3), lineWidth: 0.7)
            if showLabels {
                VStack(spacing: 2) {
                    if isToday {
                        Text("今日")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(TapeShape().fill(Palette.tape.opacity(0.85)))
                            .rotationEffect(.degrees(-4))
                    }
                    Text(room.shortName)
                        .font(.system(size: rect.width < 70 ? 10 : 12, design: .serif))
                        .foregroundStyle(isHidden ? Palette.sub : Palette.ink.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(4)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .contentShape(Rectangle())
        .onTapGesture { onTap?(room) }
        .offset(x: rect.minX, y: rect.minY)
    }

    private var accessibilitySummary: String {
        let parts = Room.allCases.filter { !hidden.contains($0) }.map { room in
            "\(room.name) 澄み \(Int(((1 - (hazes[room] ?? 0)) * 100).rounded()))%"
        }
        return "間取り図。" + parts.joined(separator: "、")
    }
}

extension Room {
    /// ドアの弧を描く角
    var doorCorner: DoorArc.Corner {
        switch self {
        case .bedroom, .storage, .toilet: .bottomRight
        case .washroom, .bath: .topRight
        case .living, .kitchen: .bottomLeft
        case .hallway: .topLeft
        case .entrance: .topRight
        case .veranda: .none
        }
    }
}

/// ドアの 1/4 円（間取り図の記号）
struct DoorArc: Shape {
    enum Corner { case topLeft, topRight, bottomLeft, bottomRight, none }
    let corner: Corner

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(16, min(rect.width, rect.height) * 0.32)
        let inset: CGFloat = 3
        switch corner {
        case .none:
            return p
        case .topLeft:
            let c = CGPoint(x: rect.minX + inset, y: rect.minY + inset)
            p.move(to: c); p.addLine(to: CGPoint(x: c.x + r, y: c.y))
            p.addArc(center: c, radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        case .topRight:
            let c = CGPoint(x: rect.maxX - inset, y: rect.minY + inset)
            p.move(to: c); p.addLine(to: CGPoint(x: c.x, y: c.y + r))
            p.addArc(center: c, radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        case .bottomLeft:
            let c = CGPoint(x: rect.minX + inset, y: rect.maxY - inset)
            p.move(to: c); p.addLine(to: CGPoint(x: c.x, y: c.y - r))
            p.addArc(center: c, radius: r, startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
        case .bottomRight:
            let c = CGPoint(x: rect.maxX - inset, y: rect.maxY - inset)
            p.move(to: c); p.addLine(to: CGPoint(x: c.x - r, y: c.y))
            p.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
        return p
    }
}

/// 曇り：細かい点の重なり。haze が上がるほど点が増え、地が少しくすむ
struct HazeView: View {
    let haze: Double
    let seed: Int

    var body: some View {
        ZStack {
            Rectangle().fill(Palette.haze.opacity(0.16 * haze))
            HazeDots(haze: haze, seed: seed).fill(Palette.haze.opacity(0.75))
        }
        .allowsHitTesting(false)
    }
}

/// 曇りの点。Shape なので haze の変化が補間され、掃除すると点が少しずつ消える
struct HazeDots: Shape {
    var haze: Double
    let seed: Int

    var animatableData: Double {
        get { haze }
        set { haze = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 6
        let cols = Int(rect.width / step) + 1
        let rows = Int(rect.height / step) + 1
        for row in 0..<rows {
            for col in 0..<cols {
                let u = Self.unit(seed, row, col)
                guard u < haze * 0.8 else { continue }
                let shift: CGFloat = row.isMultiple(of: 2) ? 0 : step / 2
                let x = rect.minX + CGFloat(col) * step + shift + CGFloat(u * 2)
                let y = rect.minY + CGFloat(row) * step + CGFloat(Self.unit(seed + 7, col, row) * 2)
                let r: CGFloat = 0.6 + CGFloat(u) * 0.6
                p.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
        }
        return p
    }

    /// 決まった乱数（毎回同じ散り方。スクリーンショットが安定する）
    static func unit(_ a: Int, _ b: Int, _ c: Int) -> Double {
        var x = UInt32(truncatingIfNeeded: a &* 73_856_093 ^ b &* 19_349_663 ^ c &* 83_492_791)
        x ^= x >> 13
        x = x &* 0x5bd1e995
        x ^= x >> 15
        return Double(x % 1000) / 1000
    }
}

/// 家にない部屋の斜線
struct HatchView: View {
    var body: some View {
        Canvas { context, size in
            var p = Path()
            var x: CGFloat = -size.height
            while x < size.width {
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 8
            }
            context.stroke(p, with: .color(Palette.line), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 掃除当番の札

/// 札の形：上の角を落とし、紐を通す穴をあける
struct TagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cut: CGFloat = min(22, rect.width * 0.12)
        let r: CGFloat = Radius.card
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        p.closeSubpath()
        // 紐の穴
        p.addEllipse(in: CGRect(x: rect.midX - 6, y: rect.minY + 10, width: 12, height: 12))
        return p
    }
}

/// 札の地（穴を抜き、細い縁と弱い影）
struct TagBackground: View {
    var tint: Color = Palette.tag

    var body: some View {
        ZStack {
            TagShape().fill(tint, style: FillStyle(eoFill: true))
                .liftShadow()
            TagShape().stroke(Palette.line, lineWidth: 1)
            // 穴の補強の輪
            GeometryReader { geo in
                Circle()
                    .stroke(Palette.mint, lineWidth: 2)
                    .frame(width: 18, height: 18)
                    .position(x: geo.size.width / 2, y: 16)
            }
        }
    }
}

/// 札を吊るす紐
struct StringLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX - 18, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.midX - 14, y: rect.maxY - 2))
        p.move(to: CGPoint(x: rect.midX + 18, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.midX + 14, y: rect.maxY - 2))
        return p
    }
}

// MARK: - テープ

/// 両端がギザギザのテープ（歯 4・深さ 3）
struct TapeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let teeth = 4
        let depth: CGFloat = min(3, rect.width * 0.08)
        let h = rect.height / CGFloat(teeth)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        for i in 0..<teeth {
            p.addLine(to: CGPoint(x: rect.maxX - depth, y: rect.minY + h * (CGFloat(i) + 0.5)))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * CGFloat(i + 1)))
        }
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        for i in (0..<teeth).reversed() {
            p.addLine(to: CGPoint(x: rect.minX + depth, y: rect.minY + h * (CGFloat(i) + 0.5)))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * CGFloat(i)))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - 小さな部品

/// 道具の札（細い線のピル）
struct ToolChip: View {
    let tool: Tool

    var body: some View {
        Text(tool.name)
            .font(.caption)
            .foregroundStyle(Palette.ink.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Palette.paper))
            .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
            .shadow(color: Palette.line, radius: 0, y: 1)
    }
}

/// 折り返して並べる（道具の札）
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// 手順の丸（済むと、チェックの線が描かれる）
struct StepCheck: View {
    let done: Bool

    var body: some View {
        ZStack {
            Circle().strokeBorder(done ? Palette.mintDeep : Palette.line, lineWidth: 1.4)
                .background(Circle().fill(done ? Palette.mintSoft : Palette.paper))
            CheckShape()
                .trim(from: 0, to: done ? 1 : 0)
                .stroke(Palette.mintDeep, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .padding(7)
        }
        .frame(width: 28, height: 28)
    }
}

struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

/// 細い進みの帯
struct ThinBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line)
                Capsule().fill(Palette.mint).frame(width: max(4, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 6)
    }
}

/// 日付の言い方（「11月8日（日）」）
enum DayText {
    static let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    static func short(_ day: DayKey, calendar: Calendar = .current) -> String {
        let w = calendar.component(.weekday, from: day.date(calendar: calendar))
        return "\(day.month)月\(day.day)日（\(weekdays[(w - 1 + 7) % 7])）"
    }

    static func relative(_ day: DayKey?, from today: DayKey, calendar: Calendar = .current) -> String {
        guard let day else { return "まだ記録なし" }
        let d = day.days(to: today, calendar: calendar)
        switch d {
        case ..<1: return "今日"
        case 1: return "きのう"
        case 2..<30: return "\(d) 日前"
        default: return "\(day.month)月\(day.day)日"
        }
    }
}

/// 画面の見出し（小さなラベル＋セリフの題）
struct ScreenHeader: View {
    let label: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).smallLabel()
            Text(title)
                .font(Typo.title(.title))
                .foregroundStyle(Palette.ink)
                .kerning(-0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 細い線の囲み（白いカードの代わりに、紙の上の枠）
struct PaperPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
    }
}
