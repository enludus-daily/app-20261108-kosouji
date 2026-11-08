import Foundation
import Observation
import SwiftUI

enum AppTab: Hashable { case today, plan, calendar, settings }

/// 保存する記録（UserDefaults に JSON で 1 つ）
struct Household: Codable, Equatable, Sendable {
    var startDay: DayKey?
    var log: [LogEntry] = []
    var plan: DayPlan?
    /// 1 か所にかける時間の上限（分）
    var budget: Int = 10
    /// Pro：1 日に出す数
    var dailyCount: Int = 1
    /// 家にない部屋（間取り図では薄く、候補に出さない）
    var hiddenRooms: Set<Room> = []
    /// Pro：自分で足した場所
    var customSpots: [Spot] = []
    /// 課金の画面を自動で出した日（同じ日に 2 度出さない）
    var paywallShownDay: DayKey?
}

/// 端末の中だけに保存する。テストとスクリーンショットでは差し替える
protocol HouseholdStore: Sendable {
    func load() -> Household?
    func save(_ household: Household)
}

struct DeviceStore: HouseholdStore {
    private let key = "kosouji.household.v1"

    func load() -> Household? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Household.self, from: data)
    }

    func save(_ household: Household) {
        if let data = try? JSONEncoder().encode(household) { UserDefaults.standard.set(data, forKey: key) }
    }
}

struct MemoryStore: HouseholdStore {
    func load() -> Household? { nil }
    func save(_ household: Household) {}
}

@MainActor
@Observable
final class AppModel {
    static let bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.006"
    static let proID = ProductID.pro(bundleID: bundleID)
    static let budgets = [5, 10, 15, 20]
    static let proDailyCounts = [1, 2, 3]

    var tab: AppTab = .today
    var showPaywall = false
    /// 間取り図で選んだ部屋
    var selectedRoom: Room?
    /// 今日の札で済ませた手順（場所ごと。今日だけ持つ）
    var checkedSteps: [String: Set<Int>] = [:]
    /// 済ませた直後の印（間取りの部屋が澄む動きに使う）
    var justCleaned: Room?

    private(set) var household: Household
    let purchases: PurchaseStore
    let screenshotScene: String?
    private let store: HouseholdStore
    private let clock: () -> Date
    let calendar: Calendar

    @ObservationIgnored private let defaults: UserDefaults
    var onboardingDone: Bool {
        didSet { if screenshotScene == nil { defaults.set(onboardingDone, forKey: "kosouji.onboardingDone") } }
    }
    var hapticsOn: Bool {
        didSet { defaults.set(!hapticsOn, forKey: "kosouji.hapticsOff") }
    }

    init(store: HouseholdStore? = nil, clock: @escaping () -> Date = Date.init, calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        let scene = defaults.string(forKey: "screenshotScene")
        screenshotScene = (scene?.isEmpty ?? true) ? nil : scene
        let chosen: HouseholdStore = store ?? (screenshotScene != nil ? MemoryStore() : DeviceStore())
        self.store = chosen
        self.clock = clock
        self.calendar = calendar
        self.defaults = defaults
        hapticsOn = !defaults.bool(forKey: "kosouji.hapticsOff")
        household = chosen.load() ?? Household()
        purchases = PurchaseStore(productIDs: [Self.proID], proProductIDs: [Self.proID])
        onboardingDone = screenshotScene.map { $0 != "onboarding" } ?? defaults.bool(forKey: "kosouji.onboardingDone")
        if household.startDay == nil {
            household.startDay = DayKey(clock(), calendar: calendar)
        }
        if let screenshotScene { Sample.fill(self, scene: screenshotScene) }
        refreshPlan()
        if let first = todaySpots.first {
            switch screenshotScene {
            case "steps"?: checkedSteps[first.id] = [0, 1]
            case "done"?: markDone(first)
            default: break
            }
        }
    }

    // MARK: - 権利

    var isPro: Bool { purchases.entitlements.isPro || screenshotScene == "pro" }

    func isUnlocked(_ pack: Pack) -> Bool { pack.isFree || isPro }

    // MARK: - 日付と場所

    var today: DayKey { DayKey(clock(), calendar: calendar) }

    /// 今の家で使う場所（鍵の開いた束・家にある部屋・自分の場所）
    var spots: [Spot] {
        let base = SpotData.all.filter { isUnlocked($0.pack) }
        let custom = isPro ? household.customSpots : []
        return (base + custom).filter { !household.hiddenRooms.contains($0.room) }
    }

    func spot(_ id: String) -> Spot? {
        SpotData.byID[id] ?? household.customSpots.first { $0.id == id }
    }

    var planner: Planner {
        Planner(spots: spots, log: household.log, startDay: household.startDay ?? today,
                perDay: isPro ? household.dailyCount : 1, calendar: calendar)
    }

    var yearEndFocus: Bool {
        let month = today.month
        return month >= 10 && month <= 12
    }

    var todaySpots: [Spot] {
        (household.plan?.picks ?? []).compactMap { spot($0) }
    }

    var visibleRooms: [Room] { Room.allCases.filter { !household.hiddenRooms.contains($0) } }

    // MARK: - 今日の分

    /// 日が変わっていたら、今日の分を作り直す
    func refreshPlan() {
        let day = today
        let count = isPro ? household.dailyCount : 1
        if let plan = household.plan, plan.day == day, plan.picks.count == count,
           plan.picks.allSatisfy({ id in spots.contains { $0.id == id } }) {
            return
        }
        if household.plan?.day != day { checkedSteps = [:] }
        household.plan = planner.plan(on: day, count: count, budget: household.budget, yearEndFocus: yearEndFocus)
        save()
    }

    func swap(_ spot: Spot) {
        guard let plan = household.plan else { return }
        household.plan = planner.swap(plan, replacing: spot.id, budget: household.budget, yearEndFocus: yearEndFocus)
        checkedSteps[spot.id] = nil
        save()
    }

    func toggleStep(_ index: Int, of spot: Spot) {
        var set = checkedSteps[spot.id] ?? []
        if set.contains(index) { set.remove(index) } else { set.insert(index) }
        checkedSteps[spot.id] = set
    }

    func isDoneToday(_ spot: Spot) -> Bool {
        household.log.contains { $0.spotID == spot.id && $0.day == today }
    }

    func markDone(_ spot: Spot) {
        guard !isDoneToday(spot) else { return }
        household.log.append(LogEntry(spotID: spot.id, day: today))
        checkedSteps[spot.id] = Set(spot.steps.indices)
        justCleaned = spot.room
        save()
        // 価値を感じた直後（3 回目の小掃除）に 1 度だけ。同じ日に 2 度は出さない
        if !isPro && household.log.count == 3 && household.paywallShownDay == nil && screenshotScene == nil {
            household.paywallShownDay = today
            save()
            showPaywall = true
        }
    }

    func undo(_ spot: Spot) {
        household.log.removeAll { $0.spotID == spot.id && $0.day == today }
        checkedSteps[spot.id] = nil
        save()
    }

    var doneTodayCount: Int { household.log.filter { $0.day == today }.count }

    // MARK: - 記録

    func lastDone(_ spot: Spot) -> DayKey? { planner.lastDone[spot.id] }

    func history(of spot: Spot) -> [DayKey] {
        household.log.filter { $0.spotID == spot.id }.map(\.day).sorted(by: >)
    }

    func entries(on day: DayKey) -> [Spot] {
        household.log.filter { $0.day == day }.compactMap { self.spot($0.spotID) }
    }

    var activeDays: Set<DayKey> { Set(household.log.map(\.day)) }

    var streak: Streak { Streak.make(log: household.log, today: today, calendar: calendar) }

    var yearEnd: YearEndProgress { YearEndProgress.make(spots: spots, log: household.log, today: today, calendar: calendar) }

    // MARK: - 設定

    func setBudget(_ minutes: Int) {
        household.budget = minutes
        household.plan = nil
        refreshPlan()
    }

    func setDailyCount(_ count: Int) {
        household.dailyCount = isPro ? max(1, min(3, count)) : 1
        refreshPlan()
    }

    func setRoom(_ room: Room, present: Bool) {
        if present { household.hiddenRooms.remove(room) } else { household.hiddenRooms.insert(room) }
        refreshPlan()
    }

    func addCustomSpot(name: String, room: Room, interval: Int, minutes: Int) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isPro, !trimmed.isEmpty else { return }
        let id = "c-\(household.customSpots.count + 1)-\(Int(clock().timeIntervalSince1970))"
        let custom = Spot(id, room, String(trimmed.prefix(24)), min: minutes, every: interval, [],
                          ["道具を用意する", "上から下へ、奥から手前へ", "終わったら換気して乾かす"], pack: .custom)
        household.customSpots.append(custom)
        save()
    }

    func removeCustomSpot(_ spot: Spot) {
        household.customSpots.removeAll { $0.id == spot.id }
        household.log.removeAll { $0.spotID == spot.id }
        refreshPlan()
    }

    func resetAll() {
        household = Household(startDay: today)
        checkedSteps = [:]
        refreshPlan()
    }

    func replaceHousehold(_ value: Household) {
        household = value
    }

    private func save() { store.save(household) }
}
