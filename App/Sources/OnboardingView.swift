import SwiftUI

/// 使い方 3 ページ。1 枚目は動く見本（曇った間取り図が、1 部屋ずつ澄んでいく）
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                pageView(
                    label: "1 / 3",
                    title: "大掃除を、\n1 日 10 分に分ける",
                    text: "年末にまとめてやらず、毎日 1 か所だけ。家の間取り図が、掃除した部屋から澄んでいきます。"
                ) { DemoPlan() }
                .tag(0)
                pageView(
                    label: "2 / 3",
                    title: "今日の 1 か所は、\nアプリが決める",
                    text: "レンジフード・網戸・排水口など、やり方つきの 115 か所から。前にやった日と季節を見て、そろそろの所を出します。"
                ) { DemoTag() }
                .tag(1)
                pageView(
                    label: "3 / 3",
                    title: "1 か所の時間を\n選んでください",
                    text: "あとから設定で変えられます。記録はこの iPhone の中だけに保存し、外には送りません。"
                ) { budgetPicker }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Capsule().fill(i == page ? Palette.mintDeep : Palette.line)
                        .frame(width: i == page ? 18 : 6, height: 6)
                }
            }
            .animation(.easeOut(duration: 0.25), value: page)
            .padding(.bottom, Space.l)

            Button(page < 2 ? "次へ" : "はじめる") {
                if page < 2 {
                    withAnimation(.easeOut(duration: 0.3)) { page += 1 }
                } else {
                    withAnimation(.easeOut(duration: 0.35)) { model.onboardingDone = true }
                    model.refreshPlan()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
            .frame(maxWidth: 520)
        }
        .background(Palette.ground)
        .sensoryFeedback(.selection, trigger: page)
    }

    private func pageView<V: View>(label: String, title: String, text: String, @ViewBuilder visual: () -> V) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                visual()
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Space.xl)
                Text(label).smallLabel()
                Text(title)
                    .font(Typo.title(.title))
                    .foregroundStyle(Palette.ink)
                    .kerning(-0.5)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text)
                    .font(.body)
                    .foregroundStyle(Palette.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.xl)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private var budgetPicker: some View {
        VStack(spacing: Space.s) {
            ForEach(AppModel.budgets, id: \.self) { minutes in
                let chosen = model.household.budget == minutes
                Button {
                    model.setBudget(minutes)
                } label: {
                    HStack {
                        Text("\(minutes)").font(Typo.number(size: 28)).kerning(-1).monospacedDigit()
                        Text("分まで").font(.subheadline)
                        Spacer()
                        Text(budgetNote(minutes)).font(.caption).foregroundStyle(Palette.sub)
                        if chosen { Image(systemName: "checkmark").foregroundStyle(Palette.mintDeep) }
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, Space.l)
                    .frame(minHeight: 56)
                    .background(chosen ? Palette.mintSoft : Palette.paper, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(chosen ? Palette.mint : Palette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: model.household.budget)
    }

    private func budgetNote(_ minutes: Int) -> String {
        switch minutes {
        case 5: "朝のしたくの合間に"
        case 10: "おすすめ"
        case 15: "夕食のあとに"
        default: "週末にまとめて"
        }
    }
}

/// 動く見本：曇った家が 1 部屋ずつ澄み、また曇る（動きを減らす設定では、澄んだ絵で止める）
struct DemoPlan: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cleaned = 0
    private let order: [Room] = [.kitchen, .bath, .living, .entrance, .bedroom, .washroom, .toilet, .veranda, .hallway, .storage]

    var body: some View {
        var hazes: [Room: Double] = [:]
        for (i, room) in order.enumerated() { hazes[room] = i < cleaned ? 0.02 : 0.55 + Double(i % 3) * 0.15 }
        return FloorPlanView(hazes: hazes, today: cleaned < order.count ? [order[cleaned]] : [])
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .softShadow()
            .animation(.easeOut(duration: 0.9), value: cleaned)
            .task {
                if reduceMotion { cleaned = 4; return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(1100))
                    cleaned = cleaned >= order.count ? 0 : cleaned + 1
                }
            }
            .accessibilityLabel("見本の間取り図。掃除した部屋から澄んでいく")
    }
}

/// 札の見本
struct DemoTag: View {
    private let spot = SpotData.byID["k-hood-filter"]

    var body: some View {
        VStack(spacing: 0) {
            StringLine().stroke(Palette.sub.opacity(0.6), lineWidth: 1).frame(height: 18)
            VStack(alignment: .leading, spacing: Space.s) {
                Spacer().frame(height: 22)
                HStack {
                    Text("キッチン").smallLabel()
                    Spacer()
                    Text("\(spot?.minutes ?? 20) 分").font(.system(.subheadline, design: .serif)).foregroundStyle(Palette.mintDeep)
                }
                Text(spot?.name ?? "換気扇のフィルター").font(Typo.title(.title2)).foregroundStyle(Palette.ink)
                Text("前回：91 日前・3 か月ごと").font(.caption).foregroundStyle(Palette.sub)
                FlowLayout { ForEach(spot?.tools ?? [], id: \.self) { ToolChip(tool: $0) } }
                ForEach(Array((spot?.steps ?? []).enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: Space.m) {
                        StepCheck(done: i == 0)
                        Text(step).font(.subheadline).foregroundStyle(Palette.ink.opacity(0.85)).padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.l)
            .background(TagBackground())
            .rotationEffect(.degrees(-2))
        }
        .accessibilityElement(children: .combine)
    }
}
