import Foundation

/// 日付の 1 日（時刻を持たない）。端末の暦で数える
struct DayKey: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1)
    }

    func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
    }

    func adding(days: Int, calendar: Calendar = .current) -> DayKey {
        DayKey(calendar.date(byAdding: .day, value: days, to: date(calendar: calendar)) ?? date(calendar: calendar), calendar: calendar)
    }

    /// self から other までの日数（other が後なら正）
    func days(to other: DayKey, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: date(calendar: calendar), to: other.date(calendar: calendar)).day ?? 0
    }

    static func < (a: DayKey, b: DayKey) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }
}

/// 掃除した記録 1 件
struct LogEntry: Codable, Hashable, Sendable {
    let spotID: String
    let day: DayKey
}

/// 今日の分（その日のうちは同じ場所を出す）
struct DayPlan: Codable, Equatable, Sendable {
    let day: DayKey
    var picks: [String]
    var skipped: [String] = []
}

/// 場所の曇りと、今日の 1 か所を決める計算。画面から切り離してテストする
struct Planner: Sendable {
    let spots: [Spot]
    /// 最後に掃除した日（記録がなければ nil）
    let lastDone: [String: DayKey]
    /// 使い始めた日。記録のない場所は、この日に「ほどよく汚れていた」として数える
    let startDay: DayKey
    let calendar: Calendar
    /// 1 日 perDay か所で家じゅうを回せるように、間隔を引き延ばす倍率（1 以上）。
    /// 目安の間隔のままだと、毎日 1 か所では追いつかず（無料の 115 か所で 1 日 6 か所ぶん）、家がずっと曇ったままになる。
    /// 間隔の平方根に比例させると、短い所はよく、長い所も 1 年に 1 度は回ってくる（テストで確かめる）
    let pace: Double

    init(spots: [Spot], log: [LogEntry], startDay: DayKey, perDay: Int = 1, calendar: Calendar = .current) {
        self.spots = spots
        let demand = spots.map { 1 / Double($0.interval).squareRoot() }.reduce(0, +)
        self.pace = max(1, demand / Double(max(1, perDay)))
        var last: [String: DayKey] = [:]
        for entry in log {
            if let known = last[entry.spotID], entry.day <= known { continue }
            last[entry.spotID] = entry.day
        }
        self.lastDone = last
        self.startDay = startDay
        self.calendar = calendar
    }

    /// 0〜1 の決まった値（場所ごとに毎回同じ）。記録のない場所の「最初の汚れ具合」に使う
    static func stableUnit(_ id: String) -> Double {
        var hash: UInt64 = 14_695_981_039_346_656_037  // FNV-1a
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return Double(hash % 10_000) / 10_000
    }

    /// このアプリで回す間隔（日）。目安の間隔より短くはしない
    func effectiveInterval(of spot: Spot) -> Double {
        max(Double(spot.interval), pace * Double(spot.interval).squareRoot())
    }

    /// 前回からの日数。記録がなければ、使い始めの日に間隔の 0.35〜1.15 倍たっていたとする
    func age(of spot: Spot, on today: DayKey) -> Double {
        if let last = lastDone[spot.id] {
            return Double(max(0, last.days(to: today, calendar: calendar)))
        }
        let seeded = effectiveInterval(of: spot) * (0.35 + 0.8 * Self.stableUnit(spot.id))
        return seeded + Double(max(0, startDay.days(to: today, calendar: calendar)))
    }

    /// 間隔に対する進み（1 で「やりどき」）
    func ratio(of spot: Spot, on today: DayKey) -> Double {
        age(of: spot, on: today) / effectiveInterval(of: spot)
    }

    /// 次に札に出るころ
    func nextDue(of spot: Spot, after day: DayKey) -> DayKey {
        day.adding(days: Int(effectiveInterval(of: spot).rounded()), calendar: calendar)
    }

    /// 曇り（0 = 澄んでいる、1 = 曇りきった）。やりどきの少し前から曇りはじめる
    func haze(of spot: Spot, on today: DayKey) -> Double {
        min(1, max(0, (ratio(of: spot, on: today) - 0.25) / 1.0))
    }

    /// 季節の外の場所は、曇りにも今日の候補にも入れない
    func active(on today: DayKey) -> [Spot] {
        spots.filter { $0.inSeason(month: today.month) }
    }

    /// 部屋の曇り（場所の平均）。場所がなければ 0
    func haze(of room: Room, on today: DayKey) -> Double {
        let inRoom = active(on: today).filter { $0.room == room }
        guard !inRoom.isEmpty else { return 0 }
        return inRoom.map { haze(of: $0, on: today) }.reduce(0, +) / Double(inRoom.count)
    }

    /// 家全体の澄み（0〜100）
    func clarity(on today: DayKey) -> Int {
        let list = active(on: today)
        guard !list.isEmpty else { return 100 }
        let mean = list.map { haze(of: $0, on: today) }.reduce(0, +) / Double(list.count)
        return Int(((1 - mean) * 100).rounded())
    }

    /// 今日の候補の点。やりどきの進み × 季節（向いた月なら 1.3 倍）× 年末（年末の所なら 1.25 倍）
    func score(of spot: Spot, on today: DayKey, yearEndFocus: Bool) -> Double {
        var value = ratio(of: spot, on: today)
        if spot.isSeasonal { value *= 1.3 }
        if yearEndFocus && spot.yearEnd { value *= 1.25 }
        return value
    }

    /// 今日の候補を点の高い順に。時間の上限（分）を超える場所は後ろへ回す
    func candidates(on today: DayKey, budget: Int, yearEndFocus: Bool, excluding: Set<String> = []) -> [Spot] {
        let pool = active(on: today).filter { !excluding.contains($0.id) && lastDone[$0.id] != today }
        let sorted = pool.sorted { a, b in
            let fa = a.minutes <= budget, fb = b.minutes <= budget
            if fa != fb { return fa }
            let sa = score(of: a, on: today, yearEndFocus: yearEndFocus)
            let sb = score(of: b, on: today, yearEndFocus: yearEndFocus)
            if sa != sb { return sa > sb }
            return a.id < b.id
        }
        return sorted
    }

    /// 今日の分を決める（count か所）
    func plan(on today: DayKey, count: Int, budget: Int, yearEndFocus: Bool) -> DayPlan {
        let picks = candidates(on: today, budget: budget, yearEndFocus: yearEndFocus).prefix(max(1, count)).map(\.id)
        return DayPlan(day: today, picks: Array(picks))
    }

    /// 「ほかの所にする」：今の 1 か所を外し、次の候補に入れかえる
    func swap(_ plan: DayPlan, replacing id: String, budget: Int, yearEndFocus: Bool) -> DayPlan {
        var next = plan
        next.skipped.append(id)
        let excluded = Set(next.skipped).union(next.picks)
        guard let index = next.picks.firstIndex(of: id) else { return next }
        if let replacement = candidates(on: plan.day, budget: budget, yearEndFocus: yearEndFocus, excluding: excluded).first {
            next.picks[index] = replacement.id
        } else {
            // 候補が尽きたら、外した中から最初に戻す
            next.skipped = [id]
        }
        return next
    }
}

/// 年末までの進み。年末の所を、秋（10 月 1 日）から何か所済ませたか
struct YearEndProgress: Equatable, Sendable {
    let done: Int
    let total: Int
    let daysLeft: Int

    /// 残りを年末（12/28）までに終えるのに要る、1 日あたりの数（切り上げ）
    var perDay: Int {
        let remaining = max(0, total - done)
        guard remaining > 0 else { return 0 }
        return Int((Double(remaining) / Double(max(1, daysLeft))).rounded(.up))
    }

    var fraction: Double { total == 0 ? 1 : Double(done) / Double(total) }

    static func make(spots: [Spot], log: [LogEntry], today: DayKey, calendar: Calendar = .current) -> YearEndProgress {
        // 1〜9 月は前の年の年末を数えず、今年の年末に向けて 10 月から数える
        let seasonStart = DayKey(year: today.year, month: 10, day: 1)
        let target = DayKey(year: today.year, month: 12, day: 28)
        let ids = Set(spots.filter(\.yearEnd).map(\.id))
        let done = Set(log.filter { ids.contains($0.spotID) && $0.day >= seasonStart && $0.day <= target }.map(\.spotID))
        let left = max(0, today.days(to: target, calendar: calendar))
        return YearEndProgress(done: done.count, total: ids.count, daysLeft: left)
    }
}

/// 続けた日数。途切れても責めず、今年の合計も出す
struct Streak: Equatable, Sendable {
    let current: Int
    let thisYear: Int
    let doneToday: Bool

    static func make(log: [LogEntry], today: DayKey, calendar: Calendar = .current) -> Streak {
        let days = Set(log.map(\.day))
        let doneToday = days.contains(today)
        var cursor = doneToday ? today : today.adding(days: -1, calendar: calendar)
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor = cursor.adding(days: -1, calendar: calendar)
        }
        let year = days.filter { $0.year == today.year }.count
        return Streak(current: count, thisYear: year, doneToday: doneToday)
    }
}
