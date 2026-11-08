import SwiftUI

/// 間取り：部屋を選ぶと、その部屋の場所と「最後にやった日」が並ぶ。場所の名前で探せる
struct PlanView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var query = ""
    @State private var opened: Spot?

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if hSize == .regular {
                        HStack(alignment: .top, spacing: Space.xl) {
                            VStack(alignment: .leading, spacing: Space.l) {
                                ScreenHeader(label: "間取り", title: "家の澄みぐあい")
                                floorPlan
                                legend
                            }
                            .frame(maxWidth: 520)
                            list.frame(maxWidth: 440)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: Space.l) {
                            ScreenHeader(label: "間取り", title: "家の澄みぐあい")
                            floorPlan
                            legend
                            list
                        }
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.m)
            }
            .background(Palette.ground)
            .searchable(text: $query, prompt: "場所で探す（例：レンジフード）")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if model.screenshotScene == "spot" { opened = SpotData.byID["k-hood-out"] }
            }
            .sheet(item: $opened) { spot in
                SpotDetailView(spot: spot).presentationBackground(Palette.ground)
            }
        }
    }

    private var floorPlan: some View {
        let planner = model.planner
        var hazes: [Room: Double] = [:]
        for room in Room.allCases { hazes[room] = planner.haze(of: room, on: model.today) }
        return FloorPlanView(
            hazes: hazes,
            today: Set(model.todaySpots.map(\.room)),
            hidden: model.household.hiddenRooms,
            selected: model.selectedRoom,
            onTap: { room in
                withAnimation(.easeOut(duration: 0.25)) {
                    model.selectedRoom = model.selectedRoom == room ? nil : room
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .softShadow()
        .sensoryFeedback(.selection, trigger: model.selectedRoom) { _, _ in model.hapticsOn }
    }

    private var legend: some View {
        HStack(spacing: Space.l) {
            legendItem(haze: 0.05, text: "澄んでいる")
            legendItem(haze: 0.5, text: "そろそろ")
            legendItem(haze: 1, text: "曇っている")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(haze: Double, text: String) -> some View {
        HStack(spacing: 6) {
            HazeView(haze: haze, seed: 3)
                .background(Palette.paper)
                .frame(width: 22, height: 16)
                .overlay(Rectangle().strokeBorder(Palette.line, lineWidth: 0.8))
            Text(text).font(.caption).foregroundStyle(Palette.sub)
        }
        .accessibilityHidden(true)
    }

    // MARK: - 一覧

    private var shownSpots: [Spot] {
        let today = model.today
        let planner = model.planner
        let base: [Spot]
        if !query.isEmpty {
            base = model.spots.filter { $0.name.localizedStandardContains(query) || $0.room.name.localizedStandardContains(query) }
        } else if let room = model.selectedRoom {
            base = model.spots.filter { $0.room == room }
        } else {
            base = model.spots
        }
        return base.sorted { planner.haze(of: $0, on: today) > planner.haze(of: $1, on: today) }
    }

    private var lockedCount: Int {
        let rooms: Set<Room> = model.selectedRoom.map { [$0] } ?? Set(Room.allCases)
        return SpotData.all.filter { !model.isUnlocked($0.pack) && rooms.contains($0.room) }.count
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(query.isEmpty ? (model.selectedRoom?.name ?? "家じゅう") : "「\(query)」").font(Typo.title(.headline)).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(shownSpots.count) か所").font(.caption).foregroundStyle(Palette.sub).monospacedDigit()
            }
            if model.selectedRoom != nil && query.isEmpty {
                Button("家じゅうを見る") { withAnimation(.easeOut(duration: 0.25)) { model.selectedRoom = nil } }
                    .font(.footnote).foregroundStyle(Palette.mintDeep)
            }
            if shownSpots.isEmpty {
                PaperPanel {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text(query.isEmpty ? "この部屋は、家にない部屋になっています" : "見つかりませんでした")
                            .font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
                        Text(query.isEmpty ? "設定の「家の部屋」で戻せます。" : "「換気扇」「網戸」「排水口」のように、場所の名前の一部で探してみてください。")
                            .font(.footnote).foregroundStyle(Palette.sub)
                    }
                }
            }
            VStack(spacing: 0) {
                ForEach(shownSpots) { spot in
                    Button { opened = spot } label: { SpotRow(spot: spot) }
                        .buttonStyle(.plain)
                    if spot.id != shownSpots.last?.id { Divider().overlay(Palette.line) }
                }
            }
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
            if !model.isPro && lockedCount > 0 {
                Button { model.showPaywall = true } label: {
                    Label("Pro の「替えどき」「季節の手入れ」に、あと \(lockedCount) か所", systemImage: "lock")
                        .font(.footnote)
                        .foregroundStyle(Palette.mintDeep)
                }
                .padding(.top, Space.xs)
            }
        }
    }
}

/// 一覧の 1 行：曇りの小窓・場所・最後にやった日
struct SpotRow: View {
    @Environment(AppModel.self) private var model
    let spot: Spot

    var body: some View {
        let haze = model.planner.haze(of: spot, on: model.today)
        HStack(spacing: Space.m) {
            HazeView(haze: haze, seed: spot.id.count)
                .background(model.isDoneToday(spot) ? Palette.mintSoft : Palette.paper)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.8))
            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name).font(.subheadline).foregroundStyle(Palette.ink).lineLimit(2)
                Text("\(spot.room.name)・\(spot.minutes) 分・\(spot.intervalText)")
                    .font(.caption).foregroundStyle(Palette.sub)
            }
            Spacer(minLength: Space.s)
            VStack(alignment: .trailing, spacing: 2) {
                Text(DayText.relative(model.lastDone(spot), from: model.today, calendar: model.calendar))
                    .font(.caption).foregroundStyle(model.lastDone(spot) == nil ? Palette.sub : Palette.ink.opacity(0.8))
                if spot.pack != .basic {
                    Text(spot.pack.title).font(.caption2).foregroundStyle(Palette.mintDeep)
                }
            }
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s + 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue("澄み \(Int(((1 - haze) * 100).rounded()))%")
    }
}

/// 1 か所の詳しい画面：手順・道具・こつ・これまでの記録
struct SpotDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let spot: Spot

    var body: some View {
        let done = model.isDoneToday(spot)
        let history = model.history(of: spot)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    ScreenHeader(label: "\(spot.room.name)・\(spot.minutes) 分・\(spot.intervalText)", title: spot.name)
                    if !spot.tools.isEmpty {
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text("用意するもの").smallLabel()
                            FlowLayout { ForEach(spot.tools, id: \.self) { ToolChip(tool: $0) } }
                        }
                    }
                    PaperPanel {
                        VStack(alignment: .leading, spacing: Space.m) {
                            Text("手順").smallLabel()
                            ForEach(Array(spot.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                                    Text("\(index + 1)").font(.system(.body, design: .serif)).foregroundStyle(Palette.mintDeep)
                                    Text(step).font(.subheadline).foregroundStyle(Palette.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            if !spot.tip.isEmpty {
                                Text("こつ　\(spot.tip)").font(.footnote).foregroundStyle(Palette.ink.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("これまで").smallLabel()
                        if history.isEmpty {
                            Text("まだ記録がありません。済ませると、ここに日付が残ります。")
                                .font(.footnote).foregroundStyle(Palette.sub)
                        } else {
                            FlowLayout {
                                ForEach(history, id: \.self) { day in
                                    Text("\(String(day.year))/\(day.month)/\(day.day)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Palette.ink.opacity(0.8))
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(Capsule().fill(Palette.mintSoft))
                                }
                            }
                        }
                    }
                    if done {
                        HStack {
                            Text("今日、済ませました").font(.subheadline).foregroundStyle(Palette.mintDeep)
                            Spacer()
                            Button("取り消す") { model.undo(spot) }.font(.footnote).foregroundStyle(Palette.sub)
                        }
                    } else {
                        Button("今日、済ませた") {
                            withAnimation(.easeOut(duration: 0.6)) { model.markDone(spot) }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    if spot.pack == .custom {
                        Button("この場所を消す", role: .destructive) {
                            model.removeCustomSpot(spot)
                            dismiss()
                        }
                        .font(.footnote)
                    }
                }
                .padding(Space.l)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.ground)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: done) { _, new in new && model.hapticsOn }
        }
    }
}
