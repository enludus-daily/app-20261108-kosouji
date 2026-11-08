import SwiftUI

/// 暦：月の暦に済ませた日が淡く塗られ、日を選ぶとその日の場所が並ぶ
struct CalendarView: View {
    @Environment(AppModel.self) private var model
    @State private var monthOffset = 0
    @State private var picked: DayKey?

    private var shownMonth: (year: Int, month: Int) {
        let base = model.today
        var total = base.year * 12 + (base.month - 1) + monthOffset
        total = max(total, 0)
        return (total / 12, total % 12 + 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    ScreenHeader(label: "暦", title: "\(String(shownMonth.year))年 \(shownMonth.month)月")
                    if model.household.log.isEmpty {
                        PaperPanel {
                            VStack(alignment: .leading, spacing: Space.s) {
                                Text("まだ何も済ませていません").font(Typo.title(.headline)).foregroundStyle(Palette.ink)
                                Text("今日の札を 1 か所済ませると、この暦にその日が淡く塗られます。1 年たつと、家じゅうを一巡りしています。")
                                    .font(.subheadline).foregroundStyle(Palette.sub)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button("今日の札を見る") { model.tab = .today }.buttonStyle(QuietButtonStyle())
                            }
                        }
                    }
                    monthGrid
                    summary
                    dayList
                }
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.m)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.ground)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - 月の暦

    private var days: [DayKey?] {
        let (year, month) = shownMonth
        let cal = model.calendar
        let first = DayKey(year: year, month: month, day: 1)
        let weekday = cal.component(.weekday, from: first.date(calendar: cal))  // 1 = 日
        let count = cal.range(of: .day, in: .month, for: first.date(calendar: cal))?.count ?? 30
        let leading: [DayKey?] = Array(repeating: nil, count: weekday - 1)
        return leading + (1...count).map { DayKey(year: year, month: month, day: $0) }
    }

    private var monthGrid: some View {
        let counts = Dictionary(grouping: model.household.log, by: \.day).mapValues(\.count)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return VStack(spacing: Space.s) {
            HStack {
                Button { withAnimation(.easeOut(duration: 0.25)) { monthOffset -= 1; picked = nil } } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("前の月")
                Spacer()
                Button { withAnimation(.easeOut(duration: 0.25)) { monthOffset += 1; picked = nil } } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .disabled(monthOffset >= 0)
                .accessibilityLabel("次の月")
            }
            .foregroundStyle(Palette.mintDeep)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(DayText.weekdays, id: \.self) { w in
                    Text(w).font(.caption2).foregroundStyle(Palette.sub)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day, count: counts[day] ?? 0)
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .padding(Space.m)
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private func dayCell(_ day: DayKey, count: Int) -> some View {
        let isToday = day == model.today
        let isPicked = day == picked
        // 濃さは 3 段（1・2・3 か所以上）
        let level = min(count, 3)
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { picked = isPicked ? nil : day }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .fill(level == 0 ? Color.clear : Palette.mint.opacity(0.3 + 0.23 * Double(level)))
                if isToday {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .strokeBorder(Palette.mintDeep, lineWidth: 1.2)
                }
                if isPicked {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .strokeBorder(Palette.ink.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
                Text("\(day.day)")
                    .font(.system(.footnote, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(day > model.today ? Palette.sub.opacity(0.6) : Palette.ink)
            }
            .frame(height: 40)
        }
        .buttonStyle(.plain)
        .disabled(day > model.today)
        .accessibilityLabel("\(day.month)月\(day.day)日")
        .accessibilityValue(count == 0 ? "記録なし" : "\(count) か所")
    }

    // MARK: - 月のまとめ

    private var summary: some View {
        let (year, month) = shownMonth
        let inMonth = model.household.log.filter { $0.day.year == year && $0.day.month == month }
        let dayCount = Set(inMonth.map(\.day)).count
        let rooms = Set(inMonth.compactMap { model.spot($0.spotID)?.room })
        return HStack(spacing: Space.l) {
            stat(value: dayCount, unit: "日", label: "済ませた日")
            stat(value: inMonth.count, unit: "か所", label: "済ませた所")
            stat(value: rooms.count, unit: "部屋", label: "手が入った部屋")
        }
    }

    private func stat(value: Int, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).smallLabel()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)").font(Typo.number(size: 26)).kerning(-1).monospacedDigit().foregroundStyle(Palette.ink)
                Text(unit).font(.caption).foregroundStyle(Palette.sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - その日の場所

    @ViewBuilder
    private var dayList: some View {
        let day = picked ?? model.today
        let list = model.entries(on: day)
        VStack(alignment: .leading, spacing: Space.s) {
            Text(DayText.short(day, calendar: model.calendar)).font(Typo.title(.headline)).foregroundStyle(Palette.ink)
            if list.isEmpty {
                Text(day == model.today ? "今日はまだです。今日の札から 1 か所どうぞ。" : "この日は、お休みの日でした。")
                    .font(.footnote).foregroundStyle(Palette.sub)
            } else {
                ForEach(list) { spot in
                    HStack(spacing: Space.s) {
                        Circle().fill(Palette.mint).frame(width: 6, height: 6)
                        Text(spot.name).font(.subheadline).foregroundStyle(Palette.ink)
                        Spacer()
                        Text(spot.room.name).font(.caption).foregroundStyle(Palette.sub)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
