import SwiftUI

/// 今日：間取り図と、今日の 1 か所の札。
/// iPhone Duo の内側（regular）では左に間取り図、右に札と手順を並べる。外側・ほかの iPhone では縦に重ねる
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if hSize == .regular {
                        HStack(alignment: .top, spacing: Space.xl) {
                            VStack(alignment: .leading, spacing: Space.l) {
                                header
                                plan
                                yearEndPanel
                            }
                            .frame(maxWidth: 520)
                            VStack(spacing: Space.l) {
                                tags
                                sharePanel
                                streakPanel
                            }
                            .frame(maxWidth: 440)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: Space.l) {
                            header
                            plan
                            tags
                            sharePanel
                            yearEndPanel
                            streakPanel
                        }
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.m)
            }
            .background(Palette.ground)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refreshPlan() }
        }
    }

    // MARK: - 見出し

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日の小掃除").smallLabel()
                Text(DayText.short(model.today, calendar: model.calendar))
                    .font(Typo.title(.title))
                    .foregroundStyle(Palette.ink)
                    .kerning(-0.5)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(model.planner.clarity(on: model.today))")
                        .font(Typo.number(size: 40))
                        .kerning(-2)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(Palette.ink)
                    Text("%").font(.system(.subheadline, design: .serif)).foregroundStyle(Palette.sub)
                }
                Text("家の澄み").smallLabel()
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - 間取り図

    private var plan: some View {
        let planner = model.planner
        let today = model.today
        var hazes: [Room: Double] = [:]
        for room in Room.allCases { hazes[room] = planner.haze(of: room, on: today) }
        return FloorPlanView(
            hazes: hazes,
            today: Set(model.todaySpots.filter { !model.isDoneToday($0) }.map(\.room)),
            cleaned: Set(model.entries(on: today).map(\.room)),
            hidden: model.household.hiddenRooms,
            onTap: { room in
                model.selectedRoom = room
                model.tab = .plan
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .softShadow()
        .animation(.easeOut(duration: 1.2), value: model.household.log.count)
    }

    // MARK: - 札

    private var tags: some View {
        VStack(spacing: Space.l) {
            ForEach(model.todaySpots) { spot in
                SpotTag(spot: spot)
            }
            if model.todaySpots.isEmpty {
                PaperPanel {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("今日の場所がありません").font(Typo.title(.headline)).foregroundStyle(Palette.ink)
                        Text("設定で部屋をすべて外しているか、季節の外です。設定の「家の部屋」を見直してください。")
                            .font(.subheadline).foregroundStyle(Palette.sub)
                        Button("設定を開く") { model.tab = .settings }.buttonStyle(QuietButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - 今日の家を共有

    @ViewBuilder
    private var sharePanel: some View {
        if model.doneTodayCount > 0, let image = shareImage {
            ShareLink(item: image, preview: SharePreview("今日の家", image: image)) {
                Label("今日の家を、1 枚の絵にして送る", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(QuietButtonStyle())
        }
    }

    /// 共有カード（1080×1350）。間取り図・日付・家の澄み・今日の場所
    private var shareImage: Image? {
        let renderer = ImageRenderer(content: ShareCard(
            day: DayText.short(model.today, calendar: model.calendar),
            clarity: model.planner.clarity(on: model.today),
            hazes: Dictionary(uniqueKeysWithValues: Room.allCases.map { ($0, model.planner.haze(of: $0, on: model.today)) }),
            cleaned: Set(model.entries(on: model.today).map(\.room)),
            hidden: model.household.hiddenRooms,
            spots: model.entries(on: model.today).map(\.name),
            streak: model.streak.current
        ))
        renderer.scale = 3
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }

    // MARK: - 年末までの進み

    private var yearEndPanel: some View {
        let progress = model.yearEnd
        return PaperPanel {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text("年末までに").smallLabel()
                    Spacer()
                    Text("あと \(progress.daysLeft) 日").font(.caption).foregroundStyle(Palette.sub).monospacedDigit()
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(progress.done)")
                        .font(Typo.number(size: 30)).kerning(-1.5).monospacedDigit()
                        .contentTransition(.numericText())
                    Text("/ \(progress.total) か所").font(.subheadline).foregroundStyle(Palette.sub)
                }
                .foregroundStyle(Palette.ink)
                ThinBar(fraction: progress.fraction)
                if model.isPro {
                    Text(progress.perDay == 0 ? "年末の所は、もう全部済んでいます。大掃除はいりません。" : "1 日 \(progress.perDay) か所ずつで、12 月 28 日に間に合います。今日の札は年末の所を先に出しています。")
                        .font(.footnote).foregroundStyle(Palette.ink.opacity(0.8))
                } else {
                    Button {
                        model.showPaywall = true
                    } label: {
                        Label("年末の逆算（Pro）：1 日何か所で間に合うか", systemImage: "lock")
                            .font(.footnote)
                            .foregroundStyle(Palette.mintDeep)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 続けた日

    private var streakPanel: some View {
        let streak = model.streak
        return PaperPanel {
            HStack(spacing: Space.l) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("続けて").smallLabel()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(streak.current)").font(Typo.number(size: 28)).kerning(-1).monospacedDigit()
                        Text("日").font(.caption).foregroundStyle(Palette.sub)
                    }
                }
                Divider().frame(height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("今年").smallLabel()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(streak.thisYear)").font(Typo.number(size: 28)).kerning(-1).monospacedDigit()
                        Text("日").font(.caption).foregroundStyle(Palette.sub)
                    }
                }
                Spacer()
                Text(streakLine(streak))
                    .font(.footnote)
                    .foregroundStyle(Palette.ink.opacity(0.75))
                    .multilineTextAlignment(.trailing)
            }
            .foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }

    private func streakLine(_ s: Streak) -> String {
        if s.doneToday { return "今日の分は\n済みました" }
        if s.current > 0 { return "今日の 1 か所で\n\(s.current + 1) 日目" }
        if s.thisYear > 0 { return "おかえりなさい。\n今日から、また" }
        return "まずは 1 か所、\n\(model.household.budget) 分から"
    }
}

/// 今日の札：場所・時間・道具・手順。済むと札に印がつき、間取りの部屋が澄む
struct SpotTag: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let spot: Spot
    @State private var swapNudge = false

    var body: some View {
        let done = model.isDoneToday(spot)
        let checked = model.checkedSteps[spot.id] ?? []
        VStack(spacing: 0) {
            StringLine()
                .stroke(Palette.sub.opacity(0.6), lineWidth: 1)
                .frame(height: 18)
            VStack(alignment: .leading, spacing: Space.m) {
                Spacer().frame(height: 22)
                HStack(alignment: .firstTextBaseline) {
                    Text(spot.room.name).smallLabel()
                    Spacer()
                    Text("\(spot.minutes) 分").font(.system(.subheadline, design: .serif)).foregroundStyle(Palette.mintDeep).monospacedDigit()
                }
                Text(spot.name)
                    .font(Typo.title(.title2))
                    .foregroundStyle(Palette.ink)
                    .kerning(-0.3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Space.s) {
                    Text("前回：\(DayText.relative(model.lastDone(spot), from: model.today, calendar: model.calendar))")
                    Text("・")
                    Text("目安 \(spot.intervalText)")
                }
                .font(.caption)
                .foregroundStyle(Palette.sub)
                if !spot.tools.isEmpty {
                    FlowLayout { ForEach(spot.tools, id: \.self) { ToolChip(tool: $0) } }
                }
                VStack(alignment: .leading, spacing: Space.s) {
                    ForEach(Array(spot.steps.enumerated()), id: \.offset) { index, step in
                        Button {
                            model.toggleStep(index, of: spot)
                        } label: {
                            HStack(alignment: .top, spacing: Space.m) {
                                StepCheck(done: checked.contains(index) || done)
                                Text(step)
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.ink.opacity(checked.contains(index) || done ? 0.55 : 0.9))
                                    .strikethrough(checked.contains(index) || done, color: Palette.sub)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(done)
                        .accessibilityLabel("手順 \(index + 1)：\(step)")
                        .accessibilityValue(checked.contains(index) || done ? "済み" : "まだ")
                    }
                }
                .sensoryFeedback(.selection, trigger: checked.count) { _, _ in model.hapticsOn }
                if !spot.tip.isEmpty {
                    Text("こつ　\(spot.tip)")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                actions(done: done)
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.l)
            .background(TagBackground())
            .overlay(alignment: .topTrailing) {
                if done { CleanStamp().padding(.trailing, Space.l).padding(.top, 56).transition(.scale(scale: 1.3).combined(with: .opacity)) }
            }
            .offset(x: swapNudge ? -10 : 0)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: done)
        .sensoryFeedback(.success, trigger: done) { _, new in new && model.hapticsOn }
    }

    @ViewBuilder
    private func actions(done: Bool) -> some View {
        if done {
            HStack {
                Text("済みました。次は \(DayText.short(model.planner.nextDue(of: spot, after: model.today), calendar: model.calendar)) ごろ")
                    .font(.footnote).foregroundStyle(Palette.mintDeep)
                Spacer()
                Button("取り消す") { model.undo(spot) }
                    .font(.footnote).foregroundStyle(Palette.sub)
            }
        } else {
            VStack(spacing: Space.s) {
                Button("済んだ") {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 1.2)) { model.markDone(spot) }
                }
                    .buttonStyle(PrimaryButtonStyle())
                Button("ほかの所にする") {
                    if !reduceMotion {
                        withAnimation(.easeOut(duration: 0.12)) { swapNudge = true }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.12)) { swapNudge = false }
                    }
                    model.swap(spot)
                }
                .buttonStyle(QuietButtonStyle())
                .sensoryFeedback(.impact(weight: .light), trigger: model.household.plan?.skipped.count ?? 0) { _, _ in model.hapticsOn }
            }
        }
    }
}

/// 済みの印（細い二重丸に「済」。判子調の太い枠にはしない）
struct CleanStamp: View {
    var body: some View {
        ZStack {
            Circle().stroke(Palette.mintDeep.opacity(0.8), lineWidth: 1.2)
            Circle().inset(by: 4).stroke(Palette.mintDeep.opacity(0.5), lineWidth: 0.8)
            Text("済").font(.system(size: 20, design: .serif)).foregroundStyle(Palette.mintDeep)
        }
        .frame(width: 52, height: 52)
        .rotationEffect(.degrees(-8))
        .accessibilityLabel("済み")
    }
}

/// 共有カード：紙の上の間取り図と、今日済ませた場所。テープは 1 枚だけ
struct ShareCard: View {
    let day: String
    let clarity: Int
    let hazes: [Room: Double]
    let cleaned: Set<Room>
    let hidden: Set<Room>
    let spots: [String]
    let streak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("こそうじ暦").font(.system(size: 11, weight: .medium)).kerning(0.6).foregroundStyle(Palette.sub)
                    Text(day).font(.system(size: 24, design: .serif)).foregroundStyle(Palette.ink)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(clarity)").font(.system(size: 40, design: .serif)).kerning(-2).monospacedDigit()
                    Text("%").font(.system(size: 14, design: .serif)).foregroundStyle(Palette.sub)
                }
                .foregroundStyle(Palette.ink)
            }
            FloorPlanView(hazes: hazes, cleaned: cleaned, hidden: hidden)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("今日の小掃除").font(.system(size: 11, weight: .medium)).kerning(0.6).foregroundStyle(Palette.sub)
                ForEach(spots, id: \.self) { name in
                    Text("・\(name)").font(.system(size: 15)).foregroundStyle(Palette.ink)
                }
                if streak > 1 {
                    Text("続けて \(streak) 日").font(.system(size: 13, design: .serif)).foregroundStyle(Palette.mintDeep)
                }
            }
        }
        .padding(24)
        .frame(width: 360, height: 450)
        .background(Palette.paper)
        .overlay(alignment: .top) {
            TapeShape().fill(Palette.tape.opacity(0.85)).frame(width: 78, height: 20).rotationEffect(.degrees(-4)).offset(y: -6)
        }
        .padding(12)
        .background(Palette.ground)
    }
}
