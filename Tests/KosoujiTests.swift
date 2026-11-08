import Foundation
import Testing
@testable import Kosouji

private let tokyo: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
    return c
}()

private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

private func spot(_ id: String, room: Room = .kitchen, minutes: Int = 10, every: Int = 10,
                  months: Set<Int> = [], yearEnd: Bool = false) -> Spot {
    Spot(id, room, id, min: minutes, every: every, [], ["a", "b", "c"], months: months, yearEnd: yearEnd)
}

struct DataTests {
    @Test func idsAreUnique() {
        #expect(Set(SpotData.all.map(\.id)).count == SpotData.all.count)
    }

    @Test func thereIsMoreThanADayOfContent() {
        let free = SpotData.all.filter { $0.pack == .basic }
        #expect(free.count >= 110)
        #expect(SpotData.all.filter { $0.pack == .replace }.count >= 20)
        #expect(SpotData.all.filter { $0.pack == .season }.count >= 20)
        // 部屋ごとに必ず場所がある
        for room in Room.allCases {
            #expect(free.contains { $0.room == room }, "\(room.name) に無料の場所がない")
        }
    }

    @Test func everySpotHasThreeStepsAndSaneNumbers() {
        for s in SpotData.all {
            #expect(s.steps.count == 3, "\(s.id)")
            #expect((5...20).contains(s.minutes), "\(s.id)")
            #expect(s.interval >= 3 && s.interval <= 365, "\(s.id)")
            #expect(s.months.allSatisfy { (1...12).contains($0) }, "\(s.id)")
            #expect(!s.name.isEmpty)
        }
    }

    @Test func chlorineAndAcidAreNeverListedTogether() {
        for s in SpotData.all {
            #expect(!Tool.hasDangerousMix(s.tools), "\(s.id) に塩素系と酸性が並んでいる")
        }
    }

    @Test func floorPlanCoversTheWholeHouseWithoutOverlap() {
        let area = Room.allCases.map { $0.frame.w * $0.frame.h }.reduce(0, +)
        #expect(abs(area - 1) < 0.0001)
        for a in Room.allCases {
            let f = a.frame
            #expect(f.x >= 0 && f.y >= 0 && f.x + f.w <= 1.0001 && f.y + f.h <= 1.0001)
        }
    }

    @Test(arguments: [(3, "3 日ごと"), (7, "1 週間ごと"), (10, "10 日ごと"), (14, "2 週間ごと"), (30, "1 か月ごと"), (90, "3 か月ごと"), (365, "1 年ごと")])
    func intervalText(days: Int, text: String) {
        #expect(Spot.intervalText(days) == text)
    }
}

struct DayKeyTests {
    @Test func countsDaysAcrossMonthsAndYears() {
        #expect(day(2026, 11, 8).days(to: day(2026, 12, 28), calendar: tokyo) == 50)
        #expect(day(2026, 12, 31).adding(days: 1, calendar: tokyo) == day(2027, 1, 1))
        #expect(day(2026, 3, 1).adding(days: -1, calendar: tokyo) == day(2026, 2, 28))
        #expect(day(2026, 1, 2) < day(2026, 2, 1))
    }
}

struct PlannerTests {
    let today = day(2026, 11, 8)

    @Test func cleaningResetsTheHaze() {
        let s = spot("a", every: 10)
        let dirty = Planner(spots: [s], log: [LogEntry(spotID: "a", day: today.adding(days: -20, calendar: tokyo))], startDay: today, calendar: tokyo)
        let clean = Planner(spots: [s], log: [LogEntry(spotID: "a", day: today)], startDay: today, calendar: tokyo)
        #expect(dirty.haze(of: s, on: today) == 1)
        #expect(clean.haze(of: s, on: today) == 0)
        #expect(clean.clarity(on: today) == 100)
    }

    @Test func theLatestEntryWinsEvenIfTheLogIsOutOfOrder() {
        let log = [LogEntry(spotID: "a", day: day(2026, 11, 7)), LogEntry(spotID: "a", day: day(2026, 10, 1))]
        let planner = Planner(spots: [spot("a")], log: log, startDay: today, calendar: tokyo)
        #expect(planner.lastDone["a"] == day(2026, 11, 7))
    }

    @Test func unknownSpotsStartPartlyDirtyAndKeepAgeing() {
        let s = spot("never", every: 100)
        let planner = Planner(spots: [s], log: [], startDay: today, calendar: tokyo)
        let first = planner.ratio(of: s, on: today)
        #expect(first >= 0.35 && first <= 1.15)
        #expect(planner.ratio(of: s, on: today.adding(days: 10, calendar: tokyo)) > first)
        // 毎回同じ値
        #expect(Planner.stableUnit("never") == Planner.stableUnit("never"))
    }

    @Test func picksTheMostOverdueSpot() {
        let a = spot("a", every: 10), b = spot("b", every: 10)
        let log = [LogEntry(spotID: "a", day: today.adding(days: -3, calendar: tokyo)),
                   LogEntry(spotID: "b", day: today.adding(days: -12, calendar: tokyo))]
        let planner = Planner(spots: [a, b], log: log, startDay: today, calendar: tokyo)
        #expect(planner.plan(on: today, count: 1, budget: 10, yearEndFocus: false).picks == ["b"])
    }

    @Test func longSpotsGoBehindTheTimeBudget() {
        let long = spot("long", minutes: 20, every: 10), short = spot("short", minutes: 5, every: 10)
        let log = [LogEntry(spotID: "long", day: today.adding(days: -30, calendar: tokyo)),
                   LogEntry(spotID: "short", day: today.adding(days: -5, calendar: tokyo))]
        let planner = Planner(spots: [long, short], log: log, startDay: today, calendar: tokyo)
        #expect(planner.plan(on: today, count: 1, budget: 10, yearEndFocus: false).picks == ["short"])
        // 上限を上げれば出る
        #expect(planner.plan(on: today, count: 1, budget: 20, yearEndFocus: false).picks == ["long"])
    }

    @Test func outOfSeasonSpotsAreLeftOut() {
        let summer = spot("summer", months: [6, 7]), any = spot("any")
        let log = [LogEntry(spotID: "summer", day: today.adding(days: -300, calendar: tokyo)),
                   LogEntry(spotID: "any", day: today.adding(days: -5, calendar: tokyo))]
        let planner = Planner(spots: [summer, any], log: log, startDay: today, calendar: tokyo)
        #expect(planner.plan(on: today, count: 1, budget: 10, yearEndFocus: false).picks == ["any"])
        #expect(planner.active(on: today).map(\.id) == ["any"])
        #expect(planner.active(on: day(2026, 7, 1)).count == 2)
    }

    @Test func yearEndFocusRaisesYearEndSpots() {
        let plain = spot("plain", every: 10), yearEnd = spot("yearEnd", every: 10, yearEnd: true)
        let log = [LogEntry(spotID: "plain", day: today.adding(days: -10, calendar: tokyo)),
                   LogEntry(spotID: "yearEnd", day: today.adding(days: -9, calendar: tokyo))]
        let planner = Planner(spots: [plain, yearEnd], log: log, startDay: today, calendar: tokyo)
        #expect(planner.plan(on: today, count: 1, budget: 10, yearEndFocus: false).picks == ["plain"])
        #expect(planner.plan(on: today, count: 1, budget: 10, yearEndFocus: true).picks == ["yearEnd"])
    }

    @Test func spotsDoneTodayAreNotOfferedAgain() {
        let a = spot("a"), b = spot("b")
        let planner = Planner(spots: [a, b], log: [LogEntry(spotID: "a", day: today)], startDay: today, calendar: tokyo)
        #expect(!planner.candidates(on: today, budget: 10, yearEndFocus: false).contains { $0.id == "a" })
    }

    @Test func swappingGivesTheNextCandidateAndRemembersTheSkip() {
        let spots = (1...4).map { spot("s\($0)", every: 10) }
        let log = spots.enumerated().map { i, s in LogEntry(spotID: s.id, day: today.adding(days: -(20 - i), calendar: tokyo)) }
        let planner = Planner(spots: spots, log: log, startDay: today, calendar: tokyo)
        let first = planner.plan(on: today, count: 1, budget: 10, yearEndFocus: false)
        #expect(first.picks == ["s1"])
        let second = planner.swap(first, replacing: "s1", budget: 10, yearEndFocus: false)
        #expect(second.picks == ["s2"])
        let third = planner.swap(second, replacing: "s2", budget: 10, yearEndFocus: false)
        #expect(third.picks == ["s3"])
        #expect(third.skipped == ["s1", "s2"])
    }

    @Test func swappingWithNothingLeftKeepsThePick() {
        let planner = Planner(spots: [spot("only")], log: [], startDay: today, calendar: tokyo)
        let plan = planner.plan(on: today, count: 1, budget: 10, yearEndFocus: false)
        #expect(planner.swap(plan, replacing: "only", budget: 10, yearEndFocus: false).picks == ["only"])
    }

    @Test func theFreeHouseIsPacedToOneSpotADay() {
        let free = SpotData.all.filter { $0.pack == .basic }
        let one = Planner(spots: free, log: [], startDay: today, calendar: tokyo)
        let three = Planner(spots: free, log: [], startDay: today, perDay: 3, calendar: tokyo)
        #expect(one.pace > 10)
        #expect(three.pace < one.pace)
        // 長い所も 1 年以内、短い所は目安の間隔より短くならない
        for s in free {
            #expect(one.effectiveInterval(of: s) <= 365, "\(s.id)")
            #expect(one.effectiveInterval(of: s) >= Double(s.interval), "\(s.id)")
        }
    }

    @Test func roomHazeIsTheAverageOfItsSpots() {
        let a = spot("a", room: .bath, every: 10), b = spot("b", room: .bath, every: 10)
        let log = [LogEntry(spotID: "a", day: today), LogEntry(spotID: "b", day: today.adding(days: -30, calendar: tokyo))]
        let planner = Planner(spots: [a, b], log: log, startDay: today, calendar: tokyo)
        #expect(abs(planner.haze(of: .bath, on: today) - 0.5) < 0.0001)
        #expect(planner.haze(of: .toilet, on: today) == 0)
    }

    @Test func everyFreeSpotGetsOfferedWithinAYear() {
        // 毎日 1 か所ずつ済ませると、1 年で無料の場所がすべて一度は出る（季節の外で出ない物を除く）
        let free = SpotData.all.filter { $0.pack == .basic }
        var log: [LogEntry] = []
        var seen = Set<String>()
        let start = day(2026, 1, 1)
        for offset in 0..<365 {
            let d = start.adding(days: offset, calendar: tokyo)
            let planner = Planner(spots: free, log: log, startDay: start, calendar: tokyo)
            let pick = planner.plan(on: d, count: 1, budget: 20, yearEndFocus: false).picks
            for id in pick {
                seen.insert(id)
                log.append(LogEntry(spotID: id, day: d))
            }
        }
        #expect(seen.count == free.count, "出なかった場所：\(Set(free.map(\.id)).subtracting(seen).sorted())")
    }
}

struct ProgressTests {
    @Test func yearEndCountsOnlyThisSeason() {
        let spots = [spot("y1", yearEnd: true), spot("y2", yearEnd: true), spot("n")]
        let log = [LogEntry(spotID: "y1", day: day(2026, 10, 3)),
                   LogEntry(spotID: "y1", day: day(2026, 11, 1)),
                   LogEntry(spotID: "y2", day: day(2026, 9, 30)),
                   LogEntry(spotID: "n", day: day(2026, 11, 2))]
        let p = YearEndProgress.make(spots: spots, log: log, today: day(2026, 11, 8), calendar: tokyo)
        #expect(p.done == 1)
        #expect(p.total == 2)
        #expect(p.daysLeft == 50)
        #expect(p.perDay == 1)
    }

    @Test func perDayRoundsUpAndIsZeroWhenFinished() {
        #expect(YearEndProgress(done: 0, total: 30, daysLeft: 20).perDay == 2)
        #expect(YearEndProgress(done: 30, total: 30, daysLeft: 20).perDay == 0)
        #expect(YearEndProgress(done: 0, total: 3, daysLeft: 0).perDay == 3)
    }

    @Test func streakCountsBackFromTodayOrYesterday() {
        let today = day(2026, 11, 8)
        let log = [-1, -2, -3, -5].map { LogEntry(spotID: "a", day: today.adding(days: $0, calendar: tokyo)) }
        let s = Streak.make(log: log, today: today, calendar: tokyo)
        #expect(s.current == 3)
        #expect(!s.doneToday)
        let withToday = Streak.make(log: log + [LogEntry(spotID: "b", day: today)], today: today, calendar: tokyo)
        #expect(withToday.current == 4)
        #expect(withToday.thisYear == 5)
    }

    @Test func aBrokenStreakIsZeroButTheYearRemains() {
        let today = day(2026, 11, 8)
        let s = Streak.make(log: [LogEntry(spotID: "a", day: day(2026, 11, 1))], today: today, calendar: tokyo)
        #expect(s.current == 0)
        #expect(s.thisYear == 1)
    }
}

/// 保存先を差し替えた記録（テスト用）
final class SpyStore: HouseholdStore, @unchecked Sendable {
    var saved: Household?
    let initial: Household?
    init(_ initial: Household? = nil) { self.initial = initial }
    func load() -> Household? { initial }
    func save(_ household: Household) { saved = household }
}

@MainActor
struct ModelTests {
    let now = DateComponents(calendar: tokyo, timeZone: tokyo.timeZone, year: 2026, month: 11, day: 8, hour: 21).date ?? Date()

    func makeModel(_ store: SpyStore = SpyStore()) -> AppModel {
        let defaults = UserDefaults(suiteName: "kosouji.tests.\(UUID().uuidString)") ?? .standard
        let fixed = now
        return AppModel(store: store, clock: { fixed }, calendar: tokyo, defaults: defaults)
    }

    @Test func aFreshHouseHasOnePlanForToday() {
        let model = makeModel()
        #expect(model.household.plan?.day == day(2026, 11, 8))
        #expect(model.todaySpots.count == 1)
        #expect(model.todaySpots.allSatisfy { $0.pack == .basic })
    }

    @Test func markingDoneIsSavedAndCanBeUndone() {
        let store = SpyStore()
        let model = makeModel(store)
        let first = model.todaySpots[0]
        model.markDone(first)
        #expect(model.isDoneToday(first))
        #expect(store.saved?.log.count == 1)
        model.markDone(first)
        #expect(model.household.log.count == 1)
        model.undo(first)
        #expect(!model.isDoneToday(first))
    }

    @Test func thePaywallComesOnceAfterTheThirdClean() {
        let model = makeModel()
        let three = Array(SpotData.all.filter { $0.pack == .basic }.prefix(4))
        model.markDone(three[0])
        model.markDone(three[1])
        #expect(!model.showPaywall)
        model.markDone(three[2])
        #expect(model.showPaywall)
        model.showPaywall = false
        model.markDone(three[3])
        #expect(!model.showPaywall)
    }

    @Test func hidingARoomTakesItsSpotsOut() {
        let model = makeModel()
        model.setRoom(.kitchen, present: false)
        #expect(!model.spots.contains { $0.room == .kitchen })
        #expect(model.todaySpots.allSatisfy { $0.room != .kitchen })
        model.setRoom(.kitchen, present: true)
        #expect(model.spots.contains { $0.room == .kitchen })
    }

    @Test func freeUsersCannotRaiseTheDailyCountOrAddSpots() {
        let model = makeModel()
        model.setDailyCount(3)
        #expect(model.household.dailyCount == 1)
        model.addCustomSpot(name: "水槽", room: .living, interval: 14, minutes: 10)
        #expect(model.household.customSpots.isEmpty)
        #expect(!model.spots.contains { $0.pack == .replace || $0.pack == .season })
    }

    @Test func changingTheBudgetReplansWithinIt() {
        let model = makeModel()
        model.setBudget(5)
        #expect(model.todaySpots.allSatisfy { $0.minutes <= 5 })
    }

    @Test func aSavedHouseIsLoadedBack() {
        var saved = Household(startDay: day(2026, 10, 1))
        saved.log = [LogEntry(spotID: "k-sink", day: day(2026, 11, 7))]
        saved.budget = 15
        let model = makeModel(SpyStore(saved))
        #expect(model.household.budget == 15)
        #expect(model.lastDone(SpotData.byID["k-sink"]!) == day(2026, 11, 7))
        #expect(model.streak.current == 1)
    }

    @Test func householdRoundTripsThroughJSON() throws {
        var h = Household(startDay: day(2026, 11, 1))
        h.log = [LogEntry(spotID: "a", day: day(2026, 11, 2))]
        h.hiddenRooms = [.veranda]
        h.customSpots = [spot("c-1")]
        h.plan = DayPlan(day: day(2026, 11, 2), picks: ["a"], skipped: ["b"])
        let data = try JSONEncoder().encode(h)
        #expect(try JSONDecoder().decode(Household.self, from: data) == h)
    }
}
