import Foundation

/// スクリーンショット用の見本の記録（起動引数 -screenshotScene <名前>）。端末には保存しない
enum Sample {
    @MainActor
    static func fill(_ model: AppModel, scene: String) {
        let today = model.today
        if scene == "empty" || scene == "onboarding" {
            model.replaceHousehold(Household(startDay: today))
            return
        }
        var household = Household(startDay: today.adding(days: -42, calendar: model.calendar))
        // 6 日続けて、その前はところどころ。決まった並びで毎回同じ絵になる
        let order = SpotData.all.filter { $0.pack == .basic }.map(\.id)
        var log: [LogEntry] = []
        var cursor = 0
        for back in stride(from: 41, through: 1, by: -1) {
            let busy = back <= 6 || back % 3 != 0
            guard busy else { continue }
            let perDay = back % 5 == 0 ? 2 : 1
            for _ in 0..<perDay {
                log.append(LogEntry(spotID: order[(cursor * 7) % order.count], day: today.adding(days: -back, calendar: model.calendar)))
                cursor += 1
            }
        }
        household.log = log
        model.replaceHousehold(household)

        switch scene {
        case "plan", "spot": model.tab = .plan
        case "room":
            model.tab = .plan
            model.selectedRoom = .kitchen
        case "calendar": model.tab = .calendar
        case "settings": model.tab = .settings
        case "paywall": model.showPaywall = true
        default: break
        }
    }
}
